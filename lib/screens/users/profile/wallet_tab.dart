import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';

/// Onglet 2 : Portefeuille
/// Affiche l'historique complet des revenus, retraits et pourboires
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> _tips = []; // ✅ NOUVEAU : Pour les pourboires
  bool _isLoading = true;

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
      // ✅ Chargement en parallèle pour plus de rapidité
      final results = await Future.wait([
        _dashboardService.getRecentTransactions(userId, limit: 50),
        _dashboardService.getWithdrawalHistory(userId, limit: 50),
        _dashboardService.getReceivedTips(userId, limit: 50), // ✅ NOUVEAU
      ]);

      _transactions = results[0] as List<Map<String, dynamic>>;
      _withdrawals = results[1] as List<Map<String, dynamic>>;
      _tips = results[2] as List<Map<String, dynamic>>; // ✅ NOUVEAU

    } catch (e) {
      debugPrint('❌ Erreur chargement wallet: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatMoney(double amount) {
    return "${amount.toStringAsFixed(0)} FCFA";
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "Date inconnue";
    try {
      final date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return "Date invalide";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }

    // ✅ Fusionner transactions, retraits ET pourboires pour un historique chronologique
    List<Map<String, dynamic>> history = [];

    for (var tx in _transactions) {
      history.add({...tx, 'type': 'income', 'date': tx['created_at']});
    }
    for (var w in _withdrawals) {
      history.add({...w, 'type': 'withdrawal', 'date': w['created_at']});
    }
    // ✅ NOUVEAU : Ajouter les pourboires à l'historique
    for (var tip in _tips) {
      history.add({...tip, 'type': 'tip', 'date': tip['created_at']});
    }

    // Trier par date décroissante (le plus récent en premier)
    history.sort((a, b) {
      final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text('Aucune transaction pour le moment', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF8B5CF6),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          final type = item['type'];
          final isIncome = type == 'income';
          final isTip = type == 'tip';
          
          // Sécurisation de la conversion du montant en double
          final double amountValue = (item['amount'] is num) 
              ? (item['amount'] as num).toDouble() 
              : double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;

          // ✅ Logique d'affichage dynamique selon le type
          IconData iconData;
          Color iconColor;
          Color iconBgColor;
          String titleText;
          String amountText;
          Color amountColor;

          if (isIncome) {
            iconData = Icons.arrow_downward;
            iconColor = const Color(0xFF8B5CF6);
            iconBgColor = const Color(0xFF8B5CF6).withOpacity(0.1);
            titleText = 'Abonnement ${item['tier_type']?.toString().toUpperCase() ?? 'FAN'}';
            amountText = '+ ${_formatMoney(amountValue)}';
            amountColor = Colors.green;
          } else if (isTip) {
            iconData = Icons.local_cafe; // Icône café pour les pourboires
            iconColor = Colors.orangeAccent;
            iconBgColor = Colors.orangeAccent.withOpacity(0.1);
            final fanName = item['profiles'] != null 
                ? (item['profiles']['full_name'] ?? item['profiles']['username'] ?? 'Un fan')
                : 'Un fan';
            titleText = 'Pourboire de $fanName';
            amountText = '+ ${_formatMoney(amountValue)}';
            amountColor = Colors.green;
          } else {
            iconData = Icons.arrow_upward;
            iconColor = Colors.orange;
            iconBgColor = Colors.orange.withOpacity(0.1);
            titleText = 'Retrait vers ${item['payment_method']?.toString().toUpperCase() ?? 'Compte'}';
            amountText = '- ${_formatMoney(amountValue)}';
            amountColor = Colors.white;
          }

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
                // Icône dynamique
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: iconColor),
                ),
                const SizedBox(width: 16),

                // Détails
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(item['date']?.toString()),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      if (!isIncome && !isTip) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Statut: ${_getStatusText(item['status']?.toString())}',
                          style: TextStyle(
                            color: _getStatusColor(item['status']?.toString()),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),

                // Montant dynamique
                Text(
                  amountText,
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'approved': return 'Approuvé';
      case 'completed': return 'Terminé';
      case 'rejected': return 'Refusé';
      default: return 'Inconnu';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'approved': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}