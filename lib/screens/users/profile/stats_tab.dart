import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/analytics_service.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'post_stats_detail_screen.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final supabase = Supabase.instance.client;

  int _selectedPeriod = 7;
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final inactiveBtnBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final inactiveBtnText = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── SÉLECTEUR DE PÉRIODE ───
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPeriodButton(7, isDark, accentColor, accentTextColor, inactiveBtnBg, inactiveBtnText),
                const SizedBox(width: 12),
                _buildPeriodButton(30, isDark, accentColor, accentTextColor, inactiveBtnBg, inactiveBtnText),
                const SizedBox(width: 12),
                _buildPeriodButton(90, isDark, accentColor, accentTextColor, inactiveBtnBg, inactiveBtnText),
              ],
            ),
            const SizedBox(height: 32),

            // ─── CARTES DE STATISTIQUES ───
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Vues totales',
                    _formatNumber(_stats['totalViews'] ?? 0),
                    Icons.visibility,
                    Colors.blue,
                    cardColor,
                    borderColor,
                    textColor,
                    subTextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Nouveaux abonnés',
                    _formatNumber(_stats['newFollowers'] ?? 0),
                    Icons.person_add,
                    Colors.green,
                    cardColor,
                    borderColor,
                    textColor,
                    subTextColor,
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
                    cardColor,
                    borderColor,
                    textColor,
                    subTextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Followers',
                    _formatNumber(_stats['totalFollowers'] ?? 0),
                    Icons.people,
                    // ✅ Violet remplacé par accent
                    accentColor,
                    cardColor,
                    borderColor,
                    textColor,
                    subTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── GRAPHIQUE ───
            Text(
              'Évolution des vues',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSimpleChart(isDark, accentColor, subTextColor, cardColor),
            const SizedBox(height: 32),

            // ─── TOP POSTS ───
            Text(
              'Vos meilleurs posts',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._topPosts.map((post) => _buildTopPostCard(
                  post,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(
    int days,
    bool isDark,
    Color accentColor,
    Color accentTextColor,
    Color inactiveBg,
    Color inactiveText,
  ) {
    final isSelected = _selectedPeriod == days;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() => _selectedPeriod = days);
          _loadStats();
        },
        style: ElevatedButton.styleFrom(
          // ✅ Actif : noir en clair / blanc en sombre
          backgroundColor: isSelected ? accentColor : inactiveBg,
          foregroundColor: isSelected ? accentTextColor : inactiveText,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          '$days jours',
          style: TextStyle(
            color: isSelected ? accentTextColor : inactiveText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Couleur sémantique conservée (bleu/vert/rouge/accent)
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: subTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleChart(bool isDark, Color accentColor, Color subTextColor, Color cardColor) {
    final viewsByDay = _stats['viewsByDay'] as Map<String, dynamic>? ?? {};
    if (viewsByDay.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('Pas assez de données', style: TextStyle(color: subTextColor)),
        ),
      );
    }

    int maxValue = 1;
    viewsByDay.values.forEach((value) {
      if (value > maxValue) maxValue = value;
    });

    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
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
                style: TextStyle(color: subTextColor, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: height,
                decoration: BoxDecoration(
                  // ✅ Barres du graphique : noir en clair / blanc en sombre
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.key.split('-').last,
                style: TextStyle(color: subTextColor, fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopPostCard(
    Map<String, dynamic> post, {
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final views = post['views_count'] ?? 0;
    final likes = post['likes_count'] ?? 0;
    final placeholderBg = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final placeholderIcon = isDark ? Colors.grey : Colors.black38;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostStatsDetailScreen(post: post),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // ─── MINIATURE ───
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
                        color: placeholderBg,
                        child: Icon(Icons.image, color: placeholderIcon),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: placeholderBg,
                      child: Icon(Icons.image, color: placeholderIcon),
                    ),
            ),
            const SizedBox(width: 12),

            // ─── INFOS ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // ✅ Bleu conservé (sémantique "vues")
                      const Icon(Icons.visibility, color: Colors.blue, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(views),
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      const SizedBox(width: 12),
                      // ✅ Rouge conservé (sémantique "likes")
                      const Icon(Icons.favorite, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(likes),
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Publié le ${_formatDate(post['created_at'])}',
                    style: TextStyle(color: subTextColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subTextColor),
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