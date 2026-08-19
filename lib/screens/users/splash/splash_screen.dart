import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(painter: _AfricaLogoPainter()),
            ),
            const SizedBox(height: 24),
            const Text(
              'Afrifan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Soutenez vos créateurs.\nVivez l\'Afrique.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const Spacer(flex: 4),
            Container(
              width: 60,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AfricaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.accentOrange,
        AppColors.primary,
        AppColors.accentPink,
      ],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);

    final path = Path();
    path.moveTo(size.width * 0.45, 0);
    path.cubicTo(size.width * 0.75, size.height * 0.05, size.width * 0.85,
        size.height * 0.25, size.width * 0.7, size.height * 0.4);
    path.cubicTo(size.width * 0.9, size.height * 0.5, size.width * 0.85,
        size.height * 0.7, size.width * 0.65, size.height * 0.75);
    path.cubicTo(size.width * 0.6, size.height * 0.9, size.width * 0.5,
        size.height, size.width * 0.4, size.height * 0.95);
    path.cubicTo(size.width * 0.3, size.height * 0.8, size.width * 0.35,
        size.height * 0.6, size.width * 0.2, size.height * 0.5);
    path.cubicTo(size.width * 0.05, size.height * 0.4, size.width * 0.15,
        size.height * 0.15, size.width * 0.45, 0);
    path.close();

    canvas.drawPath(path, paint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.accentOrange.withOpacity(0.5);
    canvas.drawArc(rect.deflate(6), -0.6, 2.2, false, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
