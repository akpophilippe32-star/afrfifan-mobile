import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/content_service.dart';
import '../../../theme/app_colors.dart';
import 'models/draft_post.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen>
    with TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final ContentService _contentService = ContentService();
  final DraftPost _draft = DraftPost();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isSelectingMedia = false;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Demander les permissions nécessaires
  /// Demander les permissions nécessaires avec gestion d'erreur
Future<bool> _requestPermissions({bool needAudio = false}) async {
  // 1. Demander les permissions de base
  Map<Permission, PermissionStatus> statuses = await [
    Permission.camera,
    Permission.photos,
    Permission.storage,
  ].request();

  // 2. Ajouter la permission audio si nécessaire
  if (needAudio) {
    final audioStatus = await Permission.audio.request();
    statuses[Permission.audio] = audioStatus;
  }

  // 3. Vérifier si toutes les permissions sont accordées
  final allGranted = statuses.values.every((status) => status.isGranted);
  
  if (allGranted) {
    debugPrint('✅ Toutes les permissions accordées');
    return true;
  }

  // 4. Gérer les permissions refusées
  final deniedPermissions = statuses.entries
      .where((entry) => !entry.value.isGranted)
      .map((entry) => entry.key.toString())
      .toList();

  debugPrint('⚠️ Permissions refusées : $deniedPermissions');

  // 5. Vérifier si certaines permissions sont définitivement refusées
  final permanentlyDenied = statuses.entries
      .where((entry) => entry.value.isPermanentlyDenied)
      .toList();

  if (permanentlyDenied.isNotEmpty) {
    // Ouvrir les paramètres de l'app
    _showPermissionDeniedDialog();
    return false;
  }

  // Afficher un message simple
  _showErrorSnackBar(
    'Permissions requises pour continuer. Veuillez les accorder dans les paramètres.',
  );
  
  return false;
}

/// Afficher un dialogue pour ouvrir les paramètres
void _showPermissionDeniedDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text(
        'Permissions requises',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Afrifan a besoin d\'accéder à votre galerie et caméra. Veuillez activer les permissions dans les paramètres de l\'application.',
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Paramètres'),
        ),
      ],
    ),
  );
}

  /// Choisir le type de post
  void _selectPostType(String type) {
    setState(() {
      _draft.postType = type;
    });
  }

  /// Sélectionner une photo simple
  /// Sélectionner une photo simple
Future<void> _pickSinglePhoto() async {
  debugPrint('🔵 Tentative de sélection photo unique...');
  
  final hasPermission = await _requestPermissions();
  if (!hasPermission) {
    debugPrint('❌ Permission refusée, annulation');
    return;
  }

  setState(() => _isSelectingMedia = true);

  try {
    debugPrint('📸 Ouverture du picker galerie...');
    
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    debugPrint('📸 Résultat picker : ${image?.path ?? "null"}');

    if (image != null) {
      setState(() {
        _draft.mediaPaths = [image.path];
      });
      _showSuccessSnackBar('Photo sélectionnée');
    } else {
      debugPrint('⚠️ Aucune image sélectionnée');
    }
  } catch (e, stack) {
    debugPrint('❌ Erreur sélection photo: $e');
    debugPrint('Stack: $stack');
    _showErrorSnackBar('Erreur : ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isSelectingMedia = false);
    }
  }
}

  /// Sélectionner plusieurs photos pour le slideshow
  /// Sélectionner plusieurs photos pour le slideshow
Future<void> _pickMultiplePhotos() async {
  debugPrint('🔵 Tentative de sélection photos multiples...');
  
  final hasPermission = await _requestPermissions();
  if (!hasPermission) return;

  setState(() => _isSelectingMedia = true);

  try {
    debugPrint('📸 Ouverture du picker multi-images...');
    
    final List<XFile> images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      limit: 8, // Limite à 8 images maximum
    );

    debugPrint('📸 ${images.length} images sélectionnées');

    if (images.isEmpty) {
      debugPrint('⚠️ Aucune image sélectionnée');
      return;
    }

    if (images.length < 5) {
      _showErrorSnackBar('Sélectionnez au moins 5 photos pour un slideshow (${images.length} sélectionnée(s))');
      return;
    }

    if (images.length > 8) {
      _showErrorSnackBar('Maximum 8 photos pour un slideshow');
      return;
    }

    setState(() {
      _draft.mediaPaths = images.map((img) => img.path).toList();
    });
    
    _showSuccessSnackBar('${images.length} photos sélectionnées');
  } catch (e, stack) {
    debugPrint('❌ Erreur sélection photos: $e');
    debugPrint('Stack: $stack');
    _showErrorSnackBar('Erreur : ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isSelectingMedia = false);
    }
  }
}

  /// Sélectionner une musique
  /// Sélectionner une musique
Future<void> _pickMusic() async {
  debugPrint('🔵 Tentative de sélection musique...');
  
  final hasPermission = await _requestPermissions(needAudio: true);
  if (!hasPermission) return;

  try {
    debugPrint('🎵 Ouverture du picker audio...');
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    debugPrint('🎵 Résultat picker audio : ${result?.files.single.name ?? "null"}');

    if (result != null && result.files.single.path != null) {
      final musicPath = result.files.single.path!;
      final musicName = result.files.single.name;

      setState(() {
        _draft.musicPath = musicPath;
        _draft.musicName = musicName;
      });

      _showSuccessSnackBar('Musique ajoutée : $musicName');
    } else {
      debugPrint('⚠️ Aucune musique sélectionnée');
    }
  } catch (e, stack) {
    debugPrint('❌ Erreur sélection musique: $e');
    debugPrint('Stack: $stack');
    _showErrorSnackBar('Erreur : ${e.toString()}');
  }
}

  /// Prendre une photo avec la caméra
  /// Prendre une photo avec la caméra
Future<void> _takePhoto() async {
  debugPrint('🔵 Tentative de prise de photo...');
  
  final hasPermission = await _requestPermissions();
  if (!hasPermission) return;

  setState(() => _isSelectingMedia = true);

  try {
    debugPrint('📷 Ouverture de la caméra...');
    
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    debugPrint('📷 Résultat caméra : ${photo?.path ?? "null"}');

    if (photo != null) {
      setState(() {
        _draft.mediaPaths = [photo.path];
      });
      _showSuccessSnackBar('Photo prise');
    }
  } catch (e, stack) {
    debugPrint('❌ Erreur prise de photo: $e');
    debugPrint('Stack: $stack');
    _showErrorSnackBar('Erreur : ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isSelectingMedia = false);
    }
  }
}

  /// Publier le post
  Future<void> _publishPost() async {
    if (!_draft.isValid) {
      _showErrorSnackBar(_draft.validationError ?? 'Post invalide');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final postId = await _contentService.publishPost(_draft);

      if (postId != null) {
        _showSuccessSnackBar('Post publié avec succès ! 🎉');

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showErrorSnackBar('Erreur lors de la publication');
      }
    } catch (e) {
      debugPrint('❌ Erreur publication: $e');
      _showErrorSnackBar('Erreur lors de la publication');
    } finally {
      setState(() => _isPublishing = false);
    }
  }

  void _showErrorSnackBar(String message) {
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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isPublishing
            ? _buildPublishingOverlay()
            : FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Créer une publication',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Que souhaitez-vous partager aujourd\'hui ?',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildPostTypeSelector(),
                            const SizedBox(height: 30),
                            _buildMediaSection(),
                            const SizedBox(height: 30),
                            if (_draft.isSlideshow) ...[
                              _buildMusicSection(),
                              const SizedBox(height: 30),
                            ],
                            _buildCaptionSection(),
                            const SizedBox(height: 40),
                            _buildPublishButton(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPublishingOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Publication en cours...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload des fichiers vers Afrifan',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
          const Text(
            'Nouveau post',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPostTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildPostTypeCard(
            type: 'image',
            icon: Icons.photo_outlined,
            title: 'Photo',
            subtitle: 'Une seule image',
            isActive: _draft.isSingleImage,
            onTap: () => _selectPostType('image'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPostTypeCard(
            type: 'slideshow',
            icon: Icons.photo_library_outlined,
            title: 'Slideshow',
            subtitle: '5-8 photos + musique',
            isActive: _draft.isSlideshow,
            onTap: () => _selectPostType('slideshow'),
          ),
        ),
      ],
    );
  }

  Widget _buildPostTypeCard({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.2) : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.grey.shade500,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _draft.isSingleImage ? 'Votre photo' : 'Vos photos (${_draft.mediaCount}/8)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_draft.mediaPaths.isEmpty)
          _buildEmptyMediaPicker()
        else
          _buildMediaPreview(),
      ],
    );
  }

  /// Zone de sélection de média vide (CORRIGÉE avec Wrap)
  Widget _buildEmptyMediaPicker() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade700,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: Colors.grey.shade600,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _draft.isSingleImage
                ? 'Ajouter une photo'
                : 'Ajouter 5 à 8 photos',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          // ✅ Wrap au lieu de Row pour éviter les contraintes infinies
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildMediaButton(
                icon: Icons.photo_library,
                label: 'Galerie',
                onTap: _draft.isSingleImage ? _pickSinglePhoto : _pickMultiplePhotos,
              ),
              _buildMediaButton(
                icon: Icons.camera_alt,
                label: 'Caméra',
                onTap: _takePhoto,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bouton de sélection de média (UNE SEULE VERSION)
  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: _isSelectingMedia ? null : onTap,
      icon: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Column(
      children: [
        if (_draft.isSingleImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(_draft.mediaPaths.first),
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _draft.mediaPaths.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_draft.mediaPaths[index]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _draft.isSingleImage ? _pickSinglePhoto : _pickMultiplePhotos,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Changer les photos'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildMusicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Musique',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _draft.hasMusic ? Icons.music_note : Icons.music_note_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _draft.hasMusic
                          ? _draft.musicName ?? 'Musique ajoutée'
                          : 'Aucune musique',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _draft.hasMusic
                          ? 'Appuyez pour changer'
                          : 'Ajoutez une musique à votre slideshow',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _pickMusic,
                icon: Icon(
                  _draft.hasMusic ? Icons.refresh : Icons.add,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Légende',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) {
            setState(() {
              _draft.caption = value;
            });
          },
          maxLines: 3,
          maxLength: 500,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Écrivez une légende...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: Colors.grey.shade900,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            counterStyle: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildPublishButton() {
    final isValid = _draft.isValid;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isValid ? _publishPost : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isValid ? AppColors.primary : Colors.grey.shade800,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.publish, size: 20),
            const SizedBox(width: 8),
            Text(
              'Publier',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}