import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class OfflineManager {
  // Noms de nos "boîtes" (tables) Hive
  static const String _recentVideosBoxName = 'recent_videos';
  static const String _downloadedVideosBoxName = 'downloaded_videos';

  /// 1. Sauvegarder une vidéo dans l'historique des 10 dernières vues
  static Future<void> saveViewedVideo(Map<String, dynamic> videoData) async {
    final box = await Hive.openBox(_recentVideosBoxName);
    
    // On récupère la liste actuelle
    List<dynamic> videos = box.values.toList();
    
    // On retire la vidéo si elle existe déjà (pour éviter les doublons et la mettre en premier)
    videos.removeWhere((v) => v['id'] == videoData['id']);
    
    // On l'ajoute au tout début de la liste
    videos.insert(0, videoData);
    
    // On garde STRICTEMENT les 10 dernières vidéos pour ne pas surcharger la mémoire
    if (videos.length > 10) {
      videos = videos.sublist(0, 10);
    }
    
    // On sauvegarde la nouvelle liste dans Hive
    await box.clear();
    await box.addAll(videos);
  }

  /// 2. Récupérer les vidéos récentes pour l'affichage hors ligne
  static Future<List<Map<String, dynamic>>> getRecentVideos() async {
    final box = await Hive.openBox(_recentVideosBoxName);
    // On retourne la liste telle quelle (la plus récente est déjà à l'index 0)
    return List<Map<String, dynamic>>.from(box.values.toList());
  }

  /// 3. Télécharger la vidéo dans le dossier PRIVÉ de l'application
  /// Retourne le chemin local du fichier si réussi, ou null si échec.
  static Future<String?> downloadVideoForOffline(String videoId, String videoUrl) async {
    try {
      // flutter_cache_manager télécharge le fichier et le stocke dans un dossier caché du système
      final fileInfo = await DefaultCacheManager().getFileFromCache(videoUrl);
      
      final String localPath;
      if (fileInfo != null) {
        localPath = fileInfo.file.path;
      } else {
        // Si pas en cache, on le télécharge
        final file = await DefaultCacheManager().getSingleFile(videoUrl);
        localPath = file.path;
      }
      
      // On sauvegarde le lien entre l'ID de la vidéo et son chemin local dans Hive
      final downloadBox = await Hive.openBox(_downloadedVideosBoxName);
      await downloadBox.put(videoId, localPath);
      
      return localPath; 
    } catch (e) {
      print('❌ Erreur téléchargement vidéo hors ligne: $e');
      return null;
    }
  }

  /// 4. Vérifier si une vidéo est déjà téléchargée et récupérer son chemin local
  static Future<String?> getLocalVideoPath(String videoId) async {
    final box = await Hive.openBox(_downloadedVideosBoxName);
    return box.get(videoId);
  }

  /// 5. (Optionnel) Supprimer une vidéo téléchargée pour libérer de l'espace
  static Future<void> deleteDownloadedVideo(String videoId) async {
    final box = await Hive.openBox(_downloadedVideosBoxName);
    final localPath = box.get(videoId);
    
    if (localPath != null) {
      // Supprimer le fichier du système de fichiers
      // Note: DefaultCacheManager gère aussi le nettoyage automatique, 
      // mais ceci force la suppression de notre référence
      await box.delete(videoId);
    }
  }
}