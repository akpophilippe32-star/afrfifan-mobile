import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/content_service.dart';
import '../create/models/draft_post.dart';
import '../../../services/video_compression_service.dart'; // ✅ AJOUTÉ

class PostSelectionScreen extends StatefulWidget {
  final String mediaPath;
  final String mediaType;
  final XFile? xFile; 
  final Map<String, String>? selectedSound;

  const PostSelectionScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    this.xFile,
    this.selectedSound,
  });

  @override
  State<PostSelectionScreen> createState() => _PostSelectionScreenState();
}

class _PostSelectionScreenState extends State<PostSelectionScreen> {
  VideoPlayerController? _videoController;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _isPublishing = false;
  bool _isCompressing = false; // ✅ AJOUTÉ : Pour afficher un loader spécifique à la compression

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    try {
      if (widget.mediaType == 'video') {
        if (kIsWeb || widget.mediaPath.startsWith('http') || widget.mediaPath.startsWith('blob')) {
          _videoController = VideoPlayerController.network(widget.mediaPath);
        } else {
          _videoController = VideoPlayerController.file(File(widget.mediaPath));
        }
        
        await _videoController!.initialize();
        
        if (mounted) {
          setState(() {});
          _videoController?.play();
          _videoController?.setLooping(true);
          setState(() => _isLoading = false);
        }
      } else {
        if (widget.xFile != null) {
          _imageBytes = await widget.xFile!.readAsBytes();
        }
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement média: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // ✅ VERSION AVEC COMPRESSION VIDÉO POUR LES STORIES
  Future<void> _publishToStory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Connectez-vous pour publier');
      return;
    }

    if (widget.xFile == null) {
      _showError('Publication en Story d\'image IA bientôt disponible. Utilisez le Feed !');
      return;
    }

    setState(() {
      _isPublishing = true;
      _isCompressing = widget.mediaType == 'video';
    });

    try {
      XFile fileToUpload = widget.xFile!;
      
      // ✅ COMPRESSION SI C'EST UNE VIDÉO
      if (widget.mediaType == 'video') {
        final compressedFile = await videoCompressionService.compressVideo(fileToUpload.path);
        if (compressedFile != null) {
          fileToUpload = XFile(compressedFile.path);
        } else {
          setState(() { _isPublishing = false; _isCompressing = false; });
          _showError('Échec de la compression vidéo.');
          return;
        }
      }

      final storyId = await contentService.publishStory(
        mediaFile: fileToUpload, // ✅ On envoie le fichier compressé
        userId: user.id,
      );

      if (storyId != null && mounted) {
        Navigator.pop(context); 
        Navigator.pop(context); 
        _showSuccess('✅ Story publiée avec succès !');
      } else {
        _showError('Erreur lors de la publication');
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      _showError('Une erreur est survenue');
    } finally {
      if (mounted) setState(() {
        _isPublishing = false;
        _isCompressing = false;
      });
    }
  }

  // ✅ VERSION AVEC COMPRESSION VIDÉO POUR LE FEED
  Future<void> _publishToFeed({String? title, String? caption}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Connectez-vous pour publier');
      return;
    }

    if (widget.xFile == null) {
      _showError('Erreur : Fichier média introuvable');
      return;
    }

    setState(() {
      _isPublishing = true;
      _isCompressing = widget.mediaType == 'video'; // Active le loader de compression si c'est une vidéo
    });

    try {
      final draft = DraftPost();
      draft.postType = widget.mediaType;
      draft.caption = caption ?? '';
      
      if (widget.selectedSound != null) {
        draft.musicUrl = widget.selectedSound!['url'];
      }
      if (title != null && title.isNotEmpty) {
        draft.caption = '$title\n\n${draft.caption}';
      }

      // ✅ 1. COMPRESSION (Uniquement pour les vidéos)
      XFile fileToUpload = widget.xFile!;
      if (widget.mediaType == 'video') {
        debugPrint('🎬 Début de la compression vidéo...');
        final compressedFile = await videoCompressionService.compressVideo(
          fileToUpload.path,
        );
        
        if (compressedFile == null) {
          setState(() { _isPublishing = false; _isCompressing = false; });
          _showError('Échec de la compression vidéo. Réessayez.');
          return;
        }
        
        // On remplace le fichier original par le fichier compressé
        fileToUpload = XFile(compressedFile.path);
        debugPrint('✅ Vidéo compressée avec succès !');
      }

      // ✅ 2. PRÉPARATION DU DRAFT AVEC LE FICHIER (COMPRESSÉ OU NON)
      draft.mediaFiles = [fileToUpload]; 

      // ✅ 3. UPLOAD VERS SUPABASE
      final postId = await contentService.publishPost(draft);

      if (postId != null && mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        _showSuccess('✅ Post publié sur le Feed !');
      } else {
        _showError('Erreur lors de la publication');
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      _showError('Une erreur est survenue : $e');
    } finally {
      if (mounted) setState(() {
        _isPublishing = false;
        _isCompressing = false;
      });
    }
  }

  void _showFeedOptions() {
    final titleController = TextEditingController();
    final captionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Détails de la publication', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Titre', hintStyle: TextStyle(color: Colors.grey.shade500), filled: true, fillColor: Colors.grey.shade900, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Légende (optionnel)', hintStyle: TextStyle(color: Colors.grey.shade500), filled: true, fillColor: Colors.grey.shade900, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _publishToFeed(title: titleController.text, caption: captionController.text);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Publier sur le Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // ✅ MODIFICATION ICI : Gestion dynamique du loader (Compression vs Publication)
        child: (_isPublishing || _isCompressing)
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    const SizedBox(height: 16),
                    Text(
                      _isCompressing 
                          ? '🎬 Compression de la vidéo en cours...' 
                          : '🚀 Publication en cours...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    if (_isCompressing) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Cela peut prendre quelques secondes',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ]
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32))),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                            : _buildMediaPreview(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.selectedSound != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.music_note, color: Color(0xFF8B5CF6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.selectedSound!['title']!,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    widget.selectedSound!['artist']!,
                                    style: TextStyle(color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          const Text('Où voulez-vous publier ?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          _buildSelectionCard(icon: Icons.flash_on, title: 'Ma Story', subtitle: 'Disparaît après 24h', color: const Color(0xFF8B5CF6), onTap: _publishToStory),
                          const SizedBox(height: 12),
                          _buildSelectionCard(icon: Icons.grid_view, title: 'Mon Feed', subtitle: 'Reste sur votre profil', color: const Color(0xFFEC4899), onTap: _showFeedOptions),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (widget.mediaType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!));
      }
    } else if (widget.xFile != null && _imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      return Image.network(
        widget.mediaPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.error, color: Colors.white54));
        },
      );
    }
    return const Center(child: Icon(Icons.error, color: Colors.white54));
  }

  Widget _buildSelectionCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.5), width: 1.5)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}