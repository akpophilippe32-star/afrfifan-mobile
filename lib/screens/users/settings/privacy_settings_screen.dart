import 'package:flutter/material.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isPrivateProfile = false;
  bool _showOnlineStatus = true;
  bool _allowDirectMessages = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;

        final bgColor = isDark ? Colors.black : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subTextColor = isDark ? Colors.grey : Colors.black54;
        final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
        final accentColor = isDark ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            title: Text(
              'Confidentialité',
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
              _buildSwitchTile(
                'Profil privé',
                'Seuls vos abonnés peuvent voir vos publications',
                _isPrivateProfile,
                (v) => setState(() => _isPrivateProfile = v),
                textColor: textColor,
                subTextColor: subTextColor,
                accentColor: accentColor,
              ),
              Divider(color: dividerColor),
              _buildSwitchTile(
                'Statut en ligne',
                'Afficher quand vous êtes connecté',
                _showOnlineStatus,
                (v) => setState(() => _showOnlineStatus = v),
                textColor: textColor,
                subTextColor: subTextColor,
                accentColor: accentColor,
              ),
              Divider(color: dividerColor),
              _buildSwitchTile(
                'Messages directs',
                'Autoriser les fans à vous envoyer des messages',
                _allowDirectMessages,
                (v) => setState(() => _allowDirectMessages = v),
                textColor: textColor,
                subTextColor: subTextColor,
                accentColor: accentColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
  }) {
    return SwitchListTile(
      // ✅ Plus de violet → noir en clair / blanc en sombre
      activeColor: accentColor,
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subTextColor),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}