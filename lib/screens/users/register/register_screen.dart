import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import '../login/login_screen.dart';
import 'age_verification_screen.dart';
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _obscure = true;
  bool _accepted = false;
  bool _isLoading = false;

  final _nameCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez accepter les conditions d\'utilisation.')),
      );
      return;
    }

    if (_nameCtrl.text.trim().isEmpty ||
        _identifierCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _identifierCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        data: {'full_name': _nameCtrl.text.trim()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inscription réussie !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // --- MODIFICATION ICI : Rediriger vers la vérification d'âge ---
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AgeVerificationScreen()),
        );
      }
    } catch (e, stackTrace) {
      // --- AFFICHAGE DE L'ERREUR DANS LE TERMINAL ---
      debugPrint('================ ERREUR SUPABASE ================');
      debugPrint(e.toString());
      debugPrint('Stacktrace: $stackTrace');
      debugPrint('================================================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              const Text(
                'Créer un compte',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Nom complet'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _identifierCtrl,
                decoration: const InputDecoration(
                  hintText: 'Email ou numéro de téléphone',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textGrey,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _accepted,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (v) => setState(() => _accepted = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            color: AppColors.textGrey, fontSize: 13, height: 1.4),
                        children: [
                          TextSpan(text: 'J\'accepte les '),
                          TextSpan(
                            text: 'Conditions d\'utilisation',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500),
                          ),
                          TextSpan(text: ' et la '),
                          TextSpan(
                            text: 'Politique de confidentialité',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isLoading ? 'Patientez...' : 'S\'inscrire',
                onPressed: _isLoading ? () {} : () => _signUp(),
              ),
              const SizedBox(height: 24),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 14),
                    children: [
                      const TextSpan(text: 'Déjà un compte ? '),
                      TextSpan(
                        text: 'Se connecter',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}