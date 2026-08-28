import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/messaging_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/report_dialog.dart';
import 'chat_screen.dart';
import '../explore/trending_creators_screen.dart';
import '../creator/creator_profile_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with AutomaticKeepAliveClientMixin {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _searchController = TextEditingController();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasLoadedOnce = false;
  String _searchQuery = '';

  final Set<String> _pinnedIds = {};
  final Set<String> _mutedIds = {};
  final Set<String> _blockedIds = {};

  bool _notifEnabled = true;
  bool _readReceipts = true;
  bool _showOnlineStatus = true;
  bool _allowFanRequests = true;

  @override
  void initState() {
    super.initState();
    _pinnedIds.clear();
    _mutedIds.clear();
    _blockedIds.clear();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadConversations() async {
    if (_hasLoadedOnce) {
      debugPrint('⏭️ Messages déjà en mémoire, pas de rechargement');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final conversations = await _messagingService.fetchInbox();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // ─────────────────────────── HELPERS ───────────────────────────
  bool _asBool(dynamic v) => v == true || v == 1 || v == '1';
  int _asInt(dynamic v) => v is int ? v : (int.tryParse('${v ?? ''}') ?? 0);

  String _nameOf(Map<String, dynamic> c) {
    final p = c['other_user_profile'] as Map<String, dynamic>?;
    return (p?['username'] ?? p?['full_name'] ?? 'Utilisateur').toString();
  }

  String? _avatarOf(Map<String, dynamic> c) =>
      (c['other_user_profile'] as Map<String, dynamic>?)?['avatar_url']?.toString();

  String? _statusOf(Map<String, dynamic> c) {
    final p = c['other_user_profile'] as Map<String, dynamic>?;
    return (p?['online_status'] ?? c['online_status'])?.toString();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'online': return const Color(0xFF22C55E);
      case 'away': return const Color(0xFFF59E0B);
      case 'busy': return const Color(0xFFEF4444);
      default: return const Color(0xFFE5E7EB);
    }
  }

  DateTime _parseTime(dynamic v) {
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (e) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_filtered);
    list.sort((a, b) {
      final aPinned = _pinnedIds.contains(a['id']);
      final bPinned = _pinnedIds.contains(b['id']);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return _parseTime(b['last_message_time']).compareTo(_parseTime(a['last_message_time']));
    });
    return list;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.trim().isEmpty) return _conversations;
    final q = _searchQuery.toLowerCase();
    return _conversations.where((c) => _nameOf(c).toLowerCase().contains(q)).toList();
  }

  List<Map<String, dynamic>> get _topRecents =>
      _sorted.where((c) => !_asBool(c['is_request'])).take(6).toList();

  int get _requestsCount =>
      _conversations.where((c) => _asBool(c['is_request'])).length;

  String _formatTimeAgo(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}j';
      return '${dateTime.day}/${dateTime.month}';
    } catch (e) {
      return '';
    }
  }

  // ─────────────────────────── ACTIONS ───────────────────────────

  Future<void> _openChat(Map<String, dynamic> conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: conversation['other_user_id'] as String,
          otherUserName: _nameOf(conversation),
          otherUserAvatar: _avatarOf(conversation),
        ),
      ),
    );
    _loadConversations();
  }

  Future<void> _deleteConversation(Map<String, dynamic> conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Supprimer la conversation ?', style: TextStyle(color: Colors.white)),
        content: const Text('Cette action est irréversible et supprimera tous les messages.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _conversations.removeWhere((c) => c['id'] == conversation['id']);
        _pinnedIds.remove(conversation['id']);
        _mutedIds.remove(conversation['id']);
        _blockedIds.remove(conversation['id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation supprimée'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating
          ),
        );
      }
    }
  }

  void _showOptions(Map<String, dynamic> conversation) {
    final convId = conversation['id'] as String;
    final creatorId = conversation['other_user_id'] as String;
    final isPinned = _pinnedIds.contains(convId);
    final isMuted = _mutedIds.contains(convId);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: const Text('Voir le profil', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatorProfileScreen(creatorId: creatorId)
                )
              );
            },
          ),
          ListTile(
            leading: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: AppColors.primary
            ),
            title: Text(
              isPinned ? 'Désépingler' : 'Épingler',
              style: const TextStyle(color: Colors.white)
            ),
            onTap: () {
              setState(() {
                isPinned ? _pinnedIds.remove(convId) : _pinnedIds.add(convId);
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              isMuted ? Icons.notifications_off : Icons.notifications,
              color: Colors.orangeAccent
            ),
            title: Text(
              isMuted ? 'Réactiver les notifications' : 'Mettre en sourdine',
              style: const TextStyle(color: Colors.white)
            ),
            onTap: () {
              setState(() {
                isMuted ? _mutedIds.remove(convId) : _mutedIds.add(convId);
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: const Text('Bloquer', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              setState(() => _blockedIds.add(convId));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Utilisateur bloqué'),
                  backgroundColor: Colors.redAccent
                )
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            title: const Text('Signaler', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => ReportDialog(
                  targetId: creatorId,
                  targetType: 'user'
                )
              );
            },
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text(
              'Supprimer la conversation',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteConversation(conversation);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold
          )
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _hasLoadedOnce = false;
              _loadConversations();
            }
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: _openMessagingSettings
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TrendingCreatorsScreen()
            )
          );
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      const Text('Erreur de chargement', style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          _hasLoadedOnce = false;
                          _loadConversations();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    _hasLoadedOnce = false;
                    await _loadConversations();
                  },
                  // ✅ SOLUTION : Utiliser un CustomScrollView avec SliverList
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchBar(),
                            if (_conversations.isEmpty)
                              _buildEmptyState()
                            else ...[
                              if (_topRecents.isNotEmpty) ...[
                                _buildSectionTitle('RÉCENTS'),
                                _buildTopRow()
                              ],
                              if (_requestsCount > 0 && _allowFanRequests)
                                _buildRequestsCard(),
                              _buildSectionTitle('TOUTES LES CONVERSATIONS'),
                            ],
                          ],
                        ),
                      ),
                      if (_conversations.isNotEmpty)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (_sorted.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        const Icon(Icons.search_off, color: Colors.grey, size: 48),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Aucun résultat pour « $_searchQuery »',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 16
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              final c = _sorted[index];
                              return _buildConversationTile(c);
                            },
                            childCount: _sorted.isEmpty ? 1 : _sorted.length,
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _buildEndFooter(),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ─────────────────────────── WIDGETS ───────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Rechercher des messages...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: false,
            fillColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 1
        )
      )
    );
  }

  Widget _buildTopRow() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topRecents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) => _buildTopAvatar(_topRecents[i]),
      ),
    );
  }

  Widget _buildTopAvatar(Map<String, dynamic> c) {
    final username = _nameOf(c);
    final avatarUrl = _avatarOf(c);
    final unread = _asInt(c['unread_count']);
    final status = _statusOf(c);

    return GestureDetector(
      onTap: () => _openChat(c),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: unread > 0
                        ? const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight
                          )
                        : null,
                    color: unread > 0 ? null : Colors.grey.shade800,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.black,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, color: Colors.white, size: 30)
                        : null
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: _unreadBadge(unread)
                  ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _showOnlineStatus ? _statusColor(status) : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2)
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13)
            ),
          ],
        ),
      ),
    );
  }

  Widget _unreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2)
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold
        ),
        textAlign: TextAlign.center
      ),
    );
  }

  Widget _buildRequestsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141417),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade900)
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14)
              ),
              child: Icon(Icons.person_add_alt_1, color: AppColors.primary)
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demandes de messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold
                    )
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_requestsCount nouvelles demandes',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13
                    )
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
              ),
              onPressed: () { /* TODO: Ouvrir écran des demandes */ },
              child: const Text(
                'Voir',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Conversation Tile avec clé UNIQUE
  Widget _buildConversationTile(Map<String, dynamic> c) {
    return Container(
      key: ValueKey('conv_${c['id']}'), // ✅ Clé UNIQUE et STABLE
      child: InkWell(
        onTap: () => _openChat(c),
        onLongPress: () => _showOptions(c),
        child: _buildRecentTile(c),
      ),
    );
  }

  Widget _buildRecentTile(Map<String, dynamic> c) {
    final username = _nameOf(c);
    final avatarUrl = _avatarOf(c);
    final lastMessage = c['last_message']?.toString() ?? '';
    final lastMessageTime = c['last_message_time']?.toString() ?? '';
    final isMine = _asBool(c['last_message_is_mine']);
    final lastMessageType = c['last_message_type']?.toString() ?? 'text';
    final lastMessageDuration = c['last_message_duration'];
    final unread = _asInt(c['unread_count']);
    final isPremium = _asBool((c['other_user_profile'] as Map<String, dynamic>?)?['is_premium']);
    final status = _statusOf(c);
    final isPinned = _pinnedIds.contains(c['id']);
    final isMuted = _mutedIds.contains(c['id']);

    String formattedLastMessage = lastMessage;
    if (lastMessageType == 'voice') {
      final duration = lastMessageDuration ?? 0;
      formattedLastMessage = '🎤 Message vocal • ${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}';
    } else if (lastMessageType == 'call_log') {
      formattedLastMessage = '📞 Appel vocal';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white, size: 26)
                    : null
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _showOnlineStatus ? _statusColor(status) : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2)
                  ),
                ),
              ),
              if (isPinned)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle
                    ),
                    child: const Icon(Icons.push_pin, color: Colors.white, size: 12)
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600
                        )
                      ),
                    ),
                    if (isPinned)
                      const Icon(Icons.push_pin, color: AppColors.primary, size: 16),
                    if (isMuted)
                      const Icon(Icons.notifications_off, color: Colors.grey, size: 16),
                    if (isPremium)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A2E0F),
                          borderRadius: BorderRadius.circular(6)
                        ),
                        child: const Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: Color(0xFFF5B60F),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5
                          )
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isMine ? 'Vous : $formattedLastMessage' : formattedLastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread > 0 ? Colors.white70 : Colors.grey.shade500,
                    fontSize: 14
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (isMine && _readReceipts && unread == 0) ...[
                    const Icon(Icons.done_all, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _formatTimeAgo(lastMessageTime),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12
                    )
                  ),
                ],
              ),
              if (unread > 0) ...[
                const SizedBox(height: 6),
                _unreadBadge(unread)
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEndFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.grey.shade800, size: 34),
          const SizedBox(height: 8),
          Text(
            'Vous avez atteint la fin',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)
          )
        ]
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          const Text(
            'Aucune conversation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold
            )
          ),
          const SizedBox(height: 8),
          Text(
            'Suivez un créateur pour commencer à discuter',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)
          ),
        ],
      ),
    );
  }

  void _openMessagingSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(2)
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Paramètres de messagerie',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold
                          )
                        )
                      ]
                    ),
                  ),
                  const SizedBox(height: 8),
                  _settingsSwitch(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Recevoir une notification à chaque message',
                    value: _notifEnabled,
                    onChanged: (v) {
                      setState(() => _notifEnabled = v);
                      setSheetState(() {});
                    }
                  ),
                  _settingsSwitch(
                    icon: Icons.done_all,
                    title: 'Accusés de lecture',
                    subtitle: 'Les autres voient quand tu as lu leurs messages',
                    value: _readReceipts,
                    onChanged: (v) {
                      setState(() => _readReceipts = v);
                      setSheetState(() {});
                    }
                  ),
                  _settingsSwitch(
                    icon: Icons.wifi_tethering,
                    title: 'Statut en ligne',
                    subtitle: 'Afficher ton statut et celui des autres',
                    value: _showOnlineStatus,
                    onChanged: (v) {
                      setState(() => _showOnlineStatus = v);
                      setSheetState(() {});
                    }
                  ),
                  _settingsSwitch(
                    icon: Icons.person_add_alt_1,
                    title: 'Demandes des fans',
                    subtitle: 'Autoriser les messages des non-abonnés',
                    value: _allowFanRequests,
                    onChanged: (v) {
                      setState(() => _allowFanRequests = v);
                      setSheetState(() {});
                    }
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _settingsSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged
  }) {
    return SwitchListTile(
      activeColor: AppColors.primary,
      secondary: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Icon(icon, color: AppColors.primary)
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}