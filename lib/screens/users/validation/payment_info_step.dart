import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'confirmation_screen.dart';

class PaymentInfoStep extends StatefulWidget {
  final String fullName;
  final String? birthDate;
  final String city;
  final String category;
  final String? idCardUrl;
  final bool phoneVerified;
  final double premiumPrice;
  final double proPrice;
  final String currency;

  const PaymentInfoStep({
    Key? key,
    required this.fullName,
    required this.birthDate,
    required this.city,
    required this.category,
    required this.idCardUrl,
    required this.phoneVerified,
    required this.premiumPrice,
    required this.proPrice,
    required this.currency,
  }) : super(key: key);

  @override
  State<PaymentInfoStep> createState() => _PaymentInfoStepState();
}

class _PaymentInfoStepState extends State<PaymentInfoStep> {
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  bool _isLoading = false;

  String _selectedOperator = 'mtn';

  // ✅ Couleurs des opérateurs conservées (identité de marque)
  static const Color _mtnColor = Color(0xFFFFCC00);
  static const Color _moovColor = Color(0xFF00B2A9);
  static const Color _orangeColor = Color(0xFFFF6600);

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
              const SizedBox(height: 30),
              _buildTitle(isDark),
              const SizedBox(height: 30),
              _buildOperatorSelector(isDark),
              const SizedBox(height: 24),
              _buildOperatorCard(),
              const SizedBox(height: 30),
              _buildMobileMoneyFields(isDark),
              const SizedBox(height: 40),
              _buildSubmitButton(isDark),
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
          'Informations de paiement',
          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Où souhaitez-vous recevoir vos gains ?',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _validateAndSubmit,
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
                child: CircularProgressIndicator(color: accentTextColor, strokeWidth: 3),
              )
            : Text(
                'Soumettre ma candidature',
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
    final accentColor = isDark ? Colors.white : Colors.black;
    final progressBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Étape 3/3',
              style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '3/3',
                style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: 1.0,
            backgroundColor: progressBg,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorSelector(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

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
          Text(
            'Choisissez votre opérateur',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _operatorOption('mtn', 'MTN', _mtnColor, isDark),
              _operatorOption('moov', 'Moov', _moovColor, isDark),
              _operatorOption('orange', 'Orange', _orangeColor, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _operatorOption(String value, String label, Color color, bool isDark) {
    final isSelected = _selectedOperator == value;
    // ✅ Fond interne : noir en clair / gris foncé en sombre (ou blanc en clair selon design)
    final innerBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final unselectedBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final unselectedText = isDark ? Colors.grey.shade500 : Colors.grey.shade600;

    return GestureDetector(
      onTap: () => setState(() => _selectedOperator = value),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : innerBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : unselectedBorder,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label[0],
                style: TextStyle(
                  color: isSelected ? color : unselectedText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? color : unselectedText,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorCard() {
    Color bgColor;
    Color textColor;
    String operatorName;
    IconData icon;

    switch (_selectedOperator) {
      case 'mtn':
        bgColor = _mtnColor;
        textColor = Colors.black;
        operatorName = 'MTN Mobile Money';
        icon = Icons.phone_android;
        break;
      case 'moov':
        bgColor = _moovColor;
        textColor = Colors.white;
        operatorName = 'Moov Money';
        icon = Icons.phone_iphone;
        break;
      case 'orange':
        bgColor = _orangeColor;
        textColor = Colors.white;
        operatorName = 'Orange Money';
        icon = Icons.phone;
        break;
      default:
        bgColor = _mtnColor;
        textColor = Colors.black;
        operatorName = 'MTN Mobile Money';
        icon = Icons.phone_android;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ✅ Couleur de l'opérateur conservée
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operatorName,
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Retrait rapide et sécurisé',
                  style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),
          // ✅ Icône check adaptée au contraste de la carte opérateur
          Icon(Icons.check_circle, color: textColor, size: 28),
        ],
      ),
    );
  }

  Widget _buildMobileMoneyFields(bool isDark) {
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? const Color(0xFF555555) : Colors.black38;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Numéro de compte',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _accountNumberController,
            style: TextStyle(color: textColor),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Ex: 97 XX XX XX',
              hintStyle: TextStyle(color: hintColor),
              // ✅ Icône accent au lieu de violette
              prefixIcon: Icon(Icons.phone, color: accentColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: cardColor,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Nom du titulaire du compte',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _accountHolderController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Doit correspondre à votre pièce d\'identité',
              hintStyle: TextStyle(color: hintColor),
              // ✅ Icône accent au lieu de violette
              prefixIcon: Icon(Icons.person, color: accentColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: cardColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _validateAndSubmit() async {
    if (_accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer le numéro de compte'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountHolderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer le nom du titulaire'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté.");

      debugPrint('📤 Envoi final vers Supabase...');

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationScreen(
              userId: user.id,
              fullName: widget.fullName,
              birthDate: widget.birthDate,
              city: widget.city,
              category: widget.category,
              idCardUrl: widget.idCardUrl,
              phoneVerified: widget.phoneVerified,
              premiumPrice: widget.premiumPrice,
              proPrice: widget.proPrice,
              currency: widget.currency,
              paymentMethod: _selectedOperator,
              paymentAccountNumber: _accountNumberController.text.trim(),
              paymentHolderName: _accountHolderController.text.trim(),
            ),
          ),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }
}