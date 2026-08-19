import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Envoyer une notification quand quelqu'un suit un utilisateur
  Future<bool> sendNewFollowerNotification({
    required String followerId,
    required String followedUserId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': followedUserId,
        'actor_id': followerId,
        'type': 'new_follower',
      });

      return true;
    } catch (e) {
      debugPrint('❌ Erreur sendNewFollowerNotification: $e');
      return false;
    }
  }

  /// Récupérer les notifications de l'utilisateur connecté
  Future<List<Map<String, dynamic>>> fetchMyNotifications({
    int limit = 30,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final notifications = List<Map<String, dynamic>>.from(response);

      if (notifications.isEmpty) return [];

      // Récupérer les IDs des personnes qui ont fait l'action
      final actorIds = notifications
          .map((notification) => notification['actor_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (actorIds.isEmpty) return notifications;

      // Récupérer les profils des acteurs
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', actorIds);

      final profiles = List<Map<String, dynamic>>.from(profilesResponse);

      final profilesMap = {
        for (final profile in profiles) profile['id'].toString(): profile,
      };

      // Ajouter le profil de l'acteur dans chaque notification
      return notifications.map((notification) {
        final actorId = notification['actor_id']?.toString();

        final enrichedNotification = Map<String, dynamic>.from(notification);
        enrichedNotification['actor_profile'] =
            actorId != null ? profilesMap[actorId] : null;

        return enrichedNotification;
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur fetchMyNotifications: $e');
      return [];
    }
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('❌ Erreur markAsRead: $e');
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('❌ Erreur markAllAsRead: $e');
    }
  }

  /// Récupérer le nombre de notifications non lues
  Future<int> getUnreadCount() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return 0;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false)
          .limit(100);

      return List<Map<String, dynamic>>.from(response).length;
    } catch (e) {
      debugPrint('❌ Erreur getUnreadCount: $e');
      return 0;
    }
  }

  /// Supprimer une notification
  Future<void> deleteNotification(String notificationId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('❌ Erreur deleteNotification: $e');
    }
  }
}

/// Instance globale facile à utiliser dans les écrans
final notificationService = NotificationService();