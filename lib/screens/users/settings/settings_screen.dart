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
import '../../../theme/theme_notifier.dart'; // ✅ IMPORT DU NOTIFIER GLOBAL
import '../login/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? username;

  const SettingsScreen({super.key, this.username});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  bool _isFrench = true;

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
    // ✅ ÉCOUTE le thème → rebuild auto quand il change
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        final String firstName = widget.username?.split(' ').first ?? 'l\'artiste';

        final bgColor = isDark ? Colors.black : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subTextColor = isDark ? Colors.grey : Colors.black54;
        final groupColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
        final groupBorder = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Paramètres',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
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
                      // 🟪 BANNIÈRE
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
                                    style: TextStyle(color: Colors.white70, fontSize: 14),
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

                      // 👤 PARAMÈTRES DU COMPTE
                      _buildSectionTitle('Paramètres du compte', textColor),
                      const SizedBox(height: 10),
                      _buildSettingsGroup(
                        groupColor: groupColor,
                        borderColor: groupBorder,
                        tiles: [
                          _buildSettingsTile(
                            Icons.person_outline,
                            'Informations personnelles',
                            textColor: textColor,
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
                            textColor: textColor,
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
                            textColor: textColor,
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
                            textColor: textColor,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Section Notifications bientôt disponible !')),
                              );
                            },
                          ),

                          // ✅ TOGGLE MODE SOMBRE/CLAIR
                          SwitchListTile(
                            secondary: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              isDark ? 'Mode sombre' : 'Mode clair',
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              isDark ? 'Apparence sombre activée' : 'Apparence claire activée',
                              style: TextStyle(color: subTextColor, fontSize: 12),
                            ),
                            value: isDark,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              // ✅ Bascule le thème global
                              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(value ? '🌙 Mode sombre activé' : '☀️ Mode clair activé'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),

                          // TOGGLE LANGUE
                          SwitchListTile(
                            secondary: const Icon(Icons.language, color: AppColors.primary),
                            title: Text(
                              _isFrench ? 'Langue : Français' : 'Language: English',
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              'Change language / Changer de langue',
                              style: TextStyle(color: subTextColor, fontSize: 12),
                            ),
                            value: _isFrench,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setState(() => _isFrench = value);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_isFrench ? 'Langue changée en Français' : 'Language switched to English')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ℹ️ ASSISTANCE
                      _buildSectionTitle('Assistance & Informations', textColor),
                      const SizedBox(height: 10),
                      _buildSettingsGroup(
                        groupColor: groupColor,
                        borderColor: groupBorder,
                        tiles: [
                          _buildSettingsTile(
                            Icons.help_outline_outlined,
                            'Aide / FAQ',
                            textColor: textColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FaqScreen()),
                            ),
                          ),
                          _buildSettingsTile(
                            Icons.description_outlined,
                            'Conditions Générales d\'Utilisation',
                            textColor: textColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
                            ),
                          ),
                          _buildSettingsTile(
                            Icons.privacy_tip_outlined,
                            'Politique de confidentialité',
                            textColor: textColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                            ),
                          ),
                          _buildSettingsTile(
                            Icons.info_outline,
                            'À propos de l\'application',
                            textColor: textColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AboutAppScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 🛑 SE DÉCONNECTER
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _logout,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: groupColor,
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
      },
    );
  }
  

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
    );
  }

  Widget _buildSettingsGroup({
    required List<Widget> tiles,
    required Color groupColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: groupColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: tiles),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title, {
    VoidCallback? onTap,
    required Color textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Option "$title" bientôt disponible !')),
        );
      },
    );
  }
}