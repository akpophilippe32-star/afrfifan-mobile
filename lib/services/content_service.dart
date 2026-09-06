import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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

      // ✅ CORRECTION : Bucket 'post-media' et contentType 'image/jpeg'
      await _supabase.storage
          .from('post-media')
          .uploadBinary(
            filePath, 
            bytes, 
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true)
          );

      final publicUrl = _supabase.storage.from('post-media').getPublicUrl(filePath);
      debugPrint('✅ Image uploadée : $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Erreur upload image: $e');
      return null;
    }
  }

  /// ✅ Upload une vidéo (Compatible Web & Mobile)
  Future<String?> uploadVideo(XFile videoFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'post_${userId}_$timestamp.mp4';
      final filePath = '$userId/$fileName';

      final bytes = await videoFile.readAsBytes();

      // ✅ CORRECTION : Bucket 'post-media' (et non 'post-images')
      await _supabase.storage
          .from('post-media')
          .uploadBinary(
            filePath, 
            bytes,
            fileOptions: const FileOptions(contentType: 'video/mp4', upsert: true),
          );

      final publicUrl = _supabase.storage.from('post-media').getPublicUrl(filePath);
      debugPrint('✅ Vidéo uploadée : $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Erreur upload vidéo: $e');
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
          .uploadBinary(
            filePath, 
            bytes,
            fileOptions: FileOptions(contentType: 'audio/mpeg', upsert: true),
          );

      final publicUrl = _supabase.storage.from('post-music').getPublicUrl(filePath);
      debugPrint('✅ Musique uploadée : $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Erreur upload musique: $e');
      return null;
    }
  }

  /// Publie un post (Compatible Web & Mobile + URLs IA + VIDÉOS)
  Future<String?> publishPost(DraftPost draft) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('❌ Aucun utilisateur connecté');
      return null;
    }

    try {
      final List<String> mediaUrls = [];
      final bool isVideo = draft.postType == 'video';

      // ✅ PRIORITÉ 1 : Utiliser draft.mediaFiles si disponible (plus fiable pour le Web/blob)
      if (draft.mediaFiles != null && draft.mediaFiles!.isNotEmpty) {
        debugPrint('📤 Upload de ${draft.mediaFiles!.length} fichier(s) depuis mediaFiles...');
        for (final xFile in draft.mediaFiles!) {
          String? url;
          if (isVideo) {
            url = await uploadVideo(xFile, user.id);
          } else {
            url = await uploadImage(xFile, user.id);
          }
          
          if (url != null) {
            mediaUrls.add(url);
          } else {
            debugPrint('❌ Échec upload média');
            return null;
          }
        }
      } 
      // ✅ PRIORITÉ 2 : Fallback sur draft.mediaPaths (pour compatibilité IA ou anciens flux)
      else if (draft.mediaPaths.isNotEmpty) {
        debugPrint('📤 Upload de ${draft.mediaPaths.length} média(s) depuis mediaPaths...');
        for (final mediaPath in draft.mediaPaths) {
          XFile xFile;
          
          if (mediaPath.startsWith('http://') || mediaPath.startsWith('https://') || mediaPath.startsWith('blob:')) {
            debugPrint('🔽 Téléchargement depuis URL: $mediaPath');
            final response = await http.get(Uri.parse(mediaPath));
            if (response.statusCode != 200) {
              debugPrint('❌ Échec téléchargement URL');
              return null;
            }
            
            final tempDir = await getTemporaryDirectory();
            final extension = isVideo ? 'mp4' : 'jpg';
            final tempFile = File('${tempDir.path}/media_${DateTime.now().millisecondsSinceEpoch}.$extension');
            await tempFile.writeAsBytes(response.bodyBytes);
            
            xFile = XFile(tempFile.path);
          } else {
            xFile = XFile(mediaPath);
          }
          
          String? url;
          if (isVideo) {
            url = await uploadVideo(xFile, user.id);
          } else {
            url = await uploadImage(xFile, user.id);
          }
          
          if (url != null) {
            mediaUrls.add(url);
          } else {
            debugPrint('❌ Échec upload média');
            return null;
          }
        }
      }

      String? musicUrl;
      if (draft.isSlideshow && draft.musicPath != null) {
        debugPrint('🎵 Upload de la musique...');
        final musicXFile = XFile(draft.musicPath!);
        musicUrl = await uploadMusic(musicXFile, user.id);
      }

      debugPrint('💾 Création du post en base de données...');
      final postData = {
        'user_id': user.id,
        'media_url': mediaUrls.isNotEmpty ? mediaUrls.first : null,
        'media_type': draft.postType,
        'content': draft.caption,
        'caption': draft.caption,
        'music_url': musicUrl ?? draft.musicUrl,
        'slide_duration': draft.slideDuration,
        'background_color': draft.backgroundColor,
      };

      final postResponse = await _supabase
          .from('posts')
          .insert(postData)
          .select('id')
          .single();

      final postId = postResponse['id'] as String;
      debugPrint('✅ Post créé avec ID: $postId');

      if (draft.isSlideshow && mediaUrls.length > 1) {
        final mediaList = <Map<String, dynamic>>[];
        for (int i = 0; i < mediaUrls.length; i++) {
          mediaList.add({
            'post_id': postId,
            'media_url': mediaUrls[i],
            'media_order': i,
          });
        }
        await _supabase.from('post_media').insert(mediaList);
      }

      return postId;
    } catch (e) {
      debugPrint('❌ Erreur publication: $e');
      return null;
    }
  }

  /// Publie une Story (Compatible Web & Mobile)
  Future<String?> publishStory({
    required XFile mediaFile,
    String? textContent,
    String? backgroundColor,
    required String userId,
  }) async {
    try {
      final isVideo = mediaFile.name.toLowerCase().endsWith('.mp4') || 
                      mediaFile.name.toLowerCase().endsWith('.mov') ||
                      mediaFile.name.toLowerCase().endsWith('.webm');
                      
      String mediaType = isVideo ? 'video' : 'image';
      String? mediaUrl;

      if (isVideo) {
        mediaUrl = await uploadVideo(mediaFile, userId);
      } else {
        mediaUrl = await uploadImage(mediaFile, userId);
      }

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
      debugPrint('❌ Erreur publication story: $e');
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

      final allMediaUrls = <String>[
        if (postResponse['media_url'] != null) postResponse['media_url'] as String,
        ...mediaList.map((m) => m['media_url'] as String),
      ];

      // ✅ CORRECTION : Utiliser 'post-media' pour la suppression
      for (final url in allMediaUrls.toSet()) {
        try {
          final filePath = _extractFilePathFromUrl(url, 'post-media');
          if (filePath != null) {
            await _supabase.storage.from('post-media').remove([filePath]);
          }
        } catch (e) {
          debugPrint('⚠️ Erreur suppression fichier média: $e');
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
          debugPrint('⚠️ Erreur suppression fichier musique: $e');
        }
      }

      await _supabase.from('post_media').delete().eq('post_id', postId);
      await _supabase.from('posts').delete().eq('id', postId);

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