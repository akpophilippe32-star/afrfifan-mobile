import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../theme/theme_notifier.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _status = 'draft';
  String _mediaType = 'file';
  bool _isSaving = false;
  bool _isUploading = false;

  String? _currentPreviewUrl;
  String? _currentFileUrl;
  XFile? _newPreviewFile;
  XFile? _newMediaFile;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  void _loadProductData() {
    final p = widget.product;
    _titleController.text = p['title'] as String? ?? '';
    _descriptionController.text = p['description'] as String? ?? '';
    _priceController.text = (p['price'] as num?)?.toString() ?? '';
    _status = p['status'] as String? ?? 'draft';
    _mediaType = p['media_type'] as String? ?? 'file';
    _currentPreviewUrl = p['preview_url'] as String?;
    _currentFileUrl = p['file_url'] as String?;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // SÉLECTION DES FICHIERS
  // ═══════════════════════════════════════════
  Future<void> _pickPreview() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) {
      setState(() => _newPreviewFile = file);
    }
  }

  Future<void> _pickMediaFile() async {
final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);    if (file != null) {
      setState(() {
        _newMediaFile = file;
        if (file.name.toLowerCase().endsWith('.mp4') ||
            file.name.toLowerCase().endsWith('.mov') ||
            file.name.toLowerCase().endsWith('.webm')) {
          _mediaType = 'video';
        } else if (file.name.toLowerCase().endsWith('.jpg') ||
            file.name.toLowerCase().endsWith('.png') ||
            file.name.toLowerCase().endsWith('.webp')) {
          _mediaType = 'image';
        } else {
          _mediaType = 'file';
        }
      });
    }
  }

  // ═══════════════════════════════════════════
  // UPLOAD DES FICHIERS
  // ═══════════════════════════════════════════
  Future<String?> _uploadFile(XFile file, String prefix) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.name.split('.').last;
final fileName = 'product_${userId}_$timestamp.$extension';
      final filePath = '$userId/$fileName';

      final bytes = await file.readAsBytes();

      String contentType = 'application/octet-stream';
      if (extension == 'jpg' || extension == 'jpeg') contentType = 'image/jpeg';
      else if (extension == 'png') contentType = 'image/png';
      else if (extension == 'webp') contentType = 'image/webp';
      else if (extension == 'mp4') contentType = 'video/mp4';
      else if (extension == 'mov') contentType = 'video/quicktime';
      else if (extension == 'webm') contentType = 'video/webm';

      await Supabase.instance.client.storage
          .from('post-media')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      return Supabase.instance.client.storage.from('post-media').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('❌ Erreur upload: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════
  // SAUVEGARDE
  // ═══════════════════════════════════════════
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? previewUrl = _currentPreviewUrl;
      String? fileUrl = _currentFileUrl;

      // Upload de la nouvelle preview si changée
      if (_newPreviewFile != null) {
        setState(() => _isUploading = true);
        previewUrl = await _uploadFile(_newPreviewFile!, 'preview');
        if (previewUrl == null) {
          _showError('Échec de l\'upload de la preview');
          return;
        }
      }

      // Upload du nouveau fichier média si changé
      if (_newMediaFile != null) {
        setState(() => _isUploading = true);
        fileUrl = await _uploadFile(_newMediaFile!, 'product');
        if (fileUrl == null) {
          _showError('Échec de l\'upload du fichier');
          return;
        }
      }

      // Mise à jour de la base de données
      await Supabase.instance.client
          .from('digital_products')
          .update({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'price': double.parse(_priceController.text),
            'status': _status,
            'media_type': _mediaType,
            'preview_url': previewUrl,
            'file_url': fileUrl,
          })
          .eq('id', widget.product['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Produit modifié avec succès'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde: $e');
      _showError('Erreur: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
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
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final fieldBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: accentColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Modifier le produit',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving || _isUploading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: accentColor, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.check, color: accentColor, size: 28),
              onPressed: _saveProduct,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══ ZONE PREVIEW ═══
            GestureDetector(
              onTap: _pickPreview,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Afficher la nouvelle preview ou l'ancienne
                      if (_newPreviewFile != null)
                        kIsWeb
                            ? Image.network(_newPreviewFile!.path, fit: BoxFit.cover)
                            : Image.file(File(_newPreviewFile!.path), fit: BoxFit.cover)
                      else if (_currentPreviewUrl != null && _currentPreviewUrl!.isNotEmpty)
                        Image.network(
                          _currentPreviewUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _previewPlaceholder(subTextColor),
                        )
                      else
                        _previewPlaceholder(subTextColor),

                      // Overlay avec icône caméra
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_camera, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Touchez pour changer la miniature',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),

            const SizedBox(height: 24),

            // ═══ TITRE ═══
            Text(
              'Titre du produit',
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Ex: Pack de presets photo',
                hintStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le titre est obligatoire';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ═══ DESCRIPTION ═══
            Text(
              'Description',
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ═══ PRIX ═══
            Text(
              'Prix (FCFA)',
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixText: 'FCFA',
                suffixStyle: TextStyle(color: subTextColor),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le prix est obligatoire';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Prix invalide';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ═══ FICHIER MÉDIA ═══
            Text(
              'Fichier du produit',
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickMediaFile,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      _mediaType == 'video'
                          ? Icons.video_library
                          : _mediaType == 'image'
                              ? Icons.image
                              : Icons.insert_drive_file,
                      color: accentColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _newMediaFile != null
                                ? _newMediaFile!.name
                                : (_currentFileUrl != null ? 'Fichier actuel' : 'Aucun fichier'),
                            style: TextStyle(color: textColor, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Type: $_mediaType • Touchez pour changer',
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.attach_file, color: subTextColor, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ═══ STATUT ═══
            Text(
              'Statut de publication',
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Brouillon', style: TextStyle(color: textColor)),
                    subtitle: Text(
                      'Visible uniquement par vous',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: 'draft',
                    groupValue: _status,
                    activeColor: accentColor,
                    onChanged: (value) => setState(() => _status = value!),
                  ),
                  RadioListTile<String>(
                    title: Text('Publié', style: TextStyle(color: textColor)),
                    subtitle: Text(
                      'Visible par tous les utilisateurs',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    value: 'published',
                    groupValue: _status,
                    activeColor: accentColor,
                    onChanged: (value) => setState(() => _status = value!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ═══ BOUTON SAUVEGARDER ═══
            ElevatedButton(
              onPressed: (_isSaving || _isUploading) ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: accentTextColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: (_isSaving || _isUploading)
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: accentTextColor, strokeWidth: 2),
                    )
                  : const Text(
                      'Enregistrer les modifications',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _previewPlaceholder(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: color, size: 48),
          const SizedBox(height: 8),
          Text(
            'Aucune miniature',
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}