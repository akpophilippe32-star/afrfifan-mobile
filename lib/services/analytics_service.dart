import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ========================================
  //  STATISTIQUES GLOBALES DU CRÉATEUR
  // ========================================
  
  Future<Map<String, dynamic>> getCreatorStats(String creatorId, {int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      
      // Récupérer les stats globales
      final statsResponse = await _supabase
          .from('creator_stats')
          .select('*')
          .eq('creator_id', creatorId)
          .maybeSingle();

      // Récupérer les vues par jour (pour le graphique)
      final viewsByDayResponse = await _supabase
          .from('post_views')
          .select('viewed_at')
          .inFilter(
            'post_id',
            (await _supabase
                .from('posts')
                .select('id')
                .eq('user_id', creatorId))
                .map((p) => p['id'].toString())
                .toList()
          )
          .gte('viewed_at', startDate.toIso8601String());

      // Calculer les vues par jour
      Map<String, int> viewsByDay = {};
      for (var i = 0; i < days; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        viewsByDay[dateKey] = 0;
      }

      for (var view in viewsByDayResponse) {
        final date = DateTime.parse(view['viewed_at']);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (viewsByDay.containsKey(dateKey)) {
          viewsByDay[dateKey] = (viewsByDay[dateKey] ?? 0) + 1;
        }
      }

      // Récupérer les nouveaux abonnés
      final newFollowersResponse = await _supabase
          .from('follows')
          .select('created_at')
          .eq('following_id', creatorId)
          .gte('created_at', startDate.toIso8601String());

      return {
        'totalViews': statsResponse?['total_views'] ?? 0,
        'totalLikes': statsResponse?['total_likes'] ?? 0,
        'totalFollowers': statsResponse?['total_followers'] ?? 0,
        'viewsByDay': viewsByDay,
        'newFollowers': newFollowersResponse.length,
      };
    } catch (e) {
      print('❌ Erreur getCreatorStats: $e');
      return {
        'totalViews': 0,
        'totalLikes': 0,
        'totalFollowers': 0,
        'viewsByDay': {},
        'newFollowers': 0,
      };
    }
  }

  // ========================================
  // 📈 STATISTIQUES D'UN POST SPÉCIFIQUE
  // ========================================
  
  Future<Map<String, dynamic>> getPostStats(String postId) async {
    try {
      // Récupérer les infos du post
      final postResponse = await _supabase
          .from('posts')
          .select('views_count, likes_count, comments_count, created_at')
          .eq('id', postId)
          .maybeSingle();

      // Compter les partages (si tu as une table post_shares)
      // final sharesCount = await _supabase...

      return {
        'views': postResponse?['views_count'] ?? 0,
        'likes': postResponse?['likes_count'] ?? 0,
        'comments': postResponse?['comments_count'] ?? 0,
        'createdAt': postResponse?['created_at'],
        'engagementRate': _calculateEngagementRate(
          postResponse?['views_count'] ?? 0,
          postResponse?['likes_count'] ?? 0,
          postResponse?['comments_count'] ?? 0,
        ),
      };
    } catch (e) {
      print('❌ Erreur getPostStats: $e');
      return {};
    }
  }

  double _calculateEngagementRate(int views, int likes, int comments) {
    if (views == 0) return 0.0;
    return ((likes + comments) / views) * 100;
  }

  // ========================================
  // 👁️ TRACKER UNE VUE
  // ========================================
  
  Future<void> trackView(String postId, String userId) async {
    try {
      await _supabase.rpc('increment_post_view', params: {
        'p_post_id': postId,
        'p_user_id': userId,
      });
    } catch (e) {
      print('❌ Erreur trackView: $e');
    }
  }

  // ========================================
  //  TOP POSTS
  // ========================================
  
  Future<List<Map<String, dynamic>>> getTopPosts(String creatorId, {int limit = 5}) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('id, media_url, views_count, likes_count, created_at')
          .eq('user_id', creatorId)
          .order('views_count', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getTopPosts: $e');
      return [];
    }
  }
}