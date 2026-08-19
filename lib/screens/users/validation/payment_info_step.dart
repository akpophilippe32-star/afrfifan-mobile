import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'confirmation_screen.dart';

class PaymentInfoStep extends StatefulWidget {
  // ✅ On reçoit toutes les données des étapes précédentes pour les transmettre à la fin
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

  final String _paymentMethod = 'mtn_momo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
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
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Où souhaitez-vous recevoir vos gains ?',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              _buildMtnCard(),
              const SizedBox(height: 30),

              _buildMobileMoneyFields(),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6), // ✅ VIOLET
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Étape 3/3',
              style: TextStyle(
                color: Color(0xFF8B5CF6), // ✅ VIOLET
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2), // ✅ VIOLET
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '3/3',
                style: TextStyle(
                  color: Color(0xFF8B5CF6), // ✅ VIOLET
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)), // ✅ VIOLET
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildMtnCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00), // Jaune MTN
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_android, color: Color(0xFFFFCC00), size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MTN Mobile Money',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Retrait rapide et sécurisé',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.black, size: 28),
        ],
      ),
    );
  }

  Widget _buildMobileMoneyFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Numéro de compte Mobile Money',
          style: TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: TextField(
            controller: _accountNumberController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Ex: 97 XX XX XX',
              hintStyle: TextStyle(color: Color(0xFF555555)),
              prefixIcon: Icon(Icons.phone, color: Color(0xFF8B5CF6)), // ✅ VIOLET
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Nom du titulaire du compte',
          style: TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: TextField(
            controller: _accountHolderController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Doit correspondre à votre pièce d\'identité',
              hintStyle: TextStyle(color: Color(0xFF555555)),
              prefixIcon: Icon(Icons.person, color: Color(0xFF8B5CF6)), // ✅ VIOLET
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _validateAndSubmit() async {
    if (_accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le numéro de compte'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_accountHolderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le nom du titulaire'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté.");

      debugPrint('📤 Préparation de l\'envoi final vers Supabase...');

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
              paymentMethod: _paymentMethod,
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
} // ✅ Accolade fermante ajoutée ici pour fermer _PaymentInfoStepState