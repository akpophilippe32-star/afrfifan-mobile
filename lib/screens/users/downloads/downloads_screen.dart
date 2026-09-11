import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../../../../services/offline_manager.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _downloadedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('📥 [DOWNLOADS SCREEN] Initialisation de l\'écran...');
    _loadDownloadedPosts();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _downloadedPosts.isNotEmpty) {
        final firstPost = _downloadedPosts[0];
        final path = firstPost['localPath']?.toString();
        if (path != null) {
          final file = File(path);
          final exists = await file.exists();
          debugPrint('🔍 [TEST FICHIER] Chemin: $path');
          debugPrint('🔍 [TEST FICHIER] Existe: $exists');
          if (exists) {
            final length = await file.length();
            debugPrint('📏 [TEST FICHIER] Taille: $length bytes');
          } else {
            debugPrint('❌ [TEST FICHIER] Le fichier a été supprimé ou n\'existe pas à cet emplacement.');
          }
        }
      }
    });
  }

  Future<void> _loadDownloadedPosts() async {
    debugPrint('🔄 [DOWNLOADS SCREEN] Début du chargement des téléchargements...');
    setState(() => _isLoading = true);

    try {
      final downloaded = await OfflineManager.getDownloadedPosts();

      debugPrint('📊 [DOWNLOADS SCREEN] ${downloaded.length} posts trouvés');

      List<Map<String, dynamic>> safeList = [];
      for (var item in downloaded) {
        if (item != null) {
          Map<String, dynamic> safeMap = {};
          if (item is Map) {
            item.forEach((key, value) {
              safeMap[key.toString()] = value;
            });
          }
          safeList.add(safeMap);
        }
      }

      if (mounted) {
        setState(() {
          _downloadedPosts = safeList;
          _isLoading = false;
        });
        debugPrint('✅ [DOWNLOADS SCREEN] Chargement terminé! ${_downloadedPosts.length} posts affichables.');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [DOWNLOADS SCREEN] Erreur chargement: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
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
    final subTextColor = isDark ? Colors.white54 : Colors.black45;
    final accentColor = isDark ? Colors.white : Colors.black;
    final placeholderBg = isDark ? Colors.grey.shade900 : Colors.grey.shade200;
    final placeholderIcon = isDark ? Colors.white54 : Colors.black38;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text('Mes téléchargements', style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _downloadedPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_for_offline_outlined, size: 80, color: subTextColor),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun téléchargement',
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les médias que tu télécharges apparaîtront ici',
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _downloadedPosts.length,
                  itemBuilder: (context, index) {
                    final post = _downloadedPosts[index];

                    final creatorName = (post['profiles'] != null && post['profiles'] is Map)
                        ? (post['profiles']['full_name']?.toString() ?? 'Créateur')
                        : 'Créateur';

                    final caption = post['content']?.toString() ?? '';
                    final localPath = post['localPath']?.toString();
                    final mediaType = post['media_type']?.toString() ?? 'image';
                    final postId = post['id']?.toString() ?? 'inconnu';

                    debugPrint('🎬 [DOWNLOADS] Affichage du post #$index (ID: $postId)');
                    debugPrint('   ├─ Type: $mediaType');
                    debugPrint('   └─ Chemin local: ${localPath ?? "null"}');

                    if (localPath == null || localPath.isEmpty) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 1),
                        height: 250,
                        color: placeholderBg,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off, color: placeholderIcon, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Fichier non disponible',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final isImage = mediaType.toLowerCase().contains('image') ||
                        mediaType.toLowerCase().contains('photo') ||
                        localPath.toLowerCase().endsWith('.jpg') ||
                        localPath.toLowerCase().endsWith('.jpeg') ||
                        localPath.toLowerCase().endsWith('.png');

                    return Dismissible(
                      key: Key(postId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        await OfflineManager.deleteDownloadedPost(postId);
                        _loadDownloadedPosts();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Supprimé du stockage'), backgroundColor: Colors.redAccent),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 1),
                        height: isImage ? 250 : 400,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            isImage
                                ? _buildLocalImage(localPath, postId, isDark)
                                : _LocalVideoPlayer(localPath: localPath, postId: postId, isDark: isDark),
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(creatorName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    if (caption.isNotEmpty)
                                      Text(caption,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildLocalImage(String localPath, String postId, bool isDark) {
    debugPrint('🖼️ [IMAGE] Tentative de chargement: $localPath');

    final placeholderBg = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final placeholderIcon = isDark ? Colors.white54 : Colors.black38;

    try {
      final file = File(localPath);
      final exists = file.existsSync();

      debugPrint('📂 [IMAGE] Fichier existe: $exists');

      if (!exists) {
        debugPrint('⚠️ [IMAGE] Fichier introuvable sur le disque!');
        return Container(
          color: placeholderBg,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_off, color: placeholderIcon, size: 48),
                const SizedBox(height: 8),
                Text('Fichier supprimé',
                    style: TextStyle(color: placeholderIcon, fontSize: 12)),
              ],
            ),
          ),
        );
      }

      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ [IMAGE] Erreur Flutter: $error');
          return Container(
            color: placeholderBg,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: placeholderIcon, size: 48),
                  const SizedBox(height: 8),
                  Text('Image corrompue',
                      style: TextStyle(color: placeholderIcon, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint('💥 [IMAGE] Erreur critique: $e');
      debugPrint('📋 Stack: $stackTrace');
      return Container(
        color: placeholderBg,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              SizedBox(height: 8),
              Text('Erreur système', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LECTEUR VIDÉO LOCAL
// ═══════════════════════════════════════════════════════════════════
class _LocalVideoPlayer extends StatefulWidget {
  final String? localPath;
  final String postId;
  final bool isDark;
  const _LocalVideoPlayer({required this.localPath, required this.postId, this.isDark = true});

  @override
  State<_LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<_LocalVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    debugPrint('🎥 [VIDEO PLAYER] Initialisation pour le post ${widget.postId}');

    if (widget.localPath != null && widget.localPath!.isNotEmpty) {
      _controller = VideoPlayerController.file(File(widget.localPath!))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _controller?.play();
          _controller?.setLooping(true);
          debugPrint('✅ [VIDEO PLAYER] Initialisé avec succès');
        }).catchError((e) {
          debugPrint('❌ [VIDEO PLAYER] Erreur lecture vidéo ${widget.postId}: $e');
        });
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ [VIDEO PLAYER] Nettoyage pour le post ${widget.postId}');
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: widget.isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        child: Center(
          // ✅ Loader noir/blanc adaptatif
          child: CircularProgressIndicator(
            color: widget.isDark ? Colors.white54 : Colors.black38,
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}