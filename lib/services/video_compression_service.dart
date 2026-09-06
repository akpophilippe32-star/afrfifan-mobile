import 'dart:io';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Service de compression vidéo pour Afrifan
/// Réduit la taille des vidéos avant l'upload pour économiser le stockage et la data.
class VideoCompressionService {
  // Instance unique (Singleton) pour éviter de recréer le service à chaque fois
  static final VideoCompressionService _instance = VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  /// 🎯 Configuration de la compression (Style YouTube/TikTok)
  /// - Qualité : Moyenne (720p max)
  /// - FPS : 30 images/seconde
  /// - Audio : Inclus
  static const VideoQuality _targetQuality = VideoQuality.MediumQuality;
  static const int _targetFrameRate = 30;

  ///  Récupère les informations d'une vidéo (durée, taille, chemin)
  Future<MediaInfo?> getVideoInfo(String filePath) async {
    try {
      // ✅ CORRECTION : getMediaInfo au lieu de getFileMediaInfo
      final info = await VideoCompress.getMediaInfo(filePath);
      return info;
    } catch (e) {
      print('❌ Erreur lors de la récupération des infos vidéo: $e');
      return null;
    }
  }

  /// ️ COMPRESSE UNE VIDÉO
  /// [filePath] : Le chemin de la vidéo originale (depuis la galerie ou caméra)
  /// [onProgress] : Callback pour afficher la progression (0.0 à 100.0) dans l'UI
  /// Retourne le chemin du fichier compressé ou null en cas d'échec.
  Future<File?> compressVideo(
    String filePath, {
    void Function(double percent)? onProgress,
  }) async {
    try {
      print('🎬 Début de la compression vidéo...');
      
      // Nettoyer le cache de compression avant de commencer (évite les bugs)
      await VideoCompress.deleteAllCache();

      // Lancer la compression
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        filePath,
        quality: _targetQuality,
        deleteOrigin: false, // ⚠️ Ne pas supprimer l'originale tout de suite (au cas où)
        includeAudio: true,
        frameRate: _targetFrameRate,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        print('❌ Échec de la compression : aucun fichier retourné.');
        return null;
      }

      final File compressedFile = mediaInfo.file!;
      
      // Afficher les stats de compression dans la console
      final originalSize = await File(filePath).length();
      final compressedSize = await compressedFile.length();
      
      print('✅ Compression terminée !');
      print('   📉 Taille originale : ${(originalSize / 1024 / 1024).toStringAsFixed(2)} Mo');
      print('   📉 Taille compressée : ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} Mo');
      print('   📉 Gain : ${((1 - compressedSize / originalSize) * 100).toStringAsFixed(0)}%');

      return compressedFile;

    } catch (e) {
      print('💥 Erreur critique lors de la compression : $e');
      return null;
    }
  }

  /// 🧹 Nettoie les fichiers temporaires de compression pour libérer de l'espace
  Future<void> clearCompressionCache() async {
    try {
      await VideoCompress.deleteAllCache();
      print('🧹 Cache de compression vidé.');
    } catch (e) {
      print(' Erreur lors du nettoyage du cache: $e');
    }
  }

  /// 📏 Vérifie si la vidéo dépasse les limites autorisées (60 secondes)
  Future<bool> isVideoTooLong(String filePath, {int maxSeconds = 60}) async {
    final info = await getVideoInfo(filePath);
    if (info != null && info.duration != null) {
      return info.duration! > maxSeconds;
    }
    return false;
  }
}

// Instance globale pour l'utiliser facilement partout dans l'app
final videoCompressionService = VideoCompressionService();