import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart';
import '../../../services/content_service.dart';
import '../create/models/draft_post.dart';

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

  // ✅ PUBLIER EN STORY (SANS COMPRESSION)
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

    setState(() => _isPublishing = true);

    try {
      final storyId = await contentService.publishStory(
        mediaFile: widget.xFile!,
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

  // ✅ PUBLIER SUR LE FEED (SANS COMPRESSION, SANS TITRE)
  Future<void> _publishToFeed({String? caption}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('Connectez-vous pour publier');
      return;
    }

    if (widget.xFile == null) {
      _showError('Erreur : Fichier média introuvable');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final draft = DraftPost();
      draft.postType = widget.mediaType;
      
      // On garde uniquement la légende (max 20 caractères)
      draft.caption = caption ?? '';

      if (widget.selectedSound != null) {
        draft.musicUrl = widget.selectedSound!['url'];
      }

      draft.mediaFiles = [widget.xFile!];

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
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _showFeedOptions(bool isDark) {
    // ✅ Suppression du titleController
    final captionController = TextEditingController();

    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade500 : Colors.black54;
    final fieldBg = isDark ? Colors.grey.shade900 : const Color(0xFFF3F4F6);
    final handleColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Détails de la publication',
                style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // ✅ UNIQUEMENT LA LÉGENDE (Limitée à 20 caractères)
            TextField(
              controller: captionController,
              maxLength: 20,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Légende (max 20 caractères)',
                hintStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: fieldBg,
                counterStyle: TextStyle(color: subTextColor, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), 
                  borderSide: BorderSide.none
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // ✅ On envoie uniquement la caption
                  _publishToFeed(caption: captionController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: accentTextColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Publier sur le Feed',
                  style: TextStyle(
                    color: accentTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final previewBg = isDark ? Colors.grey.shade900 : Colors.grey.shade200;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isPublishing
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: accentColor),
                    const SizedBox(height: 16),
                    Text(
                      '🚀 Publication en cours...',
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cela peut prendre quelques secondes',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: previewBg,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                        child: _isLoading
                            ? Center(child: CircularProgressIndicator(color: accentColor))
                            : _buildMediaPreview(isDark),
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
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.music_note, color: accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.selectedSound!['title']!,
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    widget.selectedSound!['artist']!,
                                    style: TextStyle(color: subTextColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Text(
                            'Où voulez-vous publier ?',
                            style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),

                          _buildSelectionCard(
                            icon: Icons.flash_on,
                            title: 'Ma Story',
                            subtitle: 'Disparaît après 24h',
                            accentColor: accentColor,
                            accentTextColor: accentTextColor,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            onTap: _publishToStory,
                          ),
                          const SizedBox(height: 12),
                          _buildSelectionCard(
                            icon: Icons.grid_view,
                            title: 'Mon Feed',
                            subtitle: 'Reste sur votre profil',
                            accentColor: accentColor,
                            accentTextColor: accentTextColor,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            onTap: () => _showFeedOptions(isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMediaPreview(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;

    if (widget.mediaType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
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
          return Center(child: CircularProgressIndicator(color: accentColor));
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(child: Icon(Icons.error, color: isDark ? Colors.white54 : Colors.black38));
        },
      );
    }
    return Center(child: Icon(Icons.error, color: isDark ? Colors.white54 : Colors.black38));
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color accentTextColor,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentTextColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: subTextColor, size: 18),
          ],
        ),
      ),
    );
  }
}