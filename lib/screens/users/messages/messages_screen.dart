import 'package:flutter/material.dart';
import '../../../services/messaging_service.dart';
import '../../../theme/app_colors.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // ─── Paramètres de messagerie (état local — à persister via
  // SharedPreferences ou ton backend si besoin) ───
  bool _notifEnabled = true;
  bool _readReceipts = true;
  bool _showOnlineStatus = true;
  bool _allowFanRequests = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final conversations = await _messagingService.fetchInbox();
    if (mounted) {
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
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
      case 'online':
        return const Color(0xFF22C55E); // vert
      case 'away':
        return const Color(0xFFF59E0B); // orange
      case 'busy':
        return const Color(0xFFEF4444); // rouge
      default:
        return const Color(0xFFE5E7EB); // hors ligne (blanc)
    }
  }

  DateTime _parseTime(dynamic v) {
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (e) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.trim().isEmpty) return _conversations;
    final q = _searchQuery.toLowerCase();
    return _conversations.where((c) => _nameOf(c).toLowerCase().contains(q)).toList();
  }

  /// ✅ TOUTES les conversations, triées de la plus récente à la plus ancienne
  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_filtered);
    list.sort(
      (a, b) => _parseTime(b['last_message_time'])
          .compareTo(_parseTime(a['last_message_time'])),
    );
    return list;
  }

  /// ✅ RONDS DU HAUT : les dernières personnes à qui tu as écrit
  /// (plus de notion d'épinglé) — on prend les 6 plus récentes.
  List<Map<String, dynamic>> get _topRecents => _sorted.take(6).toList();

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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return '';
    }
  }

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

  // ─────────────────────────── BUILD ───────────────────────────

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
          'Messages',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Actualiser
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadConversations,
          ),
          // ⚙️ Paramètres dédiés à la messagerie
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: _openMessagingSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          // TODO : ouvrir "nouvelle conversation"
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadConversations,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          _buildSearchBar(),
          if (_conversations.isEmpty)
            _buildEmptyState()
          else ...[
            // ─── RONDS DU HAUT : derniers contacts à qui tu as écrit ───
            if (_topRecents.isNotEmpty) ...[
              _buildSectionTitle('RÉCENTS'),
              _buildTopRow(),
            ],
            if (_requestsCount > 0 && _allowFanRequests) _buildRequestsCard(),
            // ─── LISTE DU BAS : TOUTES les conversations ───
            _buildSectionTitle('TOUTES LES CONVERSATIONS'),
            if (_sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aucun résultat pour « $_searchQuery »',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ..._sorted.map(_buildRecentTile),
            _buildEndFooter(),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── WIDGETS ───────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Rechercher des messages...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// ─── RONDS DU HAUT (derniers contacts à qui tu as écrit) ───
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
                // Anneau violet si messages non lus, gris sinon
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: unread > 0
                        ? const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                        : null,
                  ),
                ),
                // Badge non lus (haut droite)
                if (unread > 0)
                  Positioned(top: -2, right: -2, child: _unreadBadge(unread)),
                // Pastille statut en ligne (bas droite)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _showOnlineStatus ? _statusColor(status) : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
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
              style: const TextStyle(color: Colors.white, fontSize: 13),
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
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
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
          border: Border.all(color: Colors.grey.shade900),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.person_add_alt_1, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demandes de messages',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_requestsCount nouvelles demandes des fans',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                // TODO : ouvrir l'écran des demandes de messages
              },
              child: const Text(
                'Voir',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ─── LISTE DU BAS : chaque personne avec qui tu as déjà écrit ───
  Widget _buildRecentTile(Map<String, dynamic> c) {
    final username = _nameOf(c);
    final avatarUrl = _avatarOf(c);
    final lastMessage = c['last_message']?.toString() ?? '';
    final lastMessageTime = c['last_message_time']?.toString() ?? '';
    final isMine = _asBool(c['last_message_is_mine']);
      final lastMessageType = c['last_message_type']?.toString() ?? 'text';
  final lastMessageDuration = c['last_message_duration'];
  
  // ✅ FORMATAGE DU MESSAGE SELON LE TYPE
  String formattedLastMessage;
  if (lastMessageType == 'voice') {
    final duration = lastMessageDuration ?? 0;
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    formattedLastMessage = '🎤 Message vocal • $minutes:$seconds';
  } else if (lastMessageType == 'call_log') {
    formattedLastMessage = '📞 Appel vocal';
  } else {
    formattedLastMessage = lastMessage;
  }
    final unread = _asInt(c['unread_count']);
    final isPremium =
        _asBool((c['other_user_profile'] as Map<String, dynamic>?)?['is_premium']);
    final status = _statusOf(c);

    return InkWell(
      onTap: () => _openChat(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar + pastille statut
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white, size: 26)
                      : null,
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
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Nom + badge PREMIUM + aperçu
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
                            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isPremium)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A2E0F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Color(0xFFF5B60F),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
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
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Heure + badge non lus
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimeAgo(lastMessageTime),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  _unreadBadge(unread),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, color: Colors.grey.shade800, size: 34),
          const SizedBox(height: 8),
          Text(
            'Vous avez atteint la fin',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
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
          Text('Aucune conversation', style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Suivez un créateur pour commencer à discuter',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─────────────── ⚙️ PARAMÈTRES DE MESSAGERIE ───────────────

  void _openMessagingSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        borderRadius: BorderRadius.circular(2),
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
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
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
                      // TODO : sauvegarder (SharedPreferences / backend)
                    },
                  ),
                  _settingsSwitch(
                    icon: Icons.done_all,
                    title: 'Accusés de lecture',
                    subtitle: 'Les autres voient quand tu as lu leurs messages',
                    value: _readReceipts,
                    onChanged: (v) {
                      setState(() => _readReceipts = v);
                      setSheetState(() {});
                    },
                  ),
                  _settingsSwitch(
                    icon: Icons.wifi_tethering,
                    title: 'Statut en ligne',
                    subtitle: 'Afficher ton statut et celui des autres',
                    value: _showOnlineStatus,
                    onChanged: (v) {
                      setState(() => _showOnlineStatus = v);
                      setSheetState(() {});
                    },
                  ),
                  _settingsSwitch(
                    icon: Icons.person_add_alt_1,
                    title: 'Demandes des fans',
                    subtitle: 'Autoriser les messages des non-abonnés',
                    value: _allowFanRequests,
                    onChanged: (v) {
                      setState(() => _allowFanRequests = v);
                      setSheetState(() {});
                    },
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
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      activeColor: AppColors.primary,
      secondary: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}