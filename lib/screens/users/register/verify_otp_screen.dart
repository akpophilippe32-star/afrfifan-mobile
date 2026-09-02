import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import 'create_password_screen.dart'; // ✅ NOUVEAU IMPORT

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
if (_otpCtrl.text.trim().length != 8) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le code doit contenir exactement 8 chiffres')));
  return;
}
    setState(() => _isLoading = true);

    try {
      // ✅ VÉRIFIE LE CODE OTP
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otpCtrl.text.trim(),
        type: OtpType.signup, // ou OtpType.email
      );

      if (mounted) {
        // ✅ SUCCÈS : On va créer le mot de passe
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CreatePasswordScreen(email: widget.email)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code invalide ou expiré. Veuillez réessayer.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Vérification', style: TextStyle(color: AppColors.textDark)), backgroundColor: AppColors.white, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nous avons envoyé un code à 6 chiffres à', style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
              const SizedBox(height: 8),
              Text(widget.email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
              const SizedBox(height: 32),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 8,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '00000000',
                  border: OutlineInputBorder(),
                  counterText: '', // Cache le compteur "0/6"
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: _isLoading ? 'Vérification...' : 'Vérifier le code',
                onPressed: _isLoading ? () {} : _verifyOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}