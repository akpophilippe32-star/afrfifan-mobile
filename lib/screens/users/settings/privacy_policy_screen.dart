import 'package:flutter/material.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;

        final bgColor = isDark ? Colors.black : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subTextColor = isDark ? Colors.grey : Colors.black54;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            title: Text(
              'Politique de confidentialité',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collecte des données',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nous collectons uniquement les données nécessaires au fonctionnement de l\'application : nom, email, et données de paiement sécurisées.',
                  style: TextStyle(color: subTextColor, height: 1.5),
                ),
                const SizedBox(height: 24),

                Text(
                  'Utilisation des données',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vos données ne sont jamais vendues à des tiers. Elles servent uniquement à améliorer votre expérience et à assurer la sécurité de la plateforme.',
                  style: TextStyle(color: subTextColor, height: 1.5),
                ),
                const SizedBox(height: 24),

                Text(
                  'Vos droits',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Conformément à la loi, vous avez un droit d\'accès, de modification et de suppression de vos données personnelles à tout moment.',
                  style: TextStyle(color: subTextColor, height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}