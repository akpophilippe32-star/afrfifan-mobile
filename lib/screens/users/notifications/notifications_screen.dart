import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/notification_service.dart';
import '../../../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _listenToRealtimeNotifications();
  }

  void _listenToRealtimeNotifications() {
    _notificationService.subscribeToNotifications((newNotification) {
      if (mounted) {
        setState(() {
          _notifications.insert(0, newNotification);
        });
      }
    });
  }

    Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('⚠️ Utilisateur non connecté');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Récupérer les notifications classiques
      final notifications = await _notificationService.fetchMyNotifications();
      debugPrint('✅ Notifications classiques chargées: ${notifications.length}');
      
      // 2. Récupérer les campagnes admin
      debugPrint('🔍 Recherche des campagnes pour l\'user: $userId');
      final campaignsResponse = await supabase
          .from('admin_campaigns')
          .select('*')
          .or('target_type.eq.all,target_user_id.eq.$userId')
          .order('created_at', ascending: false);
      
      final campaigns = List<Map<String, dynamic>>.from(campaignsResponse ?? []);
      debugPrint('✅ Campagnes admin trouvées: ${campaigns.length}');
      
      // 3. Fusionner les deux listes
      final allNotifications = [...notifications, ...campaigns];
      
      // 4. Trier par date (le plus récent en premier)
      allNotifications.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _notifications = allNotifications;
          _isLoading = false;
        });
        debugPrint('🎉 Total des notifications affichées: ${_notifications.length}');
      }
    } catch (e) {
      debugPrint('❌ ERREUR CRITIQUE chargement notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    await _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    await _loadNotifications();
  }

  Future<void> _deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
    await _loadNotifications();
  }

  String _getNotificationText(Map<String, dynamic> notification) {
    // 1. Priorité au titre envoyé par l'admin (campagnes)
    if (notification['title'] != null && notification['title'].toString().isNotEmpty) {
      return notification['title'];
    }

    // 2. Fallback pour les notifications classiques
    final actor = notification['actor_profile'] as Map<String, dynamic>?;
    final actorName = actor?['username'] ?? actor?['full_name'] ?? 'Utilisateur';
    final type = notification['type'];

    if (type == 'new_follower') return '$actorName vous suit maintenant';
    if (type == 'message') return '$actorName vous a envoyé un message';
    if (type == 'new_post') return '$actorName a publié un nouveau contenu';
    if (type == 'withdrawal_approved') return 'Retrait validé ✅';
    if (type == 'withdrawal_rejected') return 'Retrait refusé 🚫';
    if (type == 'withdrawal_failed') return 'Échec du transfert ❌';

    return 'Nouvelle notification';
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_follower': return Icons.person_add;
      case 'message': return Icons.message;
      case 'new_post': return Icons.photo_library;
      case 'withdrawal_approved': return Icons.check_circle;
      case 'withdrawal_rejected': return Icons.cancel;
      case 'withdrawal_failed': return Icons.error;
      case 'admin_campaign': return Icons.campaign; // ✅ Icône pour les campagnes admin
      default: return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_follower': return Colors.blue;
      case 'message': return Colors.green;
      case 'new_post': return Colors.orange;
      case 'withdrawal_approved': return Colors.green;
      case 'withdrawal_rejected': return Colors.red;
      case 'withdrawal_failed': return Colors.orange;
      case 'admin_campaign': return const Color(0xFF8B5CF6); // ✅ Violet pour les campagnes
      default: return Colors.grey;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours}h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays}j';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tout marquer comme lu',
                style: TextStyle(color: AppColors.primary, fontSize: 14),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 80,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les notifications apparaîtront ici',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final actor = notification['actor_profile'] as Map<String, dynamic>?;
                      final avatarUrl = actor?['avatar_url']?.toString();
                      final isRead = notification['is_read'] as bool? ?? false;
                      final type = notification['type'] as String? ?? 'admin_campaign';
                      final createdAt = DateTime.parse(notification['created_at']);

                      return GestureDetector(
                        onTap: () => _markAsRead(notification['id']),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.grey.shade900 : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRead ? Colors.white10 : AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey.shade700,
                                    backgroundImage: avatarUrl != null 
                                        ? NetworkImage(avatarUrl) 
                                        : null,
                                    child: avatarUrl == null
                                        ? const Icon(Icons.campaign, color: Colors.white)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: _getNotificationColor(type),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 2),
                                      ),
                                      child: Icon(
                                        _getNotificationIcon(type),
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getNotificationText(notification),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (notification['message'] != null && notification['message'].toString().isNotEmpty)
                                      Text(
                                        notification['message'],
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimeAgo(createdAt),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}