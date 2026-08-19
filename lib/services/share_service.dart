import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// URL de base de ton application (à modifier plus tard avec ton vrai domaine)
  static const String appBaseUrl = 'https://afrifan.app';

  /// Partager un post GRATUIT
  /// Partage l'image + la légende + le lien vers l'app
  Future<void> shareFreePost({
    required String postId,
    required String creatorName,
    required String caption,
    String? imageUrl,
  }) async {
    try {
      // Construire le message de partage
      final StringBuffer message = StringBuffer();

      // Ajouter la légende si elle existe
      if (caption.isNotEmpty) {
        message.writeln('"$caption"');
        message.writeln();
      }

      // Ajouter le nom du créateur
      message.writeln('🎬 Créé par $creatorName sur Afrifan');
      message.writeln();

      // Ajouter le lien vers le post
      message.writeln('👉 Voir plus sur Afrifan :');
      message.writeln('$appBaseUrl/post/$postId');
      message.writeln();

      // Ajouter les hashtags
      message.writeln('#Afrifan #Createurs #Afrique');

      // Lancer le partage
      await Share.share(
        message.toString(),
        subject: 'Regarde ce contenu sur Afrifan !',
      );

      debugPrint('✅ Partage gratuit lancé pour le post $postId');
    } catch (e) {
      debugPrint('❌ Erreur partage gratuit: $e');
    }
  }

  /// Partager un post PREMIUM
  /// Partage seulement un aperçu + le lien (pas le contenu complet)
  Future<void> sharePremiumPost({
    required String postId,
    required String creatorName,
    String? previewText,
  }) async {
    try {
      // Construire le message de partage (sans le contenu réel)
      final StringBuffer message = StringBuffer();

      // Message d'accroche
      message.writeln('🔒 Contenu exclusif de $creatorName sur Afrifan !');
      message.writeln();

      // Ajouter un aperçu si disponible
      if (previewText != null && previewText.isNotEmpty) {
        message.writeln('"$previewText"');
        message.writeln();
      }

      // Incitation à s'abonner
      message.writeln('💎 Abonnez-vous pour voir ce contenu exclusif !');
      message.writeln();

      // Ajouter le lien vers le post
      message.writeln('👉 Découvrir sur Afrifan :');
      message.writeln('$appBaseUrl/post/$postId');
      message.writeln();

      // Ajouter les hashtags
      message.writeln('#Afrifan #ContenuExclusif #Afrique');

      // Lancer le partage
      await Share.share(
        message.toString(),
        subject: 'Contenu exclusif sur Afrifan !',
      );

      debugPrint('✅ Partage premium lancé pour le post $postId');
    } catch (e) {
      debugPrint('❌ Erreur partage premium: $e');
    }
  }

  /// Partager le profil d'un créateur
  Future<void> shareCreatorProfile({
    required String creatorId,
    required String creatorName,
    String? bio,
  }) async {
    try {
      final StringBuffer message = StringBuffer();

      message.writeln('🌟 Découvrez $creatorName sur Afrifan !');
      message.writeln();

      if (bio != null && bio.isNotEmpty) {
        message.writeln('"$bio"');
        message.writeln();
      }

      message.writeln('👉 Suivre ce créateur :');
      message.writeln('$appBaseUrl/creator/$creatorId');
      message.writeln();
      message.writeln('#Afrifan #Createurs #Afrique');

      await Share.share(
        message.toString(),
        subject: 'Découvrez $creatorName sur Afrifan !',
      );

      debugPrint('✅ Partage profil lancé pour $creatorName');
    } catch (e) {
      debugPrint('❌ Erreur partage profil: $e');
    }
  }

  /// Partager l'application Afrifan elle-même
  Future<void> shareApp() async {
    try {
      final message = '''
🎬 Afrifan - La plateforme des créateurs africains !

Découvrez et soutenez vos créateurs préférés :
📸 Photos
🎵 Slideshows musicaux
🎥 Vidéos
💬 Messagerie directe

👉 Téléchargez Afrifan :
$appBaseUrl

#Afrifan #Createurs #Afrique''';

      await Share.share(
        message,
        subject: 'Découvrez Afrifan !',
      );

      debugPrint('✅ Partage de l\'app lancé');
    } catch (e) {
      debugPrint('❌ Erreur partage app: $e');
    }
  }
}

/// Instance globale facile à utiliser
final shareService = ShareService();