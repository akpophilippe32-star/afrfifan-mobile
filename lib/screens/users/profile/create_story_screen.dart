import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final ImagePicker _picker = ImagePicker();
  
  // États pour le mode Média
  XFile? _selectedFile;
  String _mediaType = 'image'; 
  
  // États pour le mode Texte
  bool _isTextMode = false;
  final TextEditingController _textController = TextEditingController();
  String _selectedColor = '#8B5CF6'; // Violet Afrifan par défaut

  bool _isUploading = false;

  // ✅ Les 5 couleurs disponibles (Format Hexadécimal)
  final List<Map<String, String>> _availableColors = [
    {'name': 'Violet', 'hex': '#8B5CF6'}, // Couleur Afrifan
    {'name': 'Jaune', 'hex': '#FBBF24'},
    {'name': 'Rouge', 'hex': '#EF4444'},
    {'name': 'Bleu', 'hex': '#3B82F6'},
    {'name': 'Blanc', 'hex': '#FFFFFF'},
  ];

  // Détermine si le texte doit être noir ou blanc selon le fond
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

  // ✅ 1. SÉLECTIONNER UN FICHIER (Photo ou Vidéo)
  Future<void> _pickMedia(bool isVideo) async {
    try {
      // ✅ CORRECTION 1 : videoQuality retiré car non supporté par pickMedia
      final XFile? file = await _picker.pickMedia(
        imageQuality: 80,
      );
      if (file != null) {
        setState(() {
          _selectedFile = file;
          _mediaType = isVideo ? 'video' : 'image';
          _isTextMode = false; // On bascule en mode média
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur sélection média : $e");
    }
  }

  // ✅ 2. UPLOADER ET ENREGISTRER LE STATUT
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Nouveau Statut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _publishStory,
              child: const Text('Publier', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : Column(
              children: [
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
                              color: _isTextMode ? const Color(0xFF8B5CF6) : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Text('Texte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
                              color: !_isTextMode ? const Color(0xFF8B5CF6) : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Text('Photo / Vidéo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),

                Expanded(
                  child: _isTextMode ? _buildTextEditor() : _buildMediaPicker(),
                ),
              ],
            ),
    );
  }

  // ✅ INTERFACE D'ÉDITION DE TEXTE
  Widget _buildTextEditor() {
    return Container(
      width: double.infinity,
      // ✅ CORRECTION 2 : int.parse() convertit la String en int pour la classe Color
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
            decoration: const InputDecoration(
              hintText: 'Quoi de neuf ?',
              hintStyle: TextStyle(color: Colors.white54),
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
                      // ✅ CORRECTION 3 : int.parse() ici aussi
                      color: Color(int.parse(hex.replaceAll('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8)] : null,
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

  // ✅ INTERFACE DE SÉLECTION MÉDIA
  Widget _buildMediaPicker() {
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
            const Icon(Icons.image_outlined, color: Colors.white54, size: 80),
          
          const SizedBox(height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPickButton(Icons.photo_camera, 'Photo', () => _pickMedia(false)),
              const SizedBox(width: 24),
              _buildPickButton(Icons.videocam, 'Vidéo', () => _pickMedia(true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}