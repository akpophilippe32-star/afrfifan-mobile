import 'dart:async'; // ✅ AJOUTE CETTE LIGNE ICI
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
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

  // ✅ Écoute les nouvelles ventes en temps réel
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
      // 1. Charger les stats générales (abonnés, etc.)
      final overview = await _dashboardService.getDashboardOverview(userId);
      
      // 2. Charger le solde du wallet
      final walletData = await supabase
          .from('wallets')
          .select('balance, total_earned')
          .eq('creator_id', userId)
          .maybeSingle();

      // ✅ DIAGNOSTIC : On affiche exactement ce que Supabase renvoie
      debugPrint('🔍 WALLET DATA REÇU DE SUPABASE : $walletData');
      debugPrint('🔍 OVERVIEW DATA REÇU DU SERVICE : $overview');

      // 3. Compter le nombre de ventes de produits
      final salesCountResponse = await supabase
          .from('product_purchases')
          .select('id')
          .eq('creator_id', userId)
          .eq('payment_status', 'completed');

      if (mounted) {
        setState(() {
          // On force l'utilisation des données du wallet SI elles existent
          final dbBalance = (walletData?['balance'] as num?)?.toDouble();
          final dbTotalEarned = (walletData?['total_earned'] as num?)?.toDouble();
          
          // Si dbBalance est null (à cause de RLS), on utilise le fallback
          _balance = dbBalance ?? overview['balance'] ?? 0.0;
          _totalEarned = dbTotalEarned ?? overview['totalEarnings'] ?? 0.0;
          
          _subscribersCount = overview['subscribers']?['total'] ?? 0;
          _productSalesCount = salesCountResponse.length;
          _isLoading = false;
          
          // ✅ DIAGNOSTIC : On affiche ce qui va être affiché à l'écran
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF8B5CF6),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💰 CARTE PORTEFEUILLE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(_formatMoney(_balance), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WithdrawalScreen())),
                          icon: const Icon(Icons.account_balance_wallet, size: 18),
                          label: const Text('Retrait', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voir l\'historique dans l\'onglet Portefeuille'), backgroundColor: Color(0xFF8B5CF6)));
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text('Mes Statistiques', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard('$_subscribersCount', 'Abonnés', Icons.people_outline),
                const SizedBox(width: 12),
                _buildStatCard(_formatMoney(_totalEarned), 'Gains totaux', Icons.trending_up),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard('$_productSalesCount', 'Ventes Boutique', Icons.shopping_bag_outlined),
                const SizedBox(width: 12),
                _buildStatCard(
                  _balance > 0 ? _formatMoney(_balance) : '0 FCFA', 
                  'À retirer', 
                  Icons.account_balance
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }
}