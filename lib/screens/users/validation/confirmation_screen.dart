import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ✅ AJOUTE CET IMPORT (ajuste le chemin '../' si ton dossier profile_screen.dart est ailleurs)
import '../main/main_screen.dart';

class ConfirmationScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final String? birthDate;
  final String city;
  final String category;
  final String? idCardUrl;
  final bool phoneVerified;
  final double premiumPrice;
  final double proPrice;
  final String currency;
  final String paymentMethod;
  final String paymentAccountNumber;
  final String paymentHolderName;

  const ConfirmationScreen({
    Key? key,
    required this.userId,
    required this.fullName,
    required this.birthDate,
    required this.city,
    required this.category,
    required this.idCardUrl,
    required this.phoneVerified,
    required this.premiumPrice,
    required this.proPrice,
    required this.currency,
    required this.paymentMethod,
    required this.paymentAccountNumber,
    required this.paymentHolderName,
  }) : super(key: key);

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _submitApplication();
  }

  Future<void> _submitApplication() async {
    try {
      debugPrint('📤 Envoi final de la demande créateur à Supabase...');

      await Supabase.instance.client.from('creator_applications').insert({
        'user_id': widget.userId,
        'full_name': widget.fullName,
        'birth_date': widget.birthDate,
        'city': widget.city,
        'category': widget.category,
        'id_card_url': widget.idCardUrl,
        'phone_verified': widget.phoneVerified,
        'premium_price': widget.premiumPrice,
        'pro_price': widget.proPrice,
        'currency': widget.currency,
        'payment_method': widget.paymentMethod,
        'payment_account_number': widget.paymentAccountNumber,
        'payment_holder_name': widget.paymentHolderName,
        'status': 'pending',
      });

      debugPrint('✅ Demande créateur enregistrée avec succès !');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR LORS DE L\'INSERTION SUPABASE: $e');
      debugPrint('StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CORRECTION : On bloque le retour SEULEMENT pendant le chargement
    return WillPopScope(
      onWillPop: () async => _isLoading, 
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: _buildCurrentState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    if (_isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 3),
          const SizedBox(height: 24),
          const Text(
            'Envoi de votre demande...',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Veuillez ne pas quitter l\'application.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      );
    }

    if (!_isSuccess && _errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Une erreur est survenue',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _submitApplication,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    // ✅ ÉCRAN DE SUCCÈS
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSuccessIcon(),
        const SizedBox(height: 30),
        const Text(
          'Votre demande a été envoyée\navec succès !',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Notre équipe vérifie vos informations\nsous 24 à 48h.\nVous recevrez une notification.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF888888), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 30),
        _buildStatusCard(),
        const SizedBox(height: 40),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
      ),
      child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, color: Color(0xFF8B5CF6), size: 24),
              const SizedBox(width: 10),
              const Text(
                'En cours de vérification',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              backgroundColor: Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MODIFICATION ICI : Bouton unique qui ramène au profil
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () {
              // ✅ Vide la pile de navigation et affiche directement le Profil
            Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (context) => const MainScreen()), // ✅ Retourne à l'écran principal
  (route) => false,
);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              'Retour à mon profil',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // ✅ Le bouton "Voir l'historique" a été complètement supprimé ici
      ],
    );
  }
}