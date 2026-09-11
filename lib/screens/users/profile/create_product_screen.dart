import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedFileType;
  File? _selectedFile;
  Uint8List? _fileBytes;
  String? _fileName;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'jpg', 'jpeg', 'png', 'pdf', 'mp3', 'wav'],
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        final fileName = pickedFile.name;
        final fileExtension = fileName.split('.').last.toLowerCase();

        String fileType;
        if (['mp4', 'mov'].contains(fileExtension)) {
          fileType = 'video';
        } else if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
          fileType = 'image';
        } else if (['mp3', 'wav'].contains(fileExtension)) {
          fileType = 'audio';
        } else {
          fileType = 'file';
        }

        setState(() {
          _fileName = fileName;
          _selectedFileType = fileType;

          if (kIsWeb) {
            _fileBytes = pickedFile.bytes;
          } else {
            if (pickedFile.path != null) {
              _selectedFile = File(pickedFile.path!);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur sélection fichier: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sélection du fichier'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _publishProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if ((kIsWeb && _fileBytes == null) || (!kIsWeb && _selectedFile == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un fichier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final fileExtension = _fileName!.split('.').last;
      final filePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      if (kIsWeb && _fileBytes != null) {
        await Supabase.instance.client.storage
            .from('digital_products')
            .uploadBinary(filePath, _fileBytes!);
      } else if (_selectedFile != null) {
        await Supabase.instance.client.storage
            .from('digital_products')
            .upload(filePath, _selectedFile!);
      } else {
        throw Exception('Format de fichier non supporté');
      }

      final fileUrl = Supabase.instance.client.storage
          .from('digital_products')
          .getPublicUrl(filePath);

      await Supabase.instance.client.from('digital_products').insert({
        'creator_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'media_type': _selectedFileType,
        'file_url': fileUrl,
        'preview_url': fileUrl,
        'price': double.parse(_priceController.text),
        'currency': 'XOF',
        'status': 'published',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produit publié avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Erreur publication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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
    final subTextColor = isDark ? Colors.grey.shade500 : Colors.black54;
    final fieldBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    final hasFile = _selectedFile != null || _fileBytes != null;

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
          'Nouveau produit',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ Loader noir/blanc
                  CircularProgressIndicator(color: accentColor),
                  const SizedBox(height: 16),
                  Text(
                    'Publication en cours...',
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── TITRE ───
                    Text(
                      'Titre du produit',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Ex: Cours de cuisine africaine',
                        hintStyle: TextStyle(color: subTextColor),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Veuillez entrer un titre';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ─── DESCRIPTION ───
                    Text(
                      'Description',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(color: textColor),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Décrivez votre produit...',
                        hintStyle: TextStyle(color: subTextColor),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── PRIX ───
                    Text(
                      'Prix (FCFA)',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Ex: 5000',
                        hintStyle: TextStyle(color: subTextColor),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Veuillez entrer un prix';
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) return 'Prix invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ─── FICHIER ───
                    Text(
                      'Fichier du produit',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: fieldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            // ✅ Bordure accent si fichier sélectionné, sinon gris adaptatif
                            color: hasFile
                                ? accentColor
                                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              hasFile ? Icons.check_circle : Icons.cloud_upload,
                              color: hasFile
                                  ? accentColor
                                  : (isDark ? Colors.grey : Colors.black38),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _fileName ?? 'Cliquez pour sélectionner un fichier',
                              style: TextStyle(
                                color: hasFile ? textColor : subTextColor,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (hasFile) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Type: ${_selectedFileType?.toUpperCase()}',
                                style: TextStyle(color: subTextColor, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── BOUTON PUBLIER ───
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _publishProduct,
                        style: ElevatedButton.styleFrom(
                          // ✅ Bouton : noir en clair / blanc en sombre
                          backgroundColor: accentColor,
                          foregroundColor: accentTextColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Publier le produit',
                          style: TextStyle(
                            color: accentTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}