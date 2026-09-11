import 'package:flutter/material.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ ÉCOUTE DU THÈME
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;

        final bgColor = isDark ? Colors.black : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subTextColor = isDark ? Colors.grey : Colors.black54;
        final accentColor = isDark ? Colors.white : Colors.black;
        final accentTextColor = isDark ? Colors.black : Colors.white;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            title: Text(
              'À propos',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── ICÔNE ───
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // ✅ Fond accent très léger au lieu de violet
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star, color: accentColor, size: 60),
                ),
                const SizedBox(height: 24),

                // ─── NOM APP ───
                Text(
                  'Afrifan',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // ─── VERSION ───
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: subTextColor, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // ─── DESCRIPTION ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Développé avec ❤️ pour connecter les créateurs et leurs fans.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, height: 1.5),
                  ),
                ),
                const SizedBox(height: 40),

                // ─── SUPPRIMER COMPTE (rouge conservé = action destructive) ───
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Supprimer mon compte',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}