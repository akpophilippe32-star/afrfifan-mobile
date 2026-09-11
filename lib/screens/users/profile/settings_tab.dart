import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class SettingsTab extends StatefulWidget {
  const SettingsTab({Key? key}) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  final _premiumPriceController = TextEditingController();
  final _proPriceController = TextEditingController();

  String _userName = '';
  bool _isVerified = false;
  double _premiumPrice = 1000;
  double _proPrice = 5000;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _premiumPriceController.dispose();
    _proPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = await supabase
          .from('profiles')
          .select('username, full_name, is_verified, premium_price, pro_price')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        _userName = profile['full_name'] ?? profile['username'] ?? 'Utilisateur';
        _isVerified = profile['is_verified'] ?? false;
        _premiumPrice = (profile['premium_price'] ?? 1000).toDouble();
        _proPrice = (profile['pro_price'] ?? 5000).toDouble();

        _premiumPriceController.text = _premiumPrice.toStringAsFixed(0);
        _proPriceController.text = _proPrice.toStringAsFixed(0);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur chargement paramètres: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrices() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final premiumPrice = double.tryParse(_premiumPriceController.text);
    final proPrice = double.tryParse(_proPriceController.text);

    if (premiumPrice == null || premiumPrice < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le prix Premium doit être au minimum 500 FCFA'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (proPrice == null || proPrice < 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le prix Pro doit être au minimum 2000 FCFA'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await _dashboardService.updatePrices(
        creatorId: userId,
        premiumPrice: premiumPrice,
        proPrice: proPrice,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prix mis à jour avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Erreur lors de la mise à jour');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    final fieldBg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF);
    final dividerColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── MON COMPTE ───
          Text(
            'Mon Compte',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Nom',
                  _userName,
                  Icons.person,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  accentColor: accentColor,
                ),
                Divider(color: dividerColor, height: 24),
                _buildInfoRow(
                  'Statut',
                  _isVerified ? 'Vérifié ✓' : 'Non vérifié',
                  Icons.verified,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  accentColor: accentColor,
                  // ✅ Vert / Orange conservés (sémantique)
                  valueColor: _isVerified ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── TARIFS ───
          Text(
            'Mes Tarifs d\'Abonnement',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abonnement Premium',
                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accès au contenu exclusif de base',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _premiumPriceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Min. 500 FCFA',
                    hintStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: fieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: 'FCFA',
                    suffixStyle: TextStyle(color: subTextColor),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Abonnement Pro',
                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accès complet + messages privés + appels',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proPriceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Min. 2000 FCFA',
                    hintStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: fieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: 'FCFA',
                    suffixStyle: TextStyle(color: subTextColor),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── BOUTON SAUVEGARDER ───
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePrices,
                    style: ElevatedButton.styleFrom(
                      // ✅ Bouton : noir en clair / blanc en sombre
                      backgroundColor: accentColor,
                      foregroundColor: accentTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: accentTextColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Sauvegarder les prix',
                            style: TextStyle(
                              color: accentTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
  }) {
    return Row(
      children: [
        // ✅ Icône : noir en clair / blanc en sombre
        Icon(icon, color: accentColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}