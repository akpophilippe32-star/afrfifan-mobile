import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/users/create/models/draft_post.dart';

class ContentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload une image dans Supabase Storage
  /// Retourne l'URL publique de l'image
  Future<String?> uploadImage(File imageFile, String userId) async {
    try {
      // Générer un nom de fichier unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'post_${userId}_$timestamp.jpg';
      final filePath = '$userId/$fileName';

      // Upload dans le bucket post-images
      await _supabase.storage
          .from('post-images')
          .upload(filePath, imageFile);

      // Obtenir l'URL publique
      final publicUrl = _supabase.storage
          .from('post-images')
          .getPublicUrl(filePath);

      debugPrint('✅ Image uploadée : $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Erreur upload image: $e');
      return null;
    }
  }

  /// Upload une musique dans Supabase Storage
  /// Retourne l'URL publique de la musique
  Future<String?> uploadMusic(File musicFile, String userId) async {
    try {
      // Générer un nom de fichier unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = musicFile.path.split('.').last;
      final fileName = 'music_${userId}_$timestamp.$extension';
      final filePath = '$userId/$fileName';

      // Upload dans le bucket post-music
      await _supabase.storage
          .from('post-music')
          .upload(filePath, musicFile);

      // Obtenir l'URL publique
      final publicUrl = _supabase.storage
          .from('post-music')
          .getPublicUrl(filePath);

      debugPrint('✅ Musique uploadée : $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Erreur upload musique: $e');
      return null;
    }
  }

  /// Publie un post (photo simple ou slideshow)
  /// Retourne l'ID du post créé, ou null si erreur
  Future<String?> publishPost(DraftPost draft) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('❌ Aucun utilisateur connecté');
      return null;
    }

    try {
      // 1. Upload des images
      debugPrint('📤 Upload de ${draft.mediaPaths.length} image(s)...');
      final List<String> imageUrls = [];

      for (final mediaPath in draft.mediaPaths) {
        final file = File(mediaPath);
        final url = await uploadImage(file, user.id);
        if (url == null) {
          debugPrint('❌ Échec upload image');
          return null;
        }
        imageUrls.add(url);
      }

      // 2. Upload de la musique si slideshow
      String? musicUrl;
      if (draft.isSlideshow && draft.musicPath != null) {
        debugPrint('🎵 Upload de la musique...');
        final musicFile = File(draft.musicPath!);
        musicUrl = await uploadMusic(musicFile, user.id);
        if (musicUrl == null) {
          debugPrint('❌ Échec upload musique');
          return null;
        }
      }

      // 3. Créer le post dans la table posts
      debugPrint('💾 Création du post...');
      final postData = {
  'user_id': user.id,
  'media_url': imageUrls.first,
  'media_type': draft.postType,
  'content': draft.caption,  // ← Changé de 'caption' à 'content'
  'caption': draft.caption,
  'music_url': musicUrl,
  'slide_duration': draft.slideDuration,
};

      final postResponse = await _supabase
          .from('posts')
          .insert(postData)
          .select('id')
          .single();

      final postId = postResponse['id'] as String;
      debugPrint('✅ Post créé avec ID: $postId');

      // 4. Si slideshow, ajouter toutes les images dans post_media
      if (draft.isSlideshow && imageUrls.length > 1) {
        debugPrint('🖼️ Ajout des ${imageUrls.length} images au slideshow...');
        final mediaList = <Map<String, dynamic>>[];

        for (int i = 0; i < imageUrls.length; i++) {
          mediaList.add({
            'post_id': postId,
            'media_url': imageUrls[i],
            'media_order': i,
          });
        }

        await _supabase.from('post_media').insert(mediaList);
        debugPrint('✅ Médias ajoutés au post');
      }

      debugPrint('🎉 Publication réussie !');
      return postId;
    } catch (e) {
      debugPrint('❌ Erreur publication: $e');
      return null;
    }
  }

  /// Supprime un post et tous ses fichiers associés
  Future<bool> deletePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      // 1. Récupérer les infos du post
      final postResponse = await _supabase
          .from('posts')
          .select('user_id, media_url, music_url, media_type')
          .eq('id', postId)
          .maybeSingle();

      if (postResponse == null) {
        debugPrint('❌ Post introuvable');
        return false;
      }

      // 2. Vérifier que l'utilisateur est bien l'auteur
      if (postResponse['user_id'] != user.id) {
        debugPrint('❌ Vous n\'êtes pas l\'auteur de ce post');
        return false;
      }

      // 3. Récupérer tous les médias du post (pour slideshow)
      final mediaResponse = await _supabase
          .from('post_media')
          .select('media_url')
          .eq('post_id', postId);

      final mediaList = List<Map<String, dynamic>>.from(mediaResponse);

      // 4. Supprimer les fichiers image de Storage
      final allImageUrls = <String>[
        if (postResponse['media_url'] != null) postResponse['media_url'] as String,
        ...mediaList.map((m) => m['media_url'] as String),
      ];

      for (final url in allImageUrls.toSet()) {
        try {
          final filePath = _extractFilePathFromUrl(url, 'post-images');
          if (filePath != null) {
            await _supabase.storage.from('post-images').remove([filePath]);
          }
        } catch (e) {
          debugPrint('⚠️ Erreur suppression fichier image: $e');
        }
      }

      // 5. Supprimer le fichier musique de Storage
      if (postResponse['music_url'] != null) {
        try {
          final musicPath = _extractFilePathFromUrl(
            postResponse['music_url'] as String,
            'post-music',
          );
          if (musicPath != null) {
            await _supabase.storage.from('post-music').remove([musicPath]);
          }
        } catch (e) {
          debugPrint('⚠️ Erreur suppression fichier musique: $e');
        }
      }

      // 6. Supprimer les entrées post_media
      await _supabase
          .from('post_media')
          .delete()
          .eq('post_id', postId);

      // 7. Supprimer le post
      await _supabase
          .from('posts')
          .delete()
          .eq('id', postId);

      debugPrint('✅ Post supprimé avec succès');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur suppression post: $e');
      return false;
    }
  }

  /// Récupère tous les médias d'un post (pour slideshow)
  Future<List<Map<String, dynamic>>> getPostMedia(String postId) async {
    try {
      final response = await _supabase
          .from('post_media')
          .select('*')
          .eq('post_id', postId)
          .order('media_order');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur récupération médias: $e');
      return [];
    }
  }

  /// Extrait le chemin du fichier depuis l'URL publique
  String? _extractFilePathFromUrl(String url, String bucketName) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Trouver l'index du bucket dans le chemin
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1) return null;

      // Le chemin du fichier est après le bucket
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      return filePath.isNotEmpty ? filePath : null;
    } catch (e) {
      debugPrint('❌ Erreur extraction chemin fichier: $e');
      return null;
    }
  }
}

/// Instance globale facile à utiliser
final contentService = ContentService();