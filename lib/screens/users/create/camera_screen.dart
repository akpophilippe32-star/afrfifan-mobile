import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'post_selection_screen.dart';
import 'ai_creation_screen.dart';
import 'text_post_screen.dart'; // ✅ NOUVEL ÉCRAN POUR LE TEXTE
import 'package:audioplayers/audioplayers.dart';

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
  
  final List<Map<String, String>> _availableSounds = [
    {'title': 'Amapiano Vibes', 'artist': 'DJ Maphorisa', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
    {'title': 'Afrobeat Fire', 'artist': 'Burna Boy', 'url': 'https://example.com/sound2.mp3'},
    {'title': 'Coupé Décalé', 'artist': 'DJ Arafat', 'url': 'https://example.com/sound3.mp3'},
    {'title': 'Afro Trap', 'artist': 'MHD', 'url': 'https://example.com/sound4.mp3'},
    {'title': 'Gqom Beat', 'artist': 'Babes Wodumo', 'url': 'https://example.com/sound5.mp3'},
  ];
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, String>? _selectedSound;

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

  void _openAIScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AICreationScreen()),
    );
  }

  // ✅ OUVRIR L'ÉDITEUR DE TEXTE
  void _openTextEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TextPostScreen()),
    );
  }

  // ✅ FONCTION POUR OUVRIR LA GALERIE (PHOTO OU VIDÉO)
  Future<void> _openGallery() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            
            // 1. ✅ PUBLIER DU TEXTE
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.text_fields, color: Colors.white),
              ),
              title: const Text('Publier du texte', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: const Text('Partagez vos pensées', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _openTextEditor();
              },
            ),
            
            const Divider(color: Colors.white10, height: 1),
            
            // 2. Choisir une Photo
            ListTile(
              leading: const Icon(Icons.photo, color: Color(0xFF8B5CF6)),
              title: const Text('Photo de la galerie', style: TextStyle(color: Colors.white, fontSize: 16)),
              onTap: () async {
                debugPrint('📸 [GALERIE] Ouverture du sélecteur de photo...');
                final file = await _imagePicker.pickImage(source: ImageSource.gallery);
                
                if (file != null) {
                  debugPrint('✅ [GALERIE] Photo sélectionnée avec succès: ${file.path}');
                  Navigator.pop(bottomSheetContext); 
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      debugPrint(' [GALERIE] Navigation vers PostSelectionScreen...');
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => PostSelectionScreen(
                            mediaPath: file.path ?? 'web_image_${DateTime.now().millisecondsSinceEpoch}', 
                            mediaType: 'photo', 
                            xFile: file,
                            selectedSound: _selectedSound,
                          )
                        )
                      );
                    }
                  });
                } else {
                  debugPrint('⚠️ [GALERIE] Sélection de photo annulée par l\'utilisateur.');
                }
              },
            ),
            
            const SizedBox(height: 10),
            
            // 3. Choisir une Vidéo
            ListTile(
              leading: const Icon(Icons.video_library, color: Color(0xFF8B5CF6)),
              title: const Text('Vidéo de la galerie', style: TextStyle(color: Colors.white, fontSize: 16)),
              onTap: () async {
                debugPrint(' [GALERIE] Ouverture du sélecteur de vidéo...');
                final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
                
                if (file != null) {
                  debugPrint('✅ [GALERIE] Vidéo sélectionnée avec succès: ${file.path}');
                  Navigator.pop(bottomSheetContext); 
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      debugPrint('🚀 [GALERIE] Navigation vers PostSelectionScreen...');
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => PostSelectionScreen(
                            mediaPath: file.path ?? 'web_video_${DateTime.now().millisecondsSinceEpoch}', 
                            mediaType: 'video', 
                            xFile: file,
                            selectedSound: _selectedSound,
                          )
                        )
                      );
                    }
                  });
                } else {
                  debugPrint('️ [GALERIE] Sélection de vidéo annulée par l\'utilisateur.');
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMusicSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🎵 Choisir un son',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              ...(_availableSounds ?? []).map((sound) {
                return ListTile(
                  leading: const Icon(Icons.music_note, color: Color(0xFF8B5CF6)),
                  title: Text(sound['title']!, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(sound['artist']!, style: const TextStyle(color: Colors.grey)),
                  onTap: () async {
                    await _audioPlayer.stop();
                    await _audioPlayer.play(UrlSource(sound['url']!));
                    setState(() => _selectedSound = sound);
                    Navigator.pop(context); 
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('🎵 Lecture de : ${sound['title']}')),
                    );
                  },
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

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
              selectedSound: _selectedSound,
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
              selectedSound: _selectedSound,
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
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    //  MODE WEB
    // ==========================================================
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8B5CF6),
                      Color(0xFF4A148C),
                      Colors.black,
                    ],
                  ),
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
            Positioned(
              right: 16, top: MediaQuery.of(context).padding.top + 20, bottom: 120,
              child: Column(
                children: [
                  _buildToolButton(icon: Icons.flash_off, onTap: () {}),
                  const SizedBox(height: 16),
                  _buildToolButton(icon: Icons.music_note_outlined, onTap: _showMusicSelectionSheet),
                  const SizedBox(height: 16),
                  _buildToolButton(icon: Icons.grid_off, onTap: () {}),
                ],
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ BOUTON GALERIE (inclut maintenant Texte)
                  GestureDetector(
                    onTap: _openGallery,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                    ),
                  ),
                  // BOUTON IA
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
                  // BOUTON CAPTURE
                  GestureDetector(
                    onTap: () => _simulateCaptureWeb('photo'),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                      child: Container(margin: const EdgeInsets.all(8.0), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    ),
                  ),
                  // FLIP CAMÉRA
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
    // 📱 MODE MOBILE
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
                _buildToolButton(icon: Icons.music_note_outlined, onTap: _showMusicSelectionSheet),
                const SizedBox(height: 16),
                _buildToolButton(icon: _showGrid ? Icons.grid_on : Icons.grid_off, onTap: _toggleGrid),
              ],
            ),
          ),
          if (_selectedSound != null)
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedSound!['title']!,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedSound = null);
                        _audioPlayer.stop();
                      },
                      child: const Icon(Icons.close, color: Colors.white54, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0, right: 0, bottom: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ BOUTON GALERIE (inclut Texte, Photo, Vidéo)
                GestureDetector(
                  onTap: _openGallery,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                  ),
                ),
                // BOUTON IA
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
                // BOUTON CAPTURE
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
                // FLIP CAMÉRA
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