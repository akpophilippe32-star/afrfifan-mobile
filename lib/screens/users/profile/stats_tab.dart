import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/dashboard_service.dart';

/// Onglet 4 : Statistiques
/// Affiche les graphiques de revenus, abonnés et métriques clés
class StatsTab extends StatefulWidget {
  const StatsTab({Key? key}) : super(key: key);

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  Map<DateTime, double> _revenueByDay = {};
  double _conversionRate = 0;
  double _arpu = 0;
  double _retentionRate = 0;
  String _peakHours = 'N/A';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      // Revenus par jour (30 derniers jours)
      _revenueByDay = await _dashboardService.getRevenueByDay(userId, days: 30);

      // Métriques simples
      final stats = await _dashboardService.getSimpleStats(userId);
      _conversionRate = stats['conversionRate'];
      _arpu = stats['arpu'];
      _retentionRate = stats['retentionRate'];
      _peakHours = stats['peakHours'];

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur chargement stats: $e');
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
            // Graphique des revenus
            const Text(
              '📈 Revenus (30 derniers jours)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              height: 250,
              child: _revenueByDay.isEmpty
                  ? const Center(child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)))
                  : _buildRevenueChart(),
            ),
            const SizedBox(height: 32),

            // Métriques Clés
            const Text(
              '📊 Métriques Clés',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard('${_conversionRate.toStringAsFixed(1)}%', 'Conversion', Icons.trending_up),
                const SizedBox(width: 12),
                _buildMetricCard('${_arpu.toStringAsFixed(0)} FCFA', 'ARPU', Icons.attach_money),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetricCard('${_retentionRate.toStringAsFixed(1)}%', 'Rétention', Icons.repeat),
                const SizedBox(width: 12),
                _buildMetricCard(_peakHours, 'Heure pointe', Icons.schedule),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final sortedDays = _revenueByDay.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDays.length; i++) {
      final value = _revenueByDay[sortedDays[i]] ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (sortedDays.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                if (value.toInt() < sortedDays.length) {
                  final date = sortedDays[value.toInt()];
                  return Text('${date.day}/${date.month}', style: const TextStyle(color: Colors.grey, fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF8B5CF6),
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}