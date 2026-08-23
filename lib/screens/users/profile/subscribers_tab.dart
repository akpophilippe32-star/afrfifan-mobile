import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
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

  // Variables pour les métriques
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
      // 1. Charger les métriques
      final metrics = await _dashboardService.getSubscriberMetrics(userId);
      _currentMonth = metrics['currentMonth'] ?? 0;
      _lastMonth = metrics['lastMonth'] ?? 0;
      _last6Months = metrics['last6Months'] ?? 0;

      // 2. Charger la liste des abonnés
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
        // ✅ SECTION 1 : MÉTRIQUES EN HAUT
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF0A0A0A),
          child: Row(
            children: [
              _buildMiniMetricCard('Ce mois', _currentMonth, Icons.trending_up, Colors.green),
              const SizedBox(width: 12),
              _buildMiniMetricCard('Mois dernier', _lastMonth, Icons.history, Colors.blue),
              const SizedBox(width: 12),
              _buildMiniMetricCard('6 derniers mo', _last6Months, Icons.calendar_month, const Color(0xFF8B5CF6)),
            ],
          ),
        ),

        // ✅ SECTION 2 : FILTRES
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0A0A0A),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tou'),
              const SizedBox(width: 8),
              _buildFilterChip('premium', 'Premium'),
              const SizedBox(width: 8),
              _buildFilterChip('pro', 'Pro'),
            ],
          ),
        ),

        // ✅ SECTION 3 : LISTE DES ABONNÉS
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
                      onRefresh: _loadData,
                      color: const Color(0xFF8B5CF6),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _subscribers.length,
                                                itemBuilder: (context, index) {
                          final sub = _subscribers[index];
                          final profile = sub['profiles'] as Map<String, dynamic>?;
                          final endDate = DateTime.parse(sub['end_date']);
                          final daysLeft = endDate.difference(DateTime.now()).inDays;
                          
                          // ✅ SÉCURISÉ : Utilise ?.toString() pour éviter le crash si c'est null
                          final fanId = sub['fan_id']?.toString() ?? '';

                          // ✅ RENDRE LA CARTE CLIQUABLE AVEC DÉBOGAGE
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
                                return; // On arrête ici si l'ID est vide
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
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF2A2A2A)),
                              ),
                              child: Row(
                                children: [
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
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                            Icon(
                                              Icons.calendar_today,
                                              size: 12,
                                              color: daysLeft <= 7 ? Colors.orange : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              daysLeft <= 7
                                                  ? 'Expire dans $daysLeft j'
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
                                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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

  // ✅ WIDGET POUR LES MÉTRIQUES DU HAUT
  Widget _buildMiniMetricCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadData();
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