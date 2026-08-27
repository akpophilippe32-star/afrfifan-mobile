import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/content_service.dart';
import '../create/models/draft_post.dart';

class PostSelectionScreen extends StatefulWidget {
  final String mediaPath;
  final String mediaType;
  final XFile? xFile; // ✅ Optionnel (null pour les images IA)

  const PostSelectionScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    this.xFile,
  });

  @override
  State<PostSelectionScreen> createState() => _PostSelectionScreenState();
}

class _PostSelectionScreenState extends State<PostSelectionScreen> {
  VideoPlayerController? _videoController;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    try {
      if (widget.mediaType == 'video') {
        _videoController = VideoPlayerController.network(widget.mediaPath)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController?.play();
              _videoController?.setLooping(true);
              setState(() => _isLoading = false);
            }
          });
      } else {
        if (widget.xFile != null) {
          // ✅ C'est un fichier local (caméra/galerie)
          _imageBytes = await widget.xFile!.readAsBytes();
        }
        // ✅ Si xFile est null, c'est une URL (IA), on l'affichera avec Image.network plus bas
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

  // ✅ VRAIE PUBLICATION STORY
  Future<void> _publishToStory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Connectez-vous pour publier');
      return;
    }

    // ✅ Gestion des images IA (pas de XFile local pour l'instant en story)
    if (widget.xFile == null) {
      _showError('Publication en Story d\'image IA bientôt disponible. Utilisez le Feed !');
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final storyId = await contentService.publishStory(
        mediaFile: widget.xFile!, // ✅ On est maintenant sûr qu'il n'est pas null
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
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ✅ VRAIE PUBLICATION FEED (Fonctionne parfaitement avec les URL IA !)
  Future<void> _publishToFeed({String? title, String? caption}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Connectez-vous pour publier');
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final draft = DraftPost();
      draft.postType = widget.mediaType == 'video' ? 'video' : 'image';
      draft.mediaPaths = [widget.mediaPath]; // ✅ L'URL de l'IA est parfaitement gérée ici
      draft.caption = caption ?? '';
      if (title != null && title.isNotEmpty) {
        draft.caption = '$title\n\n${draft.caption}';
      }

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
      _showError('Une erreur est survenue');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
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
        child: _isPublishing
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                SizedBox(height: 16),
                Text('Publication en cours...', style: TextStyle(color: Colors.white, fontSize: 16)),
              ]))
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
      // ✅ Fichier local (caméra/galerie)
      return Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      // ✅ C'est une URL (ex: image générée par IA)
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