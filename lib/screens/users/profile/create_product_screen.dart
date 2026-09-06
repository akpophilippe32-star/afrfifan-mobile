import 'dart:io';
import 'dart:typed_data'; // ✅ Ajouté pour les bytes (Web)
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ Ajouté pour détecter le Web
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

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
  File? _selectedFile;         // Pour Mobile
  Uint8List? _fileBytes;       // ✅ Pour le Web
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
          
          // ✅ GESTION CROSS-PLATFORM (Web vs Mobile)
          if (kIsWeb) {
            _fileBytes = pickedFile.bytes; // Sur le Web, on garde les bytes
          } else {
            if (pickedFile.path != null) {
              _selectedFile = File(pickedFile.path!); // Sur Mobile, on garde le chemin
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
    
    // Vérification qu'on a bien un fichier (soit en bytes, soit en path)
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

      // 1. Préparation du chemin dans le bucket
      final fileExtension = _fileName!.split('.').last;
      final filePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // 2. Upload du fichier (Méthode différente pour Web et Mobile)
      if (kIsWeb && _fileBytes != null) {
        // ✅ Upload depuis les bytes pour le Web
        await Supabase.instance.client.storage
            .from('digital_products')
            .uploadBinary(filePath, _fileBytes!);
      } else if (_selectedFile != null) {
        // ✅ Upload depuis le fichier pour le Mobile
        await Supabase.instance.client.storage
            .from('digital_products')
            .upload(filePath, _selectedFile!);
      } else {
        throw Exception('Format de fichier non supporté');
      }

      // 3. Récupérer l'URL du fichier
      final fileUrl = Supabase.instance.client.storage
          .from('digital_products')
          .getPublicUrl(filePath);

      // 4. Insérer le produit dans la base de données
      await Supabase.instance.client.from('digital_products').insert({
        'creator_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'media_type': _selectedFileType,
        'file_url': fileUrl,
        'preview_url': fileUrl, // Pour l'instant, on utilise la même URL pour l'aperçu
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouveau produit',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  SizedBox(height: 16),
                  Text(
                    'Publication en cours...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
                    // Titre
                    const Text(
                      'Titre du produit',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ex: Cours de cuisine africaine',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Veuillez entrer un titre';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Décrivez votre produit...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Prix
                    const Text(
                      'Prix (FCFA)',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Ex: 5000',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
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

                    // Fichier
                    const Text(
                      'Fichier du produit',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_selectedFile != null || _fileBytes != null) ? const Color(0xFF8B5CF6) : Colors.grey.shade700,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              (_selectedFile != null || _fileBytes != null) ? Icons.check_circle : Icons.cloud_upload,
                              color: (_selectedFile != null || _fileBytes != null) ? const Color(0xFF8B5CF6) : Colors.grey,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _fileName ?? 'Cliquez pour sélectionner un fichier',
                              style: TextStyle(
                                color: (_selectedFile != null || _fileBytes != null) ? Colors.white : Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedFile != null || _fileBytes != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Type: ${_selectedFileType?.toUpperCase()}',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Bouton Publier
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _publishProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Publier le produit',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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