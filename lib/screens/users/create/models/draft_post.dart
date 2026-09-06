import 'package:image_picker/image_picker.dart'; // ✅ NÉCESSAIRE POUR XFile

/// Modèle représentant un post en cours de création
class DraftPost {
  /// Type de post : 'image', 'video', 'slideshow' ou 'text'
  String postType;

  /// Chemins locaux des images/vidéos sélectionnées
  List<String> mediaPaths;

  /// ✅ NOUVEAU : Fichiers bruts (indispensable pour l'upload Web/Mobile via .readAsBytes())
  List<XFile>? mediaFiles;

  /// Chemin local de la musique (uniquement pour slideshow)
  String? musicPath;

  /// Nom du fichier musique (pour affichage)
  String? musicName;

  /// ✅ NOUVEAU : URL du son en ligne (pour les sons choisis dans la caméra)
  String? musicUrl;

  /// Légende du post
  String caption;

  /// Durée d'affichage de chaque photo dans le slideshow (en secondes)
  int slideDuration;

  /// ✅ NOUVEAU : Couleur de fond pour les posts de type texte
  String? backgroundColor;

  /// État de publication
  bool isPublishing;

  /// Constructeur
  DraftPost({
    this.postType = 'image',
    List<String>? mediaPaths,
    this.mediaFiles,
    this.musicPath,
    this.musicName,
    this.musicUrl,
    this.caption = '',
    this.slideDuration = 3,
    this.backgroundColor,
    this.isPublishing = false,
  }) : mediaPaths = mediaPaths ?? [];

  /// Vérifie si le post est valide pour publication
  bool get isValid {
    if (postType == 'text') {
      return caption.trim().isNotEmpty;
    }
    if (mediaPaths.isEmpty && mediaFiles?.isEmpty != false) return false;
    if (postType == 'image' && mediaPaths.length != 1 && (mediaFiles?.length != 1)) return false;
    if (postType == 'slideshow') {
      final count = mediaFiles?.length ?? mediaPaths.length;
      if (count < 5 || count > 8) return false;
    }
    return true;
  }

  /// Message d'erreur si le post n'est pas valide
  String? get validationError {
    if (postType == 'text') {
      return caption.trim().isEmpty ? 'Veuillez écrire quelque chose.' : null;
    }
    final count = mediaFiles?.length ?? mediaPaths.length;
    if (count == 0) return 'Veuillez sélectionner au moins un média.';
    if (postType == 'image' && count != 1) {
      return 'Pour une publication simple, sélectionnez exactement un média.';
    }
    if (postType == 'slideshow') {
      if (count < 5) return 'Pour un slideshow, sélectionnez au moins 5 images.';
      if (count > 8) return 'Pour un slideshow, sélectionnez maximum 8 images.';
    }
    return null;
  }

  /// Nombre de médias sélectionnés
  int get mediaCount => mediaFiles?.length ?? mediaPaths.length;

  /// Vérifie si c'est un slideshow
  bool get isSlideshow => postType == 'slideshow';

  /// Vérifie si c'est une photo/vidéo simple
  bool get isSingleMedia => postType == 'image' || postType == 'video';

  /// Vérifie si c'est un post texte
  bool get isTextPost => postType == 'text';

  /// Vérifie si une musique est ajoutée (locale ou URL)
  bool get hasMusic => musicPath != null || musicUrl != null;

  /// Réinitialise le brouillon
  void reset() {
    postType = 'image';
    mediaPaths = [];
    mediaFiles = null;
    musicPath = null;
    musicName = null;
    musicUrl = null;
    caption = '';
    slideDuration = 3;
    backgroundColor = null;
    isPublishing = false;
  }

  /// Crée une copie avec des modifications
  DraftPost copyWith({
    String? postType,
    List<String>? mediaPaths,
    List<XFile>? mediaFiles,
    String? musicPath,
    String? musicName,
    String? musicUrl,
    String? caption,
    int? slideDuration,
    String? backgroundColor,
    bool? isPublishing,
  }) {
    return DraftPost(
      postType: postType ?? this.postType,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      musicPath: musicPath ?? this.musicPath,
      musicName: musicName ?? this.musicName,
      musicUrl: musicUrl ?? this.musicUrl,
      caption: caption ?? this.caption,
      slideDuration: slideDuration ?? this.slideDuration,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isPublishing: isPublishing ?? this.isPublishing,
    );
  }
}