import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';

/// Onglet 3 : Abonnés
/// Affiche la liste des abonnés actifs avec leurs infos
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
  String _selectedFilter = 'all'; // 'all', 'premium', 'pro'

  @override
  void initState() {
    super.initState();
    _loadSubscribers();
  }

  Future<void> _loadSubscribers() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
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
    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF0A0A0A),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tous'),
              const SizedBox(width: 8),
              _buildFilterChip('premium', 'Premium'),
              const SizedBox(width: 8),
              _buildFilterChip('pro', 'Pro'),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
              : _subscribers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, color: Colors.grey, size: 64),
                          SizedBox(height: 16),
                          Text('Aucun abonné actif', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSubscribers,
                      color: const Color(0xFF8B5CF6),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: _subscribers.length,
                        itemBuilder: (context, index) {
                          final sub = _subscribers[index];
                          final profile = sub['profiles'] as Map<String, dynamic>?;
                          final endDate = DateTime.parse(sub['end_date']);
                          final daysLeft = endDate.difference(DateTime.now()).inDays;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                                  backgroundImage: profile?['avatar_url'] != null
                                      ? NetworkImage(profile!['avatar_url'])
                                      : null,
                                  child: profile?['avatar_url'] == null
                                      ? const Icon(Icons.person, color: Color(0xFF8B5CF6))
                                      : null,
                                ),
                                const SizedBox(width: 16),

                                // Infos
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile?['full_name'] ?? profile?['username'] ?? 'Utilisateur',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          // Badge Premium/Pro
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: sub['tier_type'] == 'pro'
                                                  ? const Color(0xFF8B5CF6)
                                                  : Colors.grey.shade800,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              sub['tier_type'] == 'pro' ? 'PRO' : 'PREMIUM',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Date d'expiration
                                          Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: daysLeft <= 7 ? Colors.orange : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            daysLeft <= 7
                                                ? 'Expire dans $daysLeft jours'
                                                : 'Expire le ${_formatDate(sub['end_date'])}',
                                            style: TextStyle(
                                              color: daysLeft <= 7 ? Colors.orange : Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Flèche
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadSubscribers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF2A2A2A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}