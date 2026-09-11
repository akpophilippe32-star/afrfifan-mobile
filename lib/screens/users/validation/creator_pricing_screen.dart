import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'payment_info_step.dart';

class CreatorPricingScreen extends StatefulWidget {
  final String fullName;
  final String? birthDate;
  final String city;
  final String category;
  final String? idCardUrl;
  final bool phoneVerified;

  const CreatorPricingScreen({
    Key? key,
    required this.fullName,
    required this.birthDate,
    required this.city,
    required this.category,
    required this.idCardUrl,
    required this.phoneVerified,
  }) : super(key: key);

  @override
  State<CreatorPricingScreen> createState() => _CreatorPricingScreenState();
}

class _CreatorPricingScreenState extends State<CreatorPricingScreen> {
  final supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> _currencies = [
    {'code': 'XOF', 'symbol': 'FCFA', 'name': 'Franc CFA', 'rate': 1.0},
    {'code': 'XAF', 'symbol': 'FCFA', 'name': 'Franc CFA (CEMAC)', 'rate': 1.0},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'rate': 0.00152},
    {'code': 'USD', 'symbol': '\$', 'name': 'Dollar US', 'rate': 0.00165},
    {'code': 'GBP', 'symbol': '£', 'name': 'Livre Sterling', 'rate': 0.00129},
  ];

  String _selectedCurrencyCode = 'XOF';
  Map<String, dynamic> get _currentCurrency =>
      _currencies.firstWhere((c) => c['code'] == _selectedCurrencyCode);

  final TextEditingController _premiumPriceController = TextEditingController();
  final TextEditingController _proPriceController = TextEditingController();

  bool _isLoading = false;

  static const int _premiumMinFCFA = 90;
  static const int _premiumMaxFCFA = 2000;
  static const int _proMinFCFA = 2001;
  static const int _proMaxFCFA = 10000;

  double _convertToCurrency(int fcfaAmount) =>
      (fcfaAmount * _currentCurrency['rate']).toDouble();
  int _convertToFCFA(double amount) =>
      (amount / _currentCurrency['rate']).round();

  String _getPremiumMin() => _convertToCurrency(_premiumMinFCFA).toStringAsFixed(2);
  String _getPremiumMax() => _convertToCurrency(_premiumMaxFCFA).toStringAsFixed(2);
  String _getProMin() => _convertToCurrency(_proMinFCFA).toStringAsFixed(2);
  String _getProMax() => _convertToCurrency(_proMaxFCFA).toStringAsFixed(2);

  bool _validatePrices() {
    final premiumPrice = double.tryParse(_premiumPriceController.text);
    final proPrice = double.tryParse(_proPriceController.text);
    if (premiumPrice == null || proPrice == null) return false;

    if (premiumPrice < double.parse(_getPremiumMin()) ||
        premiumPrice > double.parse(_getPremiumMax())) return false;
    if (proPrice < double.parse(_getProMin()) ||
        proPrice > double.parse(_getProMax())) return false;
    return true;
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

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(isDark),
              const SizedBox(height: 24),
              _buildTitle(isDark),
              const SizedBox(height: 24),
              _buildCurrencySelector(isDark),
              const SizedBox(height: 24),
              _buildTierCard(
                title: 'Niveau Premium',
                description: 'Accès aux publications standards et aux lives réservés.',
                controller: _premiumPriceController,
                minText: _getPremiumMin(),
                maxText: _getPremiumMax(),
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildTierCard(
                title: 'Niveau Pro / VIP',
                description: 'Accès total à tout le contenu, messagerie privée et avantages exclusifs.',
                controller: _proPriceController,
                minText: _getProMin(),
                maxText: _getProMax(),
                isDark: isDark,
              ),
              const SizedBox(height: 30),
              _buildContinueButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Définissez vos tarifs',
          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choisissez combien vos abonnés paieront pour accéder à vos contenus exclusifs.',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildContinueButton(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _savePricing,
        style: ElevatedButton.styleFrom(
          // ✅ Bouton : noir en clair / blanc en sombre
          backgroundColor: accentColor,
          foregroundColor: accentTextColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: accentTextColor,
                  strokeWidth: 3,
                ),
              )
            : Text(
                'Continuer vers le paiement',
                style: TextStyle(
                  color: accentTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final progressBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tarification des abonnements',
              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                // ✅ Fond accent très léger
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Étape 3/3',
                style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: 0.85,
            backgroundColor: progressBg,
            // ✅ Accent au lieu de violet
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencySelector(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final containerBg = isDark ? const Color(0xFF161616) : const Color(0xFFF3F4F6);
    final containerBorder = isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB);
    final dropdownBg = isDark ? const Color(0xFF161616) : Colors.white;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: containerBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Devise :',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          ),
          DropdownButton<String>(
            value: _selectedCurrencyCode,
            dropdownColor: dropdownBg,
            underline: const SizedBox(),
            // ✅ Icône accent
            icon: Icon(Icons.arrow_drop_down, color: accentColor),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            items: _currencies.map((curr) {
              return DropdownMenuItem<String>(
                value: curr['code'],
                child: Text('${curr['name']} (${curr['symbol']})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedCurrencyCode = val;
                  _premiumPriceController.clear();
                  _proPriceController.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String title,
    required String description,
    required TextEditingController controller,
    required String minText,
    required String maxText,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;
    final cardBg = isDark ? const Color(0xFF161616) : const Color(0xFFF3F4F6);
    final cardBorder = isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB);
    final fieldBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final accentColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? const Color(0xFF555555) : Colors.black38;
    final helperColor = isDark ? const Color(0xFF666666) : Colors.black45;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: subTextColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: TextStyle(color: textColor),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Recommandé : $minText - $maxText',
              hintStyle: TextStyle(color: hintColor),
              labelText: 'Prix par mois (${_currentCurrency['symbol']})',
              // ✅ Label accent au lieu de violet
              labelStyle: TextStyle(color: accentColor),
              helperText: 'Plage autorisée : $minText à $maxText ${_currentCurrency['symbol']}',
              helperStyle: TextStyle(color: helperColor, fontSize: 11),
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                // ✅ Bordure accent au lieu de violette
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePricing() async {
    if (!_validatePrices()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Les prix doivent être entre ${_getPremiumMin()} et ${_getPremiumMax()} ${_currentCurrency['symbol']} pour Premium, et entre ${_getProMin()} et ${_getProMax()} ${_currentCurrency['symbol']} pour Pro'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final premiumPriceFCFA = _convertToFCFA(double.parse(_premiumPriceController.text));
      final proPriceFCFA = _convertToFCFA(double.parse(_proPriceController.text));

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentInfoStep(
              fullName: widget.fullName,
              birthDate: widget.birthDate,
              city: widget.city,
              category: widget.category,
              idCardUrl: widget.idCardUrl,
              phoneVerified: widget.phoneVerified,
              premiumPrice: premiumPriceFCFA.toDouble(),
              proPrice: proPriceFCFA.toDouble(),
              currency: _selectedCurrencyCode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _premiumPriceController.dispose();
    _proPriceController.dispose();
    super.dispose();
  }
}