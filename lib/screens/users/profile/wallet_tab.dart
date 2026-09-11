import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

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
  List<Map<String, dynamic>> _tips = [];
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
      final results = await Future.wait([
        _dashboardService.getRecentTransactions(userId, limit: 50),
        _dashboardService.getWithdrawalHistory(userId, limit: 50),
        _dashboardService.getReceivedTips(userId, limit: 50),
      ]);

      _transactions = results[0] as List<Map<String, dynamic>>;
      _withdrawals = results[1] as List<Map<String, dynamic>>;
      _tips = results[2] as List<Map<String, dynamic>>;
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
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    // ─── FUSION DE L'HISTORIQUE ───
    List<Map<String, dynamic>> history = [];

    for (var tx in _transactions) {
      history.add({...tx, 'type': 'income', 'date': tx['created_at']});
    }
    for (var w in _withdrawals) {
      history.add({...w, 'type': 'withdrawal', 'date': w['created_at']});
    }
    for (var tip in _tips) {
      history.add({...tip, 'type': 'tip', 'date': tip['created_at']});
    }

    history.sort((a, b) {
      final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: isDark ? Colors.grey : Colors.grey.shade400,
                size: 64),
            const SizedBox(height: 16),
            Text(
              'Aucune transaction pour le moment',
              style: TextStyle(color: subTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: accentColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          final type = item['type'];
          final isIncome = type == 'income';
          final isTip = type == 'tip';

          final double amountValue = (item['amount'] is num)
              ? (item['amount'] as num).toDouble()
              : double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;

          // ─── LOGIQUE D'AFFICHAGE ───
          IconData iconData;
          Color iconColor;
          Color iconBgColor;
          String titleText;
          String amountText;
          Color amountColor;

          if (isIncome) {
            // ✅ Abonnement : accent (noir/blanc)
            iconData = Icons.arrow_downward;
            iconColor = accentColor;
            iconBgColor = accentColor.withOpacity(0.1);
            titleText = 'Abonnement ${item['tier_type']?.toString().toUpperCase() ?? 'FAN'}';
            amountText = '+ ${_formatMoney(amountValue)}';
            // 🟢 Vert conservé (gain)
            amountColor = Colors.green;
          } else if (isTip) {
            // 🟠 Orange conservé (pourboire)
            iconData = Icons.local_cafe;
            iconColor = Colors.orangeAccent;
            iconBgColor = Colors.orangeAccent.withOpacity(0.1);
            final fanName = item['profiles'] != null
                ? (item['profiles']['full_name'] ?? item['profiles']['username'] ?? 'Un fan')
                : 'Un fan';
            titleText = 'Pourboire de $fanName';
            amountText = '+ ${_formatMoney(amountValue)}';
            // 🟢 Vert conservé (gain)
            amountColor = Colors.green;
          } else {
            // 🟠 Orange conservé (retrait)
            iconData = Icons.arrow_upward;
            iconColor = Colors.orange;
            iconBgColor = Colors.orange.withOpacity(0.1);
            titleText = 'Retrait vers ${item['payment_method']?.toString().toUpperCase() ?? 'Compte'}';
            amountText = '- ${_formatMoney(amountValue)}';
            // ⚪ Blanc en sombre / ⚫ Noir en clair
            amountColor = textColor;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // ─── ICÔNE ───
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: iconColor),
                ),
                const SizedBox(width: 16),

                // ─── DÉTAILS ───
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(item['date']?.toString()),
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                      if (!isIncome && !isTip) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Statut: ${_getStatusText(item['status']?.toString())}',
                          style: TextStyle(
                            color: _getStatusColor(item['status']?.toString(), subTextColor),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),

                // ─── MONTANT ───
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

  Color _getStatusColor(String? status, Color fallback) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'approved': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return fallback;
    }
  }
}