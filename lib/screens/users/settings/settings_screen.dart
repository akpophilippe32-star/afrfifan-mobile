import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'change_password_screen.dart'; 
import 'personal_info_screen.dart';
import 'privacy_settings_screen.dart';
import 'faq_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_app_screen.dart';
import '../../../theme/app_colors.dart';
import '../login/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? username;

  const SettingsScreen({super.key, this.username});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  bool _isDarkMode = true; // ✅ Mode sombre activé par défaut
  bool _isFrench = true; // ✅ Français par défaut

    Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // ✅ NAVIGATION DIRECTE VERS L'ÉCRAN DE LOGIN (sans route nommée)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()), // ⚠️ Remplace LoginScreen par ton vrai écran de connexion
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la déconnexion : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = widget.username?.split(' ').first ?? 'l\'artiste';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Paramètres',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: _isLoggingOut
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🟪 --- BANNIÈRE DÉGRADÉE VIOLETTE ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bonjour, $firstName 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Gérez votre compte et vos préférences',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Opacity(
                          opacity: 0.6,
                          child: Icon(Icons.settings_suggest, size: 60, color: Colors.white54),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 👤 --- SECTION : PARAMÈTRES DU COMPTE ---
                  _buildSectionTitle('Paramètres du compte'),
                  const SizedBox(height: 10),
                  _buildSettingsGroup([
                    _buildSettingsTile(
                      Icons.person_outline, 
                      'Informations personnelles',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.lock_open_outlined, 
                      'Sécurité',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.gpp_good_outlined, 
                      'Confidentialité',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PrivacySettingsScreen()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.notifications_none_outlined, 
                      'Notifications',
                      onTap: () {
                        // TODO: Rediriger vers notifications_screen.dart si existant
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Section Notifications bientôt disponible !')),
                        );
                      },
                    ),
                    // ✅ TOGGLE MODE SOMBRE/CLAIR
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                      title: const Text('Mode sombre', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Apparence de l\'application', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      value: _isDarkMode,
                      activeColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() => _isDarkMode = value);
                        // TODO: Implémenter le changement de thème global
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_isDarkMode ? 'Mode sombre activé' : 'Mode clair activé')),
                        );
                      },
                    ),
                    // ✅ TOGGLE LANGUE FRANÇAIS/ANGLAIS
                    SwitchListTile(
                      secondary: const Icon(Icons.language, color: AppColors.primary),
                      title: Text(_isFrench ? 'Langue : Français' : 'Language: English', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Change language / Changer de langue', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      value: _isFrench,
                      activeColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() => _isFrench = value);
                        // TODO: Implémenter la traduction de l'appli
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_isFrench ? 'Langue changée en Français' : 'Language switched to English')),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // ℹ️ --- SECTION : ASSISTANCE & INFORMATIONS ---
                  _buildSectionTitle('Assistance & Informations'),
                  const SizedBox(height: 10),
                  _buildSettingsGroup([
                    _buildSettingsTile(
                      Icons.help_outline_outlined, 
                      'Aide / FAQ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FaqScreen()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.description_outlined, 
                      'Conditions Générales d\'Utilisation',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.privacy_tip_outlined, 
                      'Politique de confidentialité',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      Icons.info_outline, 
                      'À propos de l\'application',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AboutAppScreen()),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // 🛑 --- BOUTON SE DÉCONNECTER ---
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _logout,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Se déconnecter',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: tiles,
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Option "$title" bientôt disponible !'), backgroundColor: const Color(0xFF1A1A1A)),
        );
      },
    );
  }
}