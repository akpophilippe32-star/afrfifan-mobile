import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'post_selection_screen.dart';
import 'ai_creation_screen.dart'; // ✅ IMPORT DE L'ÉCRAN IA

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isRecordingVideo = false;
  bool _isFrontCamera = false;
  bool _showGrid = false;
  FlashMode _flashMode = FlashMode.off;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      _showPermissionDialog();
      return;
    }

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _controller!.initialize();
    
    if (mounted) {
      setState(() => _isCameraInitialized = true);
    }
  }

  // ✅ OUVRIR L'ÉCRAN IA (Fonctionne sur Mobile ET Web)
  void _openAIScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AICreationScreen()),
    );
  }

  // ✅ SIMULER LA CAPTURE SUR WEB (Ouvre la galerie du PC)
  Future<void> _simulateCaptureWeb(String type) async {
    try {
      final XFile? file = type == 'photo' 
          ? await _imagePicker.pickImage(source: ImageSource.gallery)
          : await _imagePicker.pickVideo(source: ImageSource.gallery);

      if (file != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostSelectionScreen(
              mediaPath: file.path,
              mediaType: type,
              xFile: file,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur test web: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Permission requise', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Afrifan a besoin d\'accéder à la caméra.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCamera() async {
    if (_controller == null || kIsWeb) return;
    final cameras = await availableCameras();
    final newCamera = _isFrontCamera
        ? cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first)
        : cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    await _controller!.dispose();
    _controller = CameraController(newCamera, ResolutionPreset.high, enableAudio: true);
    await _controller!.initialize();
    if (mounted) setState(() => _isFrontCamera = !_isFrontCamera);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || kIsWeb) return;
    try {
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostSelectionScreen(
              mediaPath: photo.path,
              mediaType: 'photo',
              xFile: photo,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur photo: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecordingVideo || kIsWeb) return;
    setState(() => _isRecordingVideo = true);
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 60) _stopRecording();
    });
    try {
      await _controller!.startVideoRecording();
    } catch (e) {
      setState(() => _isRecordingVideo = false);
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecordingVideo || kIsWeb) return;
    _recordingTimer?.cancel();
    try {
      final XFile video = await _controller!.stopVideoRecording();
      setState(() => _isRecordingVideo = false);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostSelectionScreen(
              mediaPath: video.path,
              mediaType: 'video',
              xFile: video,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isRecordingVideo = false);
    }
  }

  void _toggleFlash() {
    if (_controller == null || kIsWeb) return;
    setState(() {
      _flashMode = _flashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
      _controller!.setFlashMode(_flashMode);
    });
  }

  void _toggleGrid() {
    if (!kIsWeb) setState(() => _showGrid = !_showGrid);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recordingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // 🌐 MODE WEB (Pour tester l'interface et l'IA sur Chrome)
    // ==========================================================
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Fond simulé (dégradé stylé)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
colors: const [
  Color(0xFF8B5CF6), // Violet Afrifan
  Color(0xFF4A148C), // Équivalent de Colors.purple.shade900
  Colors.black,
],                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_enhance, size: 100, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('Mode Test Web', style: TextStyle(color: Colors.white38, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            // Overlay sombre
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.6)],
                  ),
                ),
              ),
            ),
            // Barre d'outils (droite)
            Positioned(
              right: 16, top: MediaQuery.of(context).padding.top + 20, bottom: 120,
              child: Column(
                children: [
                  _buildToolButton(icon: Icons.flash_off, onTap: () {}),
                  const SizedBox(height: 16),
                  _buildToolButton(icon: Icons.music_note_outlined, onTap: () {}),
                  const SizedBox(height: 16),
                  _buildToolButton(icon: Icons.grid_off, onTap: () {}),
                ],
              ),
            ),
            // Contrôles en bas
            Positioned(
              left: 0, right: 0, bottom: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ BOUTON IA (Fonctionnel sur Web !)
                  GestureDetector(
                    onTap: _openAIScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.grey.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 28),
                          SizedBox(height: 2),
                          Text('IA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // Bouton capture (simulé)
                  GestureDetector(
                    onTap: () => _simulateCaptureWeb('photo'),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                      child: Container(margin: const EdgeInsets.all(8.0), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    ),
                  ),
                  // Retourner caméra (désactivé)
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disponible sur mobile uniquement'), backgroundColor: Color(0xFF8B5CF6))),
                    child: Container(
                      width: 50, height: 50,
                      decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                      child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // 📱 MODE MOBILE (Caméra Native Réelle - PRIORITAIRE)
    // ==========================================================
    if (!_isCameraInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _controller!.value.isInitialized ? CameraPreview(_controller!) : Container(color: Colors.black)),
          if (_showGrid) Positioned.fill(child: CustomPaint(painter: GridPainter())),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.6)]),
              ),
            ),
          ),
          Positioned(
            right: 16, top: MediaQuery.of(context).padding.top + 20, bottom: 120,
            child: Column(
              children: [
                _buildToolButton(icon: _flashMode == FlashMode.always ? Icons.flash_on : Icons.flash_off, onTap: _toggleFlash),
                const SizedBox(height: 16),
                _buildToolButton(icon: Icons.music_note_outlined, onTap: () {}),
                const SizedBox(height: 16),
                _buildToolButton(icon: _showGrid ? Icons.grid_on : Icons.grid_off, onTap: _toggleGrid),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ BOUTON IA (Gauche)
                GestureDetector(
                  onTap: _openAIScreen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 28),
                        SizedBox(height: 2),
                        Text('IA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // BOUTON CAPTURE (Centre)
                GestureDetector(
                  onTapDown: _isRecordingVideo ? null : (_) => _startRecording(),
                  onTapUp: _isRecordingVideo ? (_) => _stopRecording() : null,
                  onTapCancel: _isRecordingVideo ? () => _stopRecording() : null,
                  onTap: _isRecordingVideo ? null : _takePhoto,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle, border: Border.all(color: _isRecordingVideo ? Colors.red : Colors.white, width: 4)),
                    child: Container(
                      margin: EdgeInsets.all(_isRecordingVideo ? 6.0 : 8.0),
                      decoration: BoxDecoration(color: _isRecordingVideo ? Colors.red : Colors.white, shape: BoxShape.circle),
                      child: _isRecordingVideo ? Center(child: Text('${_recordingSeconds}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))) : null,
                    ),
                  ),
                ),
                // Retourner caméra (Droite)
                GestureDetector(
                  onTap: _toggleCamera,
                  child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle), child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28)),
                ),
              ],
            ),
          ),
          if (_isRecordingVideo)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20, left: 0, right: 0,
              child: const Center(child: Text('ENREGISTREMENT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2))),
            ),
        ],
      ),
    );
  }

  Widget _buildToolButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)));
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3)..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}