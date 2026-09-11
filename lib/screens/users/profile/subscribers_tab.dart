import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import '../creator/creator_profile_screen.dart';

class SubscribersTab extends StatefulWidget {
  const SubscribersTab({Key? key}) : super(key: key);

  @override
  State<SubscribersTab> createState() => _SubscribersTabState();
}

class _SubscribersTabState extends State<SubscribersTab> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _subscribers = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  int _currentMonth = 0;
  int _lastMonth = 0;
  int _last6Months = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final metrics = await _dashboardService.getSubscriberMetrics(userId);
      _currentMonth = metrics['currentMonth'] ?? 0;
      _lastMonth = metrics['lastMonth'] ?? 0;
      _last6Months = metrics['last6Months'] ?? 0;

      final filter = _selectedFilter == 'all' ? null : _selectedFilter;
      _subscribers = await _dashboardService.getActiveSubscribers(userId, tierFilter: filter);

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur chargement abonnés: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "Date inconnue";
    final date = DateTime.parse(dateString);
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final avatarBg = isDark ? accentColor.withOpacity(0.15) : accentColor.withOpacity(0.08);

    return Column(
      children: [
        // ─── SECTION 1 : MÉTRIQUES ───
        Container(
          padding: const EdgeInsets.all(16),
          color: bgColor,
          child: Row(
            children: [
              _buildMiniMetricCard('Ce mois', _currentMonth, Icons.trending_up, Colors.green,
                  isDark: isDark, cardColor: cardColor, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor),
              const SizedBox(width: 12),
              _buildMiniMetricCard('Mois dernier', _lastMonth, Icons.history, Colors.blue,
                  isDark: isDark, cardColor: cardColor, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor),
              const SizedBox(width: 12),
              _buildMiniMetricCard('6 derniers mo', _last6Months, Icons.calendar_month, accentColor,
                  isDark: isDark, cardColor: cardColor, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor),
            ],
          ),
        ),

        // ─── SECTION 2 : FILTRES ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: bgColor,
          child: Row(
            children: [
              _buildFilterChip('all', 'Tou', isDark, accentColor, accentTextColor, cardColor, borderColor, subTextColor),
              const SizedBox(width: 8),
              _buildFilterChip('premium', 'Premium', isDark, accentColor, accentTextColor, cardColor, borderColor, subTextColor),
              const SizedBox(width: 8),
              _buildFilterChip('pro', 'Pro', isDark, accentColor, accentTextColor, cardColor, borderColor, subTextColor),
            ],
          ),
        ),

        // ─── SECTION 3 : LISTE DES ABONNÉS ───
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: accentColor))
              : _subscribers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              color: isDark ? Colors.grey : Colors.grey.shade400,
                              size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun abonné actif',
                            style: TextStyle(color: subTextColor, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: accentColor,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _subscribers.length,
                        itemBuilder: (context, index) {
                          final sub = _subscribers[index];
                          final profile = sub['profiles'] as Map<String, dynamic>?;
                          final endDate = DateTime.parse(sub['end_date']);
                          final daysLeft = endDate.difference(DateTime.now()).inDays;

                          final fanId = sub['fan_id']?.toString() ?? '';
                          final isPro = sub['tier_type'] == 'pro';

                          return InkWell(
                            onTap: () {
                              debugPrint('👉 CLIC DÉTECTÉ ! fanId = $fanId');

                              if (fanId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Erreur : ID de l\'abonné introuvable'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreatorProfileScreen(creatorId: fanId),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  // ─── AVATAR ───
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: avatarBg,
                                    backgroundImage: profile?['avatar_url'] != null
                                        ? NetworkImage(profile!['avatar_url'])
                                        : null,
                                    child: profile?['avatar_url'] == null
                                        ? Icon(Icons.person, color: accentColor)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),

                                  // ─── INFOS ───
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile?['full_name'] ?? profile?['username'] ?? 'Utilisateur',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            // ─── BADGE TIER ───
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                // ✅ PRO : accent / PREMIUM : gris adaptatif
                                                color: isPro
                                                    ? accentColor
                                                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isPro ? 'PRO' : 'PREMIUM',
                                                style: TextStyle(
                                                  color: isPro
                                                      ? accentTextColor
                                                      : (isDark ? Colors.white : Colors.black87),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // 🟠 Orange conservé (warning d'expiration)
                                            Icon(
                                              Icons.calendar_today,
                                              size: 12,
                                              color: daysLeft <= 7 ? Colors.orange : subTextColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              daysLeft <= 7
                                                  ? 'Expire dans $daysLeft j'
                                                  : 'Expire le ${_formatDate(sub['end_date'])}',
                                              style: TextStyle(
                                                color: daysLeft <= 7 ? Colors.orange : subTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: subTextColor, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ─── CARTE MÉTRIQUE ───
  Widget _buildMiniMetricCard(
    String label,
    int count,
    IconData icon,
    Color color, {
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: subTextColor, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── FILTRE CHIP ───
  Widget _buildFilterChip(
    String value,
    String label,
    bool isDark,
    Color accentColor,
    Color accentTextColor,
    Color cardColor,
    Color borderColor,
    Color subTextColor,
  ) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // ✅ Actif : noir en clair / blanc en sombre
          color: isSelected ? accentColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentTextColor : subTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}