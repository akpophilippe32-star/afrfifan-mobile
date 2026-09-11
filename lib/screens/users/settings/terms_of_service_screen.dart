import 'package:flutter/material.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
              'Conditions Générales',
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
                  '1. Acceptation des conditions',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'En utilisant l\'application Afrifan, vous acceptez pleinement les présentes conditions générales d\'utilisation.',
                  style: TextStyle(color: subTextColor, height: 1.5),
                ),
                const SizedBox(height: 24),

                Text(
                  '2. Contenu des utilisateurs',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les créateurs sont seuls responsables du contenu qu\'ils publient. Tout contenu illégal ou offensant entraînera la suppression immédiate du compte.',
                  style: TextStyle(color: subTextColor, height: 1.5),
                ),
                const SizedBox(height: 24),

                Text(
                  '3. Abonnements et remboursements',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les abonnements sont facturés mensuellement. Les remboursements ne sont pas garantis sauf en cas de dysfonctionnement technique avéré de notre part.',
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