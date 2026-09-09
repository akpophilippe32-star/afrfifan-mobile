import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // ✅ Pour lire les PDF

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
    // ✅ Lit la vidéo directement depuis le fichier local (pas d'internet)
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildViewer(),
    );
  }

  Widget _buildViewer() {
    final file = File(widget.localFilePath);

    // ─── 1. SI C'EST UN PDF ──────────────────────────────────────
    if (widget.mediaType == 'file' || widget.title.toLowerCase().contains('.pdf')) {
      return PDFView(
        filePath: widget.localFilePath, // ✅ Lit le fichier local en toute sécurité
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
        return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
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
          file, // ✅ Lit l'image locale
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 60));
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
            const Icon(Icons.error_outline, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Format de fichier non pris en charge', 
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}