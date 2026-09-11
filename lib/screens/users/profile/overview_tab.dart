import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'withdrawal_screen.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({Key? key}) : super(key: key);

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  double _balance = 0;
  double _totalEarned = 0;
  int _subscribersCount = 0;
  int _productSalesCount = 0;
  bool _isLoading = true;

  StreamSubscription? _salesSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToNewSales();
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }

  void _listenToNewSales() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _salesSubscription = supabase
        .from('product_purchases:creator_id=eq.$userId')
        .stream(primaryKey: ['id'])
        .listen((data) {
          debugPrint('🔔 Nouvelle vente détectée ! Rechargement du solde...');
          _loadData();
        });
  }

  Future<void> _loadData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final overview = await _dashboardService.getDashboardOverview(userId);

      final walletData = await supabase
          .from('wallets')
          .select('balance, total_earned')
          .eq('creator_id', userId)
          .maybeSingle();

      debugPrint('🔍 WALLET DATA REÇU DE SUPABASE : $walletData');
      debugPrint('🔍 OVERVIEW DATA REÇU DU SERVICE : $overview');

      final salesCountResponse = await supabase
          .from('product_purchases')
          .select('id')
          .eq('creator_id', userId)
          .eq('payment_status', 'completed');

      if (mounted) {
        setState(() {
          final dbBalance = (walletData?['balance'] as num?)?.toDouble();
          final dbTotalEarned = (walletData?['total_earned'] as num?)?.toDouble();

          _balance = dbBalance ?? overview['balance'] ?? 0.0;
          _totalEarned = dbTotalEarned ?? overview['totalEarnings'] ?? 0.0;

          _subscribersCount = overview['subscribers']?['total'] ?? 0;
          _productSalesCount = salesCountResponse.length;
          _isLoading = false;

          debugPrint('💰 BALANCE FINALE QUI VA S\'AFFICHER : $_balance');
          debugPrint('💰 TOTAL EARNED FINAL QUI VA S\'AFFICHER : $_totalEarned');
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement overview: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double amount) => "${amount.toStringAsFixed(0)} FCFA";

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

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── CARTE PORTEFEUILLE ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // ✅ Plus de gradient violet → noir en clair / gris en sombre
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                      : [const Color(0xFFE5E7EB), const Color(0xFFF3F4F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D5DB),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solde disponible',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatMoney(_balance),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      // ─── BOUTON RETRAIT ───
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WithdrawalScreen()),
                          ),
                          icon: Icon(Icons.account_balance_wallet, size: 18, color: accentTextColor),
                          label: Text(
                            'Retrait',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: accentTextColor,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            // ✅ Bouton : noir en clair / blanc en sombre
                            backgroundColor: accentColor,
                            foregroundColor: accentTextColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ─── BOUTON HISTORIQUE ───
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Voir l\'historique dans l\'onglet Portefeuille'),
                              ),
                            );
                          },
                          icon: Icon(Icons.history, size: 18, color: textColor),
                          label: Text(
                            'Historique',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: textColor, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ─── TITRE STATS ───
            Text(
              'Mes Statistiques',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildStatCard('$_subscribersCount', 'Abonnés', Icons.people_outline,
                    isDark: isDark, textColor: textColor, subTextColor: subTextColor, accentColor: accentColor),
                const SizedBox(width: 12),
                _buildStatCard(_formatMoney(_totalEarned), 'Gains totaux', Icons.trending_up,
                    isDark: isDark, textColor: textColor, subTextColor: subTextColor, accentColor: accentColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard('$_productSalesCount', 'Ventes Boutique', Icons.shopping_bag_outlined,
                    isDark: isDark, textColor: textColor, subTextColor: subTextColor, accentColor: accentColor),
                const SizedBox(width: 12),
                _buildStatCard(
                  _balance > 0 ? _formatMoney(_balance) : '0 FCFA',
                  'À retirer',
                  Icons.account_balance,
                  isDark: isDark, textColor: textColor, subTextColor: subTextColor, accentColor: accentColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon, {
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
  }) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Icône : noir en clair / blanc en sombre
            Icon(icon, color: accentColor, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}