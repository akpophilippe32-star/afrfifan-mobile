import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class SalesTab extends StatefulWidget {
  const SalesTab({super.key});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  double _totalRevenue = 0.0;
  int _totalSales = 0;
  List<Map<String, dynamic>> _productStats = [];

  String _debugMessage = '';
  int _rawRowCount = 0;

  StreamSubscription? _salesSubscription;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
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
          _loadSalesData();
        });
  }

  Future<void> _loadSalesData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('product_purchases')
          .select('''
            product_id,
            amount_paid,
            payment_status,
            digital_products (
              id,
              title,
              media_type
            )
          ''')
          .eq('creator_id', userId)
          .eq('payment_status', 'completed')
          .order('purchase_date', ascending: false);

      if (mounted) {
        _rawRowCount = response.length;

        if (response.isEmpty) {
          _debugMessage = '⚠️ 0 vente trouvée avec le statut "completed".\nVérifie si ton achat test est bien passé en "completed" dans Supabase.';
        } else {
          _debugMessage = '✅ ${response.length} vente(s) "completed" trouvée(s) en base de données.';
        }

        Map<String, Map<String, dynamic>> statsMap = {};
        double totalRev = 0.0;
        int totalSalesCount = 0;

        for (var purchase in response) {
          totalSalesCount++;

          final amount = (purchase['amount_paid'] as num?)?.toDouble() ?? 0.0;
          totalRev += amount;

          final productId = purchase['product_id'] as String? ?? 'inconnu';
          final product = purchase['digital_products'] as Map<String, dynamic>?;

          final title = product?['title'] ?? 'Produit inconnu (ID: $productId)';
          final mediaType = product?['media_type'] ?? 'file';

          if (!statsMap.containsKey(productId)) {
            statsMap[productId] = {
              'id': productId,
              'title': title,
              'media_type': mediaType,
              'sales_count': 0,
              'revenue': 0.0,
            };
          }

          statsMap[productId]!['sales_count'] += 1;
          statsMap[productId]!['revenue'] += amount;
        }

        setState(() {
          _productStats = statsMap.values.toList();
          _productStats.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

          _totalRevenue = totalRev;
          _totalSales = totalSalesCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _debugMessage = '❌ ERREUR : $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(0)} FCFA';
  }

  IconData _getIcon(String mediaType) {
    switch (mediaType) {
      case 'video': return Icons.video_library;
      case 'image': return Icons.image;
      case 'audio': return Icons.audio_file;
      default: return Icons.insert_drive_file;
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
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;
    final green = const Color(0xFF10B981);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚨 BOÎTE DE DIAGNOSTIC
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // ✅ Vert/orange conservés (sémantique : succès / warning)
              color: _rawRowCount > 0 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _rawRowCount > 0 ? Colors.green : Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔍 DIAGNOSTIC BASE DE DONNÉES',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _debugMessage,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
                Text(
                  'Somme calculée par Flutter : ${_formatPrice(_totalRevenue)}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 📊 CARTES DE STATISTIQUES GLOBALES
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Revenu Total',
                  value: _formatPrice(_totalRevenue),
                  icon: Icons.account_balance_wallet,
                  // ✅ Vert conservé (sémantique succès)
                  color: green,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Ventes Totales',
                  value: _totalSales.toString(),
                  icon: Icons.shopping_cart,
                  // ✅ Accent au lieu de violet
                  color: accentColor,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'Performance par produit',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_productStats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart, color: isDark ? Colors.grey : Colors.grey.shade400, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune vente pour le moment',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _productStats.length,
              itemBuilder: (context, index) {
                final stat = _productStats[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      // ─── ICÔNE MÉDIA ───
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          // ✅ Fond accent très léger
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIcon(stat['media_type']),
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // ─── INFOS ───
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat['title'],
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${stat['sales_count']} vente${stat['sales_count'] > 1 ? 's' : ''}',
                              style: TextStyle(color: subTextColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      // ─── REVENU ───
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(stat['revenue']),
                            style: TextStyle(
                              // ✅ Vert conservé (sémantique "gain")
                              color: green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Revenu',
                              style: TextStyle(
                                color: green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
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
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}