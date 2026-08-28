import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('À propos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.star, color: AppColors.primary, size: 60)),
            const SizedBox(height: 24),
            const Text('Afrifan', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 40),
            const Text('Développé avec ❤️ pour connecter les créateurs et leurs fans.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
            const SizedBox(height: 40),
            TextButton(onPressed: () {}, child: const Text('Supprimer mon compte', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}