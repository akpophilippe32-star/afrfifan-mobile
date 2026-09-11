import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
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

    return WillPopScope(
      onWillPop: () async => _isLoading,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: _buildCurrentState(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentState(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    if (_isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: accentColor, strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            'Envoi de votre demande...',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Veuillez ne pas quitter l\'application.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 14),
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
          Text(
            'Une erreur est survenue',
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _submitApplication();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: accentTextColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Réessayer',
                style: TextStyle(
                  color: accentTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ─── ÉCRAN DE SUCCÈS ───
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSuccessIcon(isDark),
        const SizedBox(height: 30),
        Text(
          'Votre demande a été envoyée\navec succès !',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Notre équipe vérifie vos informations\nsous 24 à 48h.\nVous recevrez une notification.',
          textAlign: TextAlign.center,
          style: TextStyle(color: subTextColor, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 30),
        _buildStatusCard(isDark),
        const SizedBox(height: 40),
        _buildActionButtons(context, isDark),
      ],
    );
  }

  Widget _buildSuccessIcon(bool isDark) {
    final circleBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final circleBorder = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: circleBg,
        shape: BoxShape.circle,
        border: Border.all(color: circleBorder, width: 2),
      ),
      // 🟢 Vert conservé (succès)
      child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final cardBorder = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final progressBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Icône accent au lieu de violet
              Icon(Icons.hourglass_empty, color: accentColor, size: 24),
              const SizedBox(width: 10),
              Text(
                'En cours de vérification',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              backgroundColor: progressBg,
              // ✅ Accent au lieu de violet
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              // ✅ Bouton : noir en clair / blanc en sombre
              backgroundColor: accentColor,
              foregroundColor: accentTextColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              'Retour à mon profil',
              style: TextStyle(
                color: accentTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}