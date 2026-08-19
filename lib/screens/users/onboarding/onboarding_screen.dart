import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import '../login/login_screen.dart';

class _OnboardData {
  final String imageAsset;
  final List<TextSpan> title;
  final String subtitle;
  final String buttonLabel;

  _OnboardData({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardData> _slides = [
    _OnboardData(
      imageAsset: 'assets/images/onboard_1.png',
      title: [
        const TextSpan(text: 'Découvrez\ndes '),
        TextSpan(text: 'créateurs', style: TextStyle(color: AppColors.primary)),
        const TextSpan(text: '\nincroyables'),
      ],
      subtitle: 'Des contenus exclusifs en photos, vidéos, audio et articles.',
      buttonLabel: 'Suivant',
    ),
    _OnboardData(
      imageAsset: 'assets/images/onboard_2.png',
      title: [
        const TextSpan(text: 'Abonnez-vous\nà vos '),
        TextSpan(text: 'favoris', style: TextStyle(color: AppColors.primary)),
      ],
      subtitle: 'Accédez à des contenus exclusifs et soutenez leurs talents.',
      buttonLabel: 'Suivant',
    ),
    _OnboardData(
      imageAsset: 'assets/images/onboard_3.png',
      title: [
        const TextSpan(text: 'Soutenez,\n'),
        TextSpan(
            text: 'Échangez, Grandissez',
            style: TextStyle(color: AppColors.primary)),
      ],
      subtitle: 'Une communauté africaine unie autour de la passion.',
      buttonLabel: 'Commencer',
    ),
  ];

  void _next() {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _OnboardSlide(data: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(
                label: _slides[_index].buttonLabel,
                onPressed: _next,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardSlide extends StatelessWidget {
  final _OnboardData data;
  const _OnboardSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                height: 1.25,
              ),
              children: data.title,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: AppColors.inputFill,
                width: double.infinity,
                child: Image.asset(
                  data.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_outlined,
                        size: 60, color: AppColors.textGrey),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
