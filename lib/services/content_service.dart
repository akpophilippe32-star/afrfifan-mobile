import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // ✅ Pour télécharger les URLs
import 'dart:io'; // ✅ Pour créer des fichiers temporaires
import 'package:path_provider/path_provider.dart'; // ✅ Pour les fichiers temporaires
import '../screens/users/create/models/draft_post.dart';

class ContentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload une image (Compatible Web & Mobile)
  Future<String?> uploadImage(XFile imageFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'post_${userId}_$timestamp.jpg';
      final filePath = '$userId/$fileName';

      final bytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from('post-images')
          .uploadBinary(filePath, bytes);

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

  /// Upload une musique (Compatible Web & Mobile)
  Future<String?> uploadMusic(XFile musicFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = musicFile.name.split('.').last;
      final fileName = 'music_${userId}_$timestamp.$extension';
      final filePath = '$userId/$fileName';

      final bytes = await musicFile.readAsBytes();

      await _supabase.storage
          .from('post-music')
          .uploadBinary(filePath, bytes);

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

  /// Publie un post (Compatible Web & Mobile + URLs IA)
  Future<String?> publishPost(DraftPost draft) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('❌ Aucun utilisateur connecté');
      return null;
    }

    try {
      debugPrint(' Upload de ${draft.mediaPaths.length} média(s)...');
      final List<String> imageUrls = [];

      for (final mediaPath in draft.mediaPaths) {
        XFile xFile;
        
        // ✅ DÉTECTION URL vs FICHIER LOCAL
        if (mediaPath.startsWith('http://') || mediaPath.startsWith('https://')) {
          // C'est une URL (ex: image IA de Pollinations)
          debugPrint('🔽 Téléchargement de l\'image depuis URL...');
          
          final response = await http.get(Uri.parse(mediaPath));
          if (response.statusCode != 200) {
            debugPrint('❌ Échec téléchargement URL');
            return null;
          }
          
          // Créer un fichier temporaire
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/ai_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(response.bodyBytes);
          
          xFile = XFile(tempFile.path);
          debugPrint('✅ Image téléchargée dans fichier temporaire');
        } else {
          // C'est un fichier local
          xFile = XFile(mediaPath);
        }
        
        final url = await uploadImage(xFile, user.id);
        if (url == null) {
          debugPrint('❌ Échec upload média');
          return null;
        }
        imageUrls.add(url);
      }

      String? musicUrl;
      if (draft.isSlideshow && draft.musicPath != null) {
        debugPrint('🎵 Upload de la musique...');
        final musicXFile = XFile(draft.musicPath!);
        musicUrl = await uploadMusic(musicXFile, user.id);
      }

      debugPrint('💾 Création du post...');
      final postData = {
        'user_id': user.id,
        'media_url': imageUrls.first,
        'media_type': draft.postType,
        'content': draft.caption,
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

      if (draft.isSlideshow && imageUrls.length > 1) {
        final mediaList = <Map<String, dynamic>>[];
        for (int i = 0; i < imageUrls.length; i++) {
          mediaList.add({
            'post_id': postId,
            'media_url': imageUrls[i],
            'media_order': i,
          });
        }
        await _supabase.from('post_media').insert(mediaList);
      }

      return postId;
    } catch (e) {
      debugPrint(' Erreur publication: $e');
      return null;
    }
  }

  /// ✅ NOUVEAU : Publie une Story (Compatible Web & Mobile)
  Future<String?> publishStory({
    required XFile mediaFile,
    String? textContent,
    String? backgroundColor,
    required String userId,
  }) async {
    try {
      String mediaType = 'image';
      
      final mediaUrl = await uploadImage(mediaFile, userId);
      if (mediaUrl == null) return null;

      final storyData = {
        'creator_id': userId,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'text_content': textContent,
        'background_color': backgroundColor,
      };

      final response = await _supabase
          .from('stories')
          .insert(storyData)
          .select('id')
          .single();

      debugPrint('✅ Story publiée avec ID: ${response['id']}');
      return response['id'] as String;
    } catch (e) {
      debugPrint(' Erreur publication story: $e');
      return null;
    }
  }

  /// Supprime un post et tous ses fichiers associés
  Future<bool> deletePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final postResponse = await _supabase
          .from('posts')
          .select('user_id, media_url, music_url, media_type')
          .eq('id', postId)
          .maybeSingle();

      if (postResponse == null) {
        debugPrint('❌ Post introuvable');
        return false;
      }

      if (postResponse['user_id'] != user.id) {
        debugPrint('❌ Vous n\'êtes pas l\'auteur de ce post');
        return false;
      }

      final mediaResponse = await _supabase
          .from('post_media')
          .select('media_url')
          .eq('post_id', postId);

      final mediaList = List<Map<String, dynamic>>.from(mediaResponse);

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
          debugPrint('️ Erreur suppression fichier musique: $e');
        }
      }

      await _supabase
          .from('post_media')
          .delete()
          .eq('post_id', postId);

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
      
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1) return null;

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      return filePath.isNotEmpty ? filePath : null;
    } catch (e) {
      debugPrint('❌ Erreur extraction chemin fichier: $e');
      return null;
    }
  }
}

final contentService = ContentService();