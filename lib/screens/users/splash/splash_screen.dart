import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../main/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _navigateToHome();
      } else {
        _navigateToOnboarding();
      }
    });

    final currentSession = supabase.auth.currentSession;
    if (currentSession != null) {
      _navigateToHome();
    } else {
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final refreshedSession = supabase.auth.currentSession;
      if (refreshedSession != null) {
        _navigateToHome();
      } else {
        _navigateToOnboarding();
      }
    }

    authSubscription.cancel();
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  void _navigateToOnboarding() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // ✅ VRAI LOGO AFRIQUE (Image locale noire sur fond blanc)
            Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                color: Colors.white, // Le fond reste blanc pour faire ressortir le logo noir
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Image.asset(
                  'assets/images/africa_logo.png',
                  fit: BoxFit.contain,
                  // ✅ J'ai retiré "color: Colors.white" pour que ton image reste noire
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Afrifan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            
            const SizedBox(height: 12),
            
            const Text(
              'Soutenez vos créateurs.\nVivez l\'Afrique.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            
            const Spacer(flex: 3),
            
            Container(
              width: 60,
              height: 4,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}