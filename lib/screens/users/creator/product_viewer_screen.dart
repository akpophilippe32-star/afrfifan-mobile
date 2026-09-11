import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin selon ton arborescence)

class ProductViewerScreen extends StatefulWidget {
  final String localFilePath;
  final String mediaType;
  final String title;

  const ProductViewerScreen({
    super.key,
    required this.localFilePath,
    required this.mediaType,
    required this.title,
  });

  @override
  State<ProductViewerScreen> createState() => _ProductViewerScreenState();
}

class _ProductViewerScreenState extends State<ProductViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final file = File(widget.localFilePath);
    _videoController = VideoPlayerController.file(file);

    await _videoController!.initialize();
    if (mounted) {
      setState(() => _isVideoInitialized = true);
      _videoController!.play();
      _videoController!.setLooping(true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(color: textColor, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildViewer(isDark),
    );
  }

  Widget _buildViewer(bool isDark) {
    final file = File(widget.localFilePath);
    final accentColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey : Colors.black54;

    // ─── 1. SI C'EST UN PDF ──────────────────────────────────────
    if (widget.mediaType == 'file' || widget.title.toLowerCase().contains('.pdf')) {
      return PDFView(
        filePath: widget.localFilePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) => debugPrint('❌ Erreur PDF: $error'),
      );
    }

    // ─── 2. SI C'EST UNE VIDÉO ───────────────────────────────────
    else if (widget.mediaType == 'video') {
      if (!_isVideoInitialized) {
        return Center(child: CircularProgressIndicator(color: accentColor));
      }
      return GestureDetector(
        onTap: () {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
          } else {
            _videoController!.play();
          }
        },
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    // ─── 3. SI C'EST UNE IMAGE ───────────────────────────────────
    else if (widget.mediaType == 'image') {
      return InteractiveViewer(
        panEnabled: true,
        boundaryMargin: const EdgeInsets.all(20),
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(Icons.broken_image, color: subTextColor, size: 60),
            );
          },
        ),
      );
    }

    // ─── 4. FORMAT NON RECONNU ───────────────────────────────────
    else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: subTextColor, size: 60),
            const SizedBox(height: 16),
            Text(
              'Format de fichier non pris en charge',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}