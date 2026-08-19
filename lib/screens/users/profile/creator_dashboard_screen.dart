import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  final supabase = Supabase.instance.client;
  
  double _balance = 0;
  double _totalEarned = 0;
  int _subscribers = 0;
  bool _isLoading = true;
  String _userName = "Créateur";

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Récupérer le nom
      final profile = await supabase.from('profiles').select('full_name').eq('id', userId).maybeSingle();
      if (profile != null) _userName = profile['full_name'] ?? "Créateur";

      // 2. Récupérer le portefeuille (Wallet)
      final wallet = await supabase.from('wallets').select('balance, total_earned').eq('creator_id', userId).maybeSingle();
      if (wallet != null) {
        _balance = (wallet['balance'] ?? 0).toDouble();
        _totalEarned = (wallet['total_earned'] ?? 0).toDouble();
      }

      // 3. Récupérer le nombre d'abonnés actifs
      final subs = await supabase.from('subscriptions').select('id').eq('creator_id', userId).eq('status', 'active');
      _subscribers = subs.length;

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erreur chargement dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double amount) {
    return "${amount.toStringAsFixed(0)} FCFA";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Text(
          'Espace $_userName',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF8B5CF6),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 💰 CARTE PORTEFEUILLE (WALLET)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                        ],
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
                                  onPressed: _openWithdrawalModal,
                                  icon: const Icon(Icons.account_balance_wallet, size: 18),
                                  label: const Text('Retrait', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF8B5CF6),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    // Action pour voir l'historique
                                  },
                                  icon: const Icon(Icons.history, size: 18),
                                  label: const Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white),
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

                    // 📊 STATISTIQUES
                    const Text('Mes Statistiques', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatCard('$_subscribers', 'Abonnés', Icons.people_outline),
                        const SizedBox(width: 12),
                        _buildStatCard(_formatMoney(_totalEarned), 'Gains totaux', Icons.trending_up),
                      ],
                    ),
                    const SizedBox(height: 30),

                    //  ACTIONS RAPIDES
                    const Text('Gestion', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildActionTile(Icons.price_change, 'Mes tarifs d\'abonnement', 'Modifier les prix Premium et Pro'),
                    const SizedBox(height: 12),
                    _buildActionTile(Icons.lock_outline, 'Contenu exclusif', 'Gérer les posts réservés aux abonnés'),
                    const SizedBox(height: 12),
                    _buildActionTile(Icons.analytics, 'Analytique', 'Voir les performances détaillées'),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  void _openWithdrawalModal() {
    if (_balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre solde est insuffisant pour un retrait.'), backgroundColor: Colors.red),
      );
      return;
    }
    // Ici on ouvrira plus tard l'écran de demande de retrait
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité de retrait en cours de construction...'), backgroundColor: Color(0xFF8B5CF6)),
    );
  }
}