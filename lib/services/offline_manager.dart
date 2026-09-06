import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';

class OfflineManager {
  static const String _recentVideosBoxName = 'recent_videos';
  static const String _downloadedPostsBoxName = 'downloaded_posts'; // ✅ Nouvelle boîte dédiée

  /// 1. Sauvegarder dans l'historique des 10 dernières vues
  static Future<void> saveViewedVideo(Map<String, dynamic> videoData) async {
    try {
      final box = await Hive.openBox(_recentVideosBoxName);
      List<dynamic> videos = box.values.toList();
      final String currentId = videoData['id']?.toString() ?? '';
      videos.removeWhere((v) => v['id'].toString() == currentId);
      videos.insert(0, videoData);
      if (videos.length > 10) videos = videos.sublist(0, 10);
      await box.clear();
      await box.addAll(videos);
    } catch (e) {
      debugPrint('❌ [HIVE] Erreur saveViewedVideo: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentVideos() async {
    try {
      final box = await Hive.openBox(_recentVideosBoxName);
      List<Map<String, dynamic>> result = [];
      for (var item in box.values.toList()) {
        if (item is Map) {
          Map<String, dynamic> cleanMap = {};
          item.forEach((key, value) => cleanMap[key.toString()] = value);
          result.add(cleanMap);
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ [HIVE] Erreur getRecentVideos: $e');
      return [];
    }
  }

  /// 3. ✅ NOUVEAU : Télécharger et sauvegarder le post COMPLET avec le chemin local
  static Future<String?> downloadVideoForOffline(String videoId, String videoUrl, Map<String, dynamic> postData) async {
    try {
      final String cleanId = videoId.toString().trim();
      debugPrint('💾 [DOWNLOAD] Début téléchargement pour ID: $cleanId');
      
      final fileInfo = await DefaultCacheManager().getFileFromCache(videoUrl);
      final String localPath;
      
      if (fileInfo != null) {
        localPath = fileInfo.file.path;
        debugPrint('ℹ️ [DOWNLOAD] Déjà en cache: $localPath');
      } else {
        debugPrint('⬇️ [DOWNLOAD] Téléchargement depuis le réseau...');
        final file = await DefaultCacheManager().getSingleFile(videoUrl);
        localPath = file.path;
        debugPrint('✅ [DOWNLOAD] Téléchargement réussi: $localPath');
      }
      
      // On sauvegarde TOUTES les données du post + le chemin local dans la boîte dédiée
      final downloadBox = await Hive.openBox(_downloadedPostsBoxName);
      final enrichedPost = {
        ...postData,
        'id': cleanId, // Force l'ID propre
        'localPath': localPath,
      };
      
      await downloadBox.put(cleanId, enrichedPost);
      debugPrint('💾 [HIVE] Post sauvegardé avec succès dans downloaded_posts pour: $cleanId');
      
      return localPath; 
    } catch (e) {
      debugPrint('❌ [DOWNLOAD] Erreur critique: $e');
      return null;
    }
  }

  /// 4. ✅ NOUVEAU : Récupérer TOUS les posts téléchargés (pour l'écran Téléchargé)
  static Future<List<Map<String, dynamic>>> getDownloadedPosts() async {
    try {
      final box = await Hive.openBox(_downloadedPostsBoxName);
      List<Map<String, dynamic>> result = [];
      
      for (var item in box.values.toList()) {
        if (item is Map) {
          Map<String, dynamic> cleanMap = {};
          item.forEach((key, value) => cleanMap[key.toString()] = value);
          result.add(cleanMap);
        }
      }
      debugPrint('✅ [HIVE] ${result.length} posts téléchargés trouvés.');
      return result;
    } catch (e) {
      debugPrint('❌ [HIVE] Erreur getDownloadedPosts: $e');
      return [];
    }
  }

  /// 5. Supprimer un post téléchargé
  static Future<void> deleteDownloadedPost(String videoId) async {
    try {
      final String cleanId = videoId.toString().trim();
      final box = await Hive.openBox(_downloadedPostsBoxName);
      await box.delete(cleanId);
      debugPrint('🗑️ [HIVE] Post supprimé de downloaded_posts: $cleanId');
    } catch (e) {
      debugPrint('❌ [HIVE] Erreur deleteDownloadedPost: $e');
    }
  }
}