import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // ✅ Opérateur sélectionné : 'mtn', 'moov' ou 'orange'
  String _selectedOperator = 'mtn';

  // ─── CONSTANTES DE COULEUR ────────────────────────────────
  static const Color _primaryColor = Color(0xFF8B5CF6);
  static const Color _backgroundColor = Color(0xFF0A0A0A);
  static const Color _cardColor = Color(0xFF1A1A1A);
  static const Color _borderColor = Color(0xFF2A2A2A);
  static const Color _textColor = Colors.white;
  static const Color _textSecondaryColor = Color(0xFF888888);
  static const Color _hintColor = Color(0xFF555555);

  // Couleurs des opérateurs
  static const Color _mtnColor = Color(0xFFFFCC00);
  static const Color _moovColor = Color(0xFF00B2A9);
  static const Color _orangeColor = Color(0xFFFF6600);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 30),

              const Text(
                'Informations de paiement',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Où souhaitez-vous recevoir vos gains ?',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              // ─── SÉLECTION DE L'OPÉRATEUR ──────────────────
              _buildOperatorSelector(),
              const SizedBox(height: 24),

              // ─── CARTE DE L'OPÉRATEUR SÉLECTIONNÉ ──────────
              _buildOperatorCard(),
              const SizedBox(height: 30),

              // ─── CHAMPS DE SAISIE ──────────────────────────
              _buildMobileMoneyFields(),
              const SizedBox(height: 40),

              // ─── BOUTON DE SOUMISSION ──────────────────────
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'Soumettre ma candidature',
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
      ),
    );
  }

  // ─── WIDGETS ────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Étape 3/3',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '3/3',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(
            value: 1.0,
            backgroundColor: Color(0xFF1A1A1A),
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choisissez votre opérateur',
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _operatorOption('mtn', 'MTN', _mtnColor),
              _operatorOption('moov', 'Moov', _moovColor),
              _operatorOption('orange', 'Orange', _orangeColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _operatorOption(String value, String label, Color color) {
    final isSelected = _selectedOperator == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedOperator = value),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : _backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade700,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label[0],
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade500,
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
              color: isSelected ? color : Colors.grey.shade500,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            const SizedBox(height: 4),
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
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Retrait rapide et sécurisé',
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  // ✅ CHAMPS DE SAISIE RÉELLEMENT SOMBRES
  Widget _buildMobileMoneyFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Numéro de compte',
          style: TextStyle(
            color: _textSecondaryColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: _accountNumberController,
            style: const TextStyle(color: _textColor),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Ex: 97 XX XX XX',
              hintStyle: TextStyle(color: _hintColor),
              prefixIcon: const Icon(Icons.phone, color: _primaryColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              // ✅ FORCER LE FOND SOMBRE
              filled: true,
              fillColor: _cardColor,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Nom du titulaire du compte',
          style: TextStyle(
            color: _textSecondaryColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: _accountHolderController,
            style: const TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'Doit correspondre à votre pièce d\'identité',
              hintStyle: TextStyle(color: _hintColor),
              prefixIcon: const Icon(Icons.person, color: _primaryColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              // ✅ FORCER LE FOND SOMBRE
              filled: true,
              fillColor: _cardColor,
            ),
          ),
        ),
      ],
    );
  }

  // ─── VALIDATION ET SOUMISSION ─────────────────────────────

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
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }
}