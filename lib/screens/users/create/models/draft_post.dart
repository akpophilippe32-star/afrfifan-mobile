/// Modèle représentant un post en cours de création
class DraftPost {
  /// Type de post : 'image' (photo simple) ou 'slideshow' (plusieurs photos + musique)
  String postType;

  /// Chemins locaux des images sélectionnées
  /// Pour une photo simple : 1 seul chemin
  /// Pour un slideshow : 5 à 8 chemins
  List<String> mediaPaths;

  /// Chemin local de la musique (uniquement pour slideshow)
  String? musicPath;

  /// Nom du fichier musique (pour affichage)
  String? musicName;

  /// Légende du post
  String caption;

  /// Durée d'affichage de chaque photo dans le slideshow (en secondes)
  int slideDuration;

  /// État de publication
  bool isPublishing;

  /// Constructeur
  DraftPost({
    this.postType = 'image',
    List<String>? mediaPaths,
    this.musicPath,
    this.musicName,
    this.caption = '',
    this.slideDuration = 3,
    this.isPublishing = false,
  }) : mediaPaths = mediaPaths ?? [];

  /// Vérifie si le post est valide pour publication
  bool get isValid {
    // Vérifier qu'il y a au moins une image
    if (mediaPaths.isEmpty) return false;

    // Pour une photo simple : exactement 1 image
    if (postType == 'image' && mediaPaths.length != 1) return false;

    // Pour un slideshow : entre 5 et 8 images
    if (postType == 'slideshow') {
      if (mediaPaths.length < 5 || mediaPaths.length > 8) return false;
      // La musique est optionnelle pour le moment
      // On pourra la rendre obligatoire plus tard si besoin
    }

    return true;
  }

  /// Message d'erreur si le post n'est pas valide
  String? get validationError {
    if (mediaPaths.isEmpty) {
      return 'Veuillez sélectionner au moins une image.';
    }

    if (postType == 'image' && mediaPaths.length != 1) {
      return 'Pour une photo simple, sélectionnez exactement une image.';
    }

    if (postType == 'slideshow') {
      if (mediaPaths.length < 5) {
        return 'Pour un slideshow, sélectionnez au moins 5 images.';
      }
      if (mediaPaths.length > 8) {
        return 'Pour un slideshow, sélectionnez maximum 8 images.';
      }
    }

    return null;
  }

  /// Nombre d'images sélectionnées
  int get mediaCount => mediaPaths.length;

  /// Vérifie si c'est un slideshow
  bool get isSlideshow => postType == 'slideshow';

  /// Vérifie si c'est une photo simple
  bool get isSingleImage => postType == 'image';

  /// Vérifie si une musique est ajoutée
  bool get hasMusic => musicPath != null;

  /// Réinitialise le brouillon
  void reset() {
    postType = 'image';
    mediaPaths = [];
    musicPath = null;
    musicName = null;
    caption = '';
    slideDuration = 3;
    isPublishing = false;
  }

  /// Crée une copie avec des modifications
  DraftPost copyWith({
    String? postType,
    List<String>? mediaPaths,
    String? musicPath,
    String? musicName,
    String? caption,
    int? slideDuration,
    bool? isPublishing,
  }) {
    return DraftPost(
      postType: postType ?? this.postType,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      musicPath: musicPath ?? this.musicPath,
      musicName: musicName ?? this.musicName,
      caption: caption ?? this.caption,
      slideDuration: slideDuration ?? this.slideDuration,
      isPublishing: isPublishing ?? this.isPublishing,
    );
  }
}