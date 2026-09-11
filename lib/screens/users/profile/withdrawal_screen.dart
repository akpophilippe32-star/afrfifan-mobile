import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/dashboard_service.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  final _amountController = TextEditingController();
  final _accountController = TextEditingController();

  String _selectedMethod = 'mtn';
  double _currentBalance = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      _currentBalance = await _dashboardService.getWalletBalance(userId);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le montant minimum de retrait est de 5 000 FCFA'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un numéro de compte valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _dashboardService.createWithdrawal(
        creatorId: userId,
        amount: amount,
        paymentMethod: _selectedMethod,
        accountNumber: _accountController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande de retrait envoyée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      if (mounted) setState(() => _isSubmitting = false);
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
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final fieldBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Demander un retrait',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── CARTE SOLDE ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      // ✅ Bordure accent au lieu du violet
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Solde disponible',
                          style: TextStyle(color: subTextColor, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentBalance.toStringAsFixed(0)} FCFA',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── MONTANT ───
                  Text(
                    'Montant à retirer',
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Min. 5000 FCFA',
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

                  // ─── MÉTHODE ───
                  Text(
                    'Méthode de paiement',
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMethod,
                        isExpanded: true,
                        dropdownColor: fieldBg,
                        style: TextStyle(color: textColor),
                        iconEnabledColor: textColor,
                        items: const [
                          DropdownMenuItem(value: 'mtn', child: Text('MTN Mobile Money')),
                          DropdownMenuItem(value: 'orange', child: Text('Orange Money')),
                          DropdownMenuItem(value: 'wave', child: Text('Wave')),
                          DropdownMenuItem(value: 'moov', child: Text('Moov Money')),
                        ],
                        onChanged: (value) => setState(() => _selectedMethod = value!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── NUMÉRO ───
                  Text(
                    'Numéro de compte / Téléphone',
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _accountController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Ex: 07 XX XX XX XX',
                      hintStyle: TextStyle(color: subTextColor),
                      filled: true,
                      fillColor: fieldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ─── BOUTON CONFIRMER ───
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitWithdrawal,
                      style: ElevatedButton.styleFrom(
                        // ✅ Bouton : noir en clair / blanc en sombre
                        backgroundColor: accentColor,
                        foregroundColor: accentTextColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: accentTextColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Confirmer le retrait',
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
    );
  }
}