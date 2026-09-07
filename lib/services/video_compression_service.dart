import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Classe simple pour remplacer l'ancien MediaInfo
class VideoInfo {
  final String filePath;
  final int sizeInBytes;
  final double? durationInSeconds;

  VideoInfo({
    required this.filePath,
    required this.sizeInBytes,
    this.durationInSeconds,
  });
}

/// Service de compression vidéo pour Afrifan
class VideoCompressionService {
  // Instance unique (Singleton)
  static final VideoCompressionService _instance = VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  /// 🎯 Récupère les informations d'une vidéo
  Future<VideoInfo?> getVideoInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final sizeInBytes = await file.length();
      double? durationInSeconds;

      final session = await FFprobeKit.getMediaInformation(filePath);
      final mediaInfo = session.getMediaInformation();
      
      if (mediaInfo != null) {
        // ✅ CORRECTION 1 : Ajout du '?' pour gérer le null
        final durationStr = mediaInfo.getAllProperties()?['duration'];
        if (durationStr != null) {
          durationInSeconds = double.tryParse(durationStr);
        }
      }

      return VideoInfo(
        filePath: filePath,
        sizeInBytes: sizeInBytes,
        durationInSeconds: durationInSeconds,
      );
    } catch (e) {
      print('❌ Erreur infos vidéo: $e');
      return null;
    }
  }

  /// 🎬 COMPRESSE UNE VIDÉO
  Future<File?> compressVideo(
    String filePath, {
    void Function(double percent)? onProgress,
  }) async {
    try {
      print('🎬 Début de la compression vidéo...');
      
      final directory = await getTemporaryDirectory();
      final fileName = filePath.split('/').last;
      final nameWithoutExt = fileName.split('.').first;
      final outputPath = "${directory.path}/compressed_${nameWithoutExt}.mp4";

      final info = await getVideoInfo(filePath);
      final totalDuration = info?.durationInSeconds ?? 0.0;

      final command = "-i '$filePath' -vcodec libx264 -crf 28 -preset ultrafast -acodec aac -b:a 128k -movflags +faststart '$outputPath'";

      // ✅ CORRECTION 2 : Ordre correct des callbacks pour ffmpeg_kit_flutter_new 4.6.2
      // 1. Complete Callback
      // 2. Log Callback
      // 3. Statistics Callback
      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            print('✅ Compression réussie !');
          } else {
            print('❌ Échec compression. Code: $returnCode');
          }
        },
        (log) {
          // Ceci est bien le Log Callback maintenant
          if (totalDuration > 0) {
            final logMessage = log.getMessage();
            if (logMessage != null && logMessage.contains('time=')) {
              final timeStr = logMessage.split('time=')[1].split(' ')[0];
              final parts = timeStr.split(':');
              if (parts.length == 3) {
                final h = double.tryParse(parts[0]) ?? 0;
                final m = double.tryParse(parts[1]) ?? 0;
                final s = double.tryParse(parts[2]) ?? 0;
                final currentTime = (h * 3600) + (m * 60) + s;
                
                final percent = (currentTime / totalDuration) * 100;
                if (onProgress != null) {
                  onProgress(percent.clamp(0.0, 100.0));
                }
              }
            }
          }
        },
        (statistics) {
          // Callback de statistiques (optionnel, on peut l'utiliser pour une barre de progression alternative)
          // final time = statistics.getTime();
        },
      );

      final compressedFile = File(outputPath);
      if (await compressedFile.exists()) {
        final originalSize = await File(filePath).length();
        final newSize = await compressedFile.length();
        
        print('📉 Originale : ${(originalSize / 1024 / 1024).toStringAsFixed(2)} Mo');
        print('📉 Compressée : ${(newSize / 1024 / 1024).toStringAsFixed(2)} Mo');
        return compressedFile;
      }
      return null;
    } catch (e) {
      print('💥 Erreur compression : $e');
      return null;
    }
  }

  /// 🧹 Nettoie les fichiers temporaires
  Future<void> clearCompressionCache() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      int deletedCount = 0;
      for (var file in files) {
        if (file is File && file.path.contains('compressed_')) {
          await file.delete();
          deletedCount++;
        }
      }
      print('🧹 Cache vidé ($deletedCount fichiers).');
    } catch (e) {
      print('❌ Erreur nettoyage cache: $e');
    }
  }

  /// 📏 Vérifie la durée
  Future<bool> isVideoTooLong(String filePath, {int maxSeconds = 60}) async {
    final info = await getVideoInfo(filePath);
    if (info != null && info.durationInSeconds != null) {
      return info.durationInSeconds! > maxSeconds;
    }
    return false;
  }
}

// Instance globale
final videoCompressionService = VideoCompressionService();