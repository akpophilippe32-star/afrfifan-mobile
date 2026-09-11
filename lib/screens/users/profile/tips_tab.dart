import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import '../creator/creator_profile_screen.dart';

class TipsTab extends StatefulWidget {
  const TipsTab({super.key});

  @override
  State<TipsTab> createState() => _TipsTabState();
}

class _TipsTabState extends State<TipsTab> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      _tips = await _dashboardService.getReceivedTips(userId, limit: 100);
    } catch (e) {
      debugPrint('❌ Erreur chargement tips: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double amount) {
    return "${amount.toStringAsFixed(0)} FCFA";
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "Date inconnue";
    try {
      final date = DateTime.parse(dateString);
      const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
      return "${date.day} ${months[date.month - 1]} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
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
    final subTextColor = isDark ? Colors.grey.shade500 : Colors.black54;
    final verySubText = isDark ? Colors.grey.shade600 : Colors.black45;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (_tips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_cafe_outlined,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 80),
            const SizedBox(height: 16),
            Text(
              'Aucun pourboire reçu pour le moment',
              style: TextStyle(color: subTextColor, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Partagez votre profil pour en recevoir !',
              style: TextStyle(color: verySubText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTips,
      color: accentColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _tips.length,
        itemBuilder: (context, index) {
          final tip = _tips[index];
          final amount = (tip['amount'] is num)
              ? (tip['amount'] as num).toDouble()
              : double.tryParse(tip['amount']?.toString() ?? '0') ?? 0.0;

          final fanId = tip['fan_id']?.toString();

          final profileData = tip['profiles'];
          final fanName = profileData != null
              ? (profileData['full_name'] ?? profileData['username'] ?? 'Un fan anonyme')
              : 'Un fan anonyme';
          final fanAvatar = profileData?['avatar_url']?.toString();

          final message = tip['message']?.toString();
          final paymentMethod = tip['payment_method']?.toString() ?? 'Mobile Money';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── FAN CLIQUABLE ───
                GestureDetector(
                  onTap: () {
                    if (fanId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorProfileScreen(creatorId: fanId),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      // ─── AVATAR ───
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            // ✅ Fond accent très léger
                            backgroundColor: accentColor.withOpacity(0.15),
                            backgroundImage: fanAvatar != null ? NetworkImage(fanAvatar) : null,
                            child: fanAvatar == null
                                ? Icon(Icons.person, color: accentColor)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                              ),
                              // ✅ Icône accent adaptative
                              child: Icon(Icons.arrow_forward, color: accentColor, size: 14),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(width: 12),

                      // ─── INFOS FAN ───
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fanName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                // ✅ Soulignement accent
                                decorationColor: accentColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // 🟠 Orange conservé (paiement)
                                const Icon(Icons.payment, color: Colors.orangeAccent, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  paymentMethod,
                                  style: TextStyle(color: subTextColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── MONTANT ───
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '+ ${_formatMoney(amount)}',
                    style: const TextStyle(
                      // 🟢 Vert conservé (argent/gain)
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ─── MESSAGE ───
                if (message != null && message.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // ✅ Fond accent très léger
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Icône accent
                        Icon(Icons.format_quote, color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── DATE ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.access_time, color: verySubText, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(tip['created_at']?.toString()),
                      style: TextStyle(color: verySubText, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}