import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('Confidentialité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSwitchTile('Profil privé', 'Seuls vos abonnés peuvent voir vos publications', _isPrivateProfile, (v) => setState(() => _isPrivateProfile = v)),
          const Divider(color: Colors.grey),
          _buildSwitchTile('Statut en ligne', 'Afficher quand vous êtes connecté', _showOnlineStatus, (v) => setState(() => _showOnlineStatus = v)),
          const Divider(color: Colors.grey),
          _buildSwitchTile('Messages directs', 'Autoriser les fans à vous envoyer des messages', _allowDirectMessages, (v) => setState(() => _allowDirectMessages = v)),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      activeColor: AppColors.primary,
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      value: value,
      onChanged: onChanged,
    );
  }
}