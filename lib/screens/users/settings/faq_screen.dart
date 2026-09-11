import 'package:flutter/material.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;

        final bgColor = isDark ? Colors.black : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subTextColor = isDark ? Colors.grey : Colors.black54;
        final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
        final dividerColor = isDark ? Colors.white24 : Colors.black12;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            title: Text(
              'Aide & FAQ',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildFaqTile(
                title: 'Comment m\'abonner à un créateur ?',
                content: 'Allez sur le profil du créateur et cliquez sur le bouton "S\'abonner". Le paiement est sécurisé.',
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                dividerColor: dividerColor,
              ),
              const SizedBox(height: 12),
              _buildFaqTile(
                title: 'Comment supprimer mon compte ?',
                content: 'Rendez-vous dans Paramètres > À propos > Supprimer mon compte.',
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                dividerColor: dividerColor,
              ),
              const SizedBox(height: 12),
              _buildFaqTile(
                title: 'Mes paiements sont-ils sécurisés ?',
                content: 'Oui, toutes les transactions sont chiffrées et traitées par des prestataires agréés.',
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                dividerColor: dividerColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaqTile({
    required String title,
    required String content,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
    required Color dividerColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          title: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconColor: textColor,
          collapsedIconColor: textColor,
          backgroundColor: cardColor,
          collapsedBackgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: dividerColor),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: dividerColor),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                content,
                style: TextStyle(color: subTextColor, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}