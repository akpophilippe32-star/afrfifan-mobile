import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import '../../../../theme/app_colors.dart';
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
    
    // ✅ TEST IMMÉDIAT : Vérifier si le fichier existe (placé au bon endroit !)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // On attend un peu que _loadDownloadedPosts finisse
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
      
      // ✅ Conversion sécurisée en Map<String, dynamic>
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Mes téléchargements', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _downloadedPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_for_offline_outlined, size: 80, color: Colors.white54),
                      const SizedBox(height: 16),
                      const Text('Aucun téléchargement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Les médias que tu télécharges apparaîtront ici', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _downloadedPosts.length,
                  itemBuilder: (context, index) {
                    final post = _downloadedPosts[index];
                    
                    // ✅ Accès sécurisé aux données avec conversion en String
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
                        color: Colors.grey.shade900,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off, color: Colors.white54, size: 48),
                              SizedBox(height: 12),
                              Text('Fichier non disponible', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
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
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                      onDismissed: (direction) async {
                        await OfflineManager.deleteDownloadedPost(postId);
                        _loadDownloadedPosts();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supprimé du stockage'), backgroundColor: Colors.redAccent));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 1),
                        height: isImage ? 250 : 400,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            isImage
                                ? _buildLocalImage(localPath, postId)
                                : _LocalVideoPlayer(localPath: localPath, postId: postId),
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    if (caption.isNotEmpty) Text(caption, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildLocalImage(String localPath, String postId) {
    debugPrint('🖼️ [IMAGE] Tentative de chargement: $localPath');
    
    try {
      final file = File(localPath);
      final exists = file.existsSync();
      
      debugPrint('📂 [IMAGE] Fichier existe: $exists');
      
      if (!exists) {
        debugPrint('⚠️ [IMAGE] Fichier introuvable sur le disque!');
        return Container(
          color: Colors.grey.shade800,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_off, color: Colors.white54, size: 48),
                SizedBox(height: 8),
                Text('Fichier supprimé', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        );
      }
      
      return Image.file(
        file,
        fit: BoxFit.cover,
        // ✅ loadingBuilder retiré pour éviter l'erreur de compilation sur certaines versions de Flutter
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ [IMAGE] Erreur Flutter: $error');
          return Container(
            color: Colors.grey.shade800,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('Image corrompue', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
        color: Colors.grey.shade800,
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

// ✅ Classe séparée pour le lecteur vidéo local
class _LocalVideoPlayer extends StatefulWidget {
  final String? localPath;
  final String postId;
  const _LocalVideoPlayer({required this.localPath, required this.postId});

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
        color: Colors.grey.shade900, 
        child: const Center(child: CircularProgressIndicator(color: Colors.white54))
      );
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio, 
      child: VideoPlayer(_controller!)
    );
  }
}