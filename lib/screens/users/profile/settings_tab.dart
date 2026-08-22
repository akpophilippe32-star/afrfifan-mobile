import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';

/// Onglet 5 : Paramètres
/// Permet de modifier les prix d'abonnement et voir les infos du créateur
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
      // ✅ CORRECTION : Suppression de 'email' de la requête
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Infos du compte
          const Text(
            'Mon Compte',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: [
                _buildInfoRow('Nom', _userName, Icons.person),
                const Divider(color: Color(0xFF2A2A2A), height: 24),
                // ✅ CORRECTION : Ligne Email supprimée ici
                _buildInfoRow(
                  'Statut',
                  _isVerified ? 'Vérifié ✓' : 'Non vérifié',
                  Icons.verified,
                  valueColor: _isVerified ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Prix d'abonnement
          const Text(
            'Mes Tarifs d\'Abonnement',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Abonnement Premium',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Accès au contenu exclusif de base',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _premiumPriceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Min. 500 FCFA',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0A0A0A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: 'FCFA',
                    suffixStyle: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Abonnement Pro',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Accès complet + messages privés + appels',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proPriceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Min. 2000 FCFA',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0A0A0A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: 'FCFA',
                    suffixStyle: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),

                // Bouton Sauvegarder
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePrices,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sauvegarder les prix',
                            style: TextStyle(
                              color: Colors.white,
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

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
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