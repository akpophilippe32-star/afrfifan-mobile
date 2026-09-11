import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedFile;
  String _mediaType = 'image';

  bool _isTextMode = false;
  final TextEditingController _textController = TextEditingController();
  // ✅ Noir par défaut au lieu du violet Afrifan
  String _selectedColor = '#1A1A1A';

  bool _isUploading = false;

  // ✅ Palette sans violet
  final List<Map<String, String>> _availableColors = [
    {'name': 'Noir', 'hex': '#1A1A1A'},
    {'name': 'Jaune', 'hex': '#FBBF24'},
    {'name': 'Rouge', 'hex': '#EF4444'},
    {'name': 'Bleu', 'hex': '#3B82F6'},
    {'name': 'Blanc', 'hex': '#FFFFFF'},
  ];

  Color _getTextColor(String hexColor) {
    if (hexColor == '#FFFFFF' || hexColor == '#FBBF24') {
      return Colors.black;
    }
    return Colors.white;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool isVideo) async {
    try {
      final XFile? file = await _picker.pickMedia(
        imageQuality: 80,
      );
      if (file != null) {
        setState(() {
          _selectedFile = file;
          _mediaType = isVideo ? 'video' : 'image';
          _isTextMode = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur sélection média : $e");
    }
  }

  Future<void> _publishStory() async {
    if (!_isTextMode && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir une photo, une vidéo ou écrire un texte."), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isTextMode && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez écrire quelque chose."), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception("Utilisateur non connecté");

      String? publicUrl;

      if (!_isTextMode && _selectedFile != null) {
        final fileExtension = path.extension(_selectedFile!.path);
        final fileName = '$userId/story_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
        final file = File(_selectedFile!.path);

        await Supabase.instance.client.storage
            .from('stories')
            .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

        publicUrl = Supabase.instance.client.storage.from('stories').getPublicUrl(fileName);
      }

      await Supabase.instance.client.from('stories').insert({
        'creator_id': userId,
        'media_url': publicUrl,
        'media_type': _isTextMode ? 'text' : _mediaType,
        'text_content': _isTextMode ? _textController.text.trim() : null,
        'background_color': _isTextMode ? _selectedColor : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🎉 Statut publié avec succès ! (Visible 24h)"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("🚨 ERREUR PUBLICATION STATUT : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
    final unselectedTabBg = isDark ? Colors.grey.shade900 : Colors.grey.shade200;
    final unselectedTabText = isDark ? Colors.white : Colors.black87;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;

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
          'Nouveau Statut',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _publishStory,
              child: Text(
                'Publier',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isUploading
          ? Center(
              child: CircularProgressIndicator(color: accentColor),
            )
          : Column(
              children: [
                // ─── SÉLECTEUR TEXTE / MÉDIA ───
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isTextMode = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              // ✅ Tab actif : noir en clair / blanc en sombre
                              color: _isTextMode ? accentColor : unselectedTabBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Texte',
                                style: TextStyle(
                                  color: _isTextMode ? accentTextColor : unselectedTabText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isTextMode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isTextMode ? accentColor : unselectedTabBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Photo / Vidéo',
                                style: TextStyle(
                                  color: !_isTextMode ? accentTextColor : unselectedTabText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: dividerColor),

                Expanded(
                  child: _isTextMode
                      ? _buildTextEditor(isDark)
                      : _buildMediaPicker(isDark),
                ),
              ],
            ),
    );
  }

  // ─── ÉDITEUR TEXTE ───
  Widget _buildTextEditor(bool isDark) {
    return Container(
      width: double.infinity,
      color: Color(int.parse(_selectedColor.replaceAll('#', '0xFF'))),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _textController,
            maxLines: 8,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _getTextColor(_selectedColor),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Quoi de neuf ?',
              hintStyle: TextStyle(
                color: _getTextColor(_selectedColor).withOpacity(0.5),
              ),
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _availableColors.map((colorMap) {
                final hex = colorMap['hex']!;
                final isSelected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse(hex.replaceAll('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(
                        // ✅ Bordure de sélection : noir en clair / blanc en sombre
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SÉLECTEUR MÉDIA ───
  Widget _buildMediaPicker(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black45;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_selectedFile != null)
            Stack(
              children: [
                Container(
                  width: 250,
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(File(_selectedFile!.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (_mediaType == 'video')
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.videocam, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            )
          else
            Icon(Icons.image_outlined, color: subTextColor, size: 80),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPickButton(
                Icons.photo_camera,
                'Photo',
                () => _pickMedia(false),
                accentColor: accentColor,
                accentTextColor: accentTextColor,
                textColor: textColor,
              ),
              const SizedBox(width: 24),
              _buildPickButton(
                Icons.videocam,
                'Vidéo',
                () => _pickMedia(true),
                accentColor: accentColor,
                accentTextColor: accentTextColor,
                textColor: textColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required Color accentColor,
    required Color accentTextColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // ✅ Bouton : noir en clair / blanc en sombre
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentTextColor, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}