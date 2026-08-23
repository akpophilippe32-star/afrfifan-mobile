import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/analytics_service.dart';
import 'post_stats_detail_screen.dart'; // On va créer cet écran après

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final supabase = Supabase.instance.client;
  
  int _selectedPeriod = 7; // 7, 30, ou 90 jours
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final stats = await _analyticsService.getCreatorStats(
        userId,
        days: _selectedPeriod,
      );
      final topPosts = await _analyticsService.getTopPosts(userId, limit: 5);

      setState(() {
        _stats = stats;
        _topPosts = topPosts;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF8B5CF6),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //  SÉLECTEUR DE PÉRIODE
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPeriodButton(7),
                const SizedBox(width: 12),
                _buildPeriodButton(30),
                const SizedBox(width: 12),
                _buildPeriodButton(90),
              ],
            ),
            const SizedBox(height: 32),

            //  CARTES DE STATISTIQUES
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Vues totales',
                    _formatNumber(_stats['totalViews'] ?? 0),
                    Icons.visibility,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Nouveaux abonnés',
                    _formatNumber(_stats['newFollowers'] ?? 0),
                    Icons.person_add,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Likes',
                    _formatNumber(_stats['totalLikes'] ?? 0),
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Followers',
                    _formatNumber(_stats['totalFollowers'] ?? 0),
                    Icons.people,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            //  GRAPHIQUE (Simple - à améliorer avec un package comme fl_chart)
            const Text(
              'Évolution des vues',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSimpleChart(),
            const SizedBox(height: 32),

            // 🔥 TOP POSTS
            const Text(
              'Vos meilleurs posts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._topPosts.map((post) => _buildTopPostCard(post)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(int days) {
    final isSelected = _selectedPeriod == days;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() => _selectedPeriod = days);
          _loadStats();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('$days jours'),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleChart() {
    final viewsByDay = _stats['viewsByDay'] as Map<String, dynamic>? ?? {};
    if (viewsByDay.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Pas assez de données', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Trouver la valeur max pour l'échelle
    int maxValue = 1;
    viewsByDay.values.forEach((value) {
      if (value > maxValue) maxValue = value;
    });

    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: viewsByDay.entries.map((entry) {
          final value = entry.value as int;
          final height = (value / maxValue) * 100;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.key.split('-').last, // Juste le jour
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

   Widget _buildTopPostCard(Map<String, dynamic> post) {
    final views = post['views_count'] ?? 0;
    final likes = post['likes_count'] ?? 0;
    
    return GestureDetector(
      onTap: () {
        // ✅ NAVIGATION VERS L'ÉCRAN DE DÉTAILS
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostStatsDetailScreen(post: post),
          ),
        );
      },
      child: Container(
        // ... (le reste du code de la carte ne change pas)
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            // Miniature
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: post['media_url'] != null
                  ? Image.network(
                      post['media_url'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility, color: Colors.blue, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(views),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(likes),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Publié le ${_formatDate(post['created_at'])}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Inconnue';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Inconnue';
    }
  }
}