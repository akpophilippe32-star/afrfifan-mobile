import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  

  /// Envoyer un message à un utilisateur
  Future<bool> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      // Vérifier que le contenu n'est pas vide
      if (content.trim().isEmpty) return false;

      await _supabase.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': receiverId,
        'content': content.trim(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Erreur sendMessage: $e');
      return false;
    }
  }

  /// Récupérer la conversation entre l'utilisateur connecté et un autre utilisateur
  Future<List<Map<String, dynamic>>> fetchConversation({
    required String otherUserId,
    int limit = 100,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // Récupérer les messages dans les deux sens (envoyés + reçus)
      final response = await _supabase
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.${user.id},receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.${user.id})')
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = List<Map<String, dynamic>>.from(response);

      // Inverser pour avoir l'ordre chronologique (plus ancien en premier)
      return messages.reversed.toList();
    } catch (e) {
      debugPrint('❌ Erreur fetchConversation: $e');
      return [];
    }
  }

  /// Récupérer la liste des conversations (inbox)
  Future<List<Map<String, dynamic>>> fetchInbox() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // Récupérer tous les messages où l'utilisateur est impliqué
      final response = await _supabase
          .from('messages')
          .select('*')
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .order('created_at', ascending: false)
          .limit(500);

      final messages = List<Map<String, dynamic>>.from(response);
      if (messages.isEmpty) return [];

      // Grouper par interlocuteur et garder le dernier message
      final Map<String, Map<String, dynamic>> conversationsMap = {};
      final Map<String, int> unreadCountMap = {};

      for (final message in messages) {
        final senderId = message['sender_id'] as String;
        final receiverId = message['receiver_id'] as String;

        // Déterminer l'autre utilisateur
        final otherUserId = senderId == user.id ? receiverId : senderId;

        // Garder seulement le dernier message par conversation
        if (!conversationsMap.containsKey(otherUserId)) {
          conversationsMap[otherUserId] = message;
          unreadCountMap[otherUserId] = 0;
        }

        // Compter les messages non lus (où je suis le destinataire)
        if (receiverId == user.id && message['is_read'] == false) {
          unreadCountMap[otherUserId] = (unreadCountMap[otherUserId] ?? 0) + 1;
        }
      }

      // Récupérer les profils des interlocuteurs
      final otherUserIds = conversationsMap.keys.toList();
      if (otherUserIds.isEmpty) return [];

      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', otherUserIds);

      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {
        for (final profile in profiles) profile['id'].toString(): profile,
      };

      // Construire la liste finale des conversations
      final List<Map<String, dynamic>> conversations = [];

      conversationsMap.forEach((otherUserId, lastMessage) {
        conversations.add({
          'other_user_id': otherUserId,
          'other_user_profile': profilesMap[otherUserId],
          'last_message': lastMessage['content'],
          'last_message_time': lastMessage['created_at'],
          'last_message_is_mine': lastMessage['sender_id'] == user.id,
          'unread_count': unreadCountMap[otherUserId] ?? 0,
        });
      });

      // Trier par date du dernier message (plus récent en premier)
      conversations.sort((a, b) {
        final timeA = DateTime.parse(a['last_message_time'] as String);
        final timeB = DateTime.parse(b['last_message_time'] as String);
        return timeB.compareTo(timeA);
      });

      return conversations;
    } catch (e) {
      debugPrint('❌ Erreur fetchInbox: $e');
      return [];
    }
  }

  /// Marquer un message comme lu
  Future<void> markAsRead(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
    } catch (e) {
      debugPrint('❌ Erreur markAsRead: $e');
    }
  }

  /// Marquer tous les messages d'une conversation comme lus
  Future<void> markConversationAsRead(String otherUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('sender_id', otherUserId)
          .eq('receiver_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('❌ Erreur markConversationAsRead: $e');
    }
  }

  /// Récupérer le nombre total de messages non lus
  Future<int> getUnreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', user.id)
          .eq('is_read', false);

      return List<Map<String, dynamic>>.from(response).length;
    } catch (e) {
      debugPrint('❌ Erreur getUnreadCount: $e');
      return 0;
    }
  }

  /// Supprimer un message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .delete()
          .eq('id', messageId);
    } catch (e) {
      debugPrint('❌ Erreur deleteMessage: $e');
    }
  }
}

/// Instance globale facile à utiliser dans les écrans
final messagingService = MessagingService();