import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Importations de tes écrans respectifs (ajuste les chemins si nécessaire)
import 'change_password_screen.dart'; 
import 'personal_info_screen.dart';
class SettingsScreen extends StatefulWidget {
  final String? username; // Pour afficher le nom dynamiquement dans la bannière

  const SettingsScreen({super.key, this.username});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;

  // 🚪 Fonction de déconnexion de Supabase
  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // Redirige vers ton écran de connexion
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la déconnexion : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extraction du premier mot du pseudo pour dire "Bonjour, [Prénom]"
    final String firstName = widget.username?.split(' ').first ?? 'l\'artiste';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fond légèrement grisé du modèle
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Paramètres',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: _isLoggingOut
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
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
                        colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)], // Dégradé violet foncé/indigo
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
                                'Gerez votre compte et vos preferences',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Illustration/Icône stylisée sur la droite
                        const Opacity(
                          opacity: 0.6,
                          child: Icon(Icons.blur_on, size: 70, color: Colors.white54),
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
  _buildSettingsTile(Icons.gpp_good_outlined, 'Confidentialité'),
  _buildSettingsTile(Icons.notifications_none_outlined, 'Notifications'),
  _buildSettingsTile(Icons.translate_outlined, 'Langue'),
  _buildSettingsTile(Icons.credit_card_outlined, 'Moyens de paiement'),
]),
                  const SizedBox(height: 28),

                  // ℹ️ --- SECTION : ASSISTANCE & INFORMATIONS ---
                  _buildSectionTitle('Assistance & Informations'),
                  const SizedBox(height: 10),
                  _buildSettingsGroup([
                    _buildSettingsTile(Icons.help_outline_outlined, 'Aide / FAQ'),
                    _buildSettingsTile(Icons.description_outlined, 'Conditions Générales d\'Utilisation'),
                    _buildSettingsTile(Icons.privacy_tip_outlined, 'Politique de confidentialité'),
                    _buildSettingsTile(Icons.info_outline, 'À propos de l\'application'),
                  ]),
                  const SizedBox(height: 32),

                  // 🛑 --- BOUTON SE DÉCONNECTER ---
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _logout,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: const Text(
                        'Se déconnecter',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // Widget d'en-tête de section
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // Widget conteneur blanc regroupant les options
  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: tiles,
      ),
    );
  }

  // Widget pour chaque ligne de paramètre avec action onTap optionnelle
  Widget _buildSettingsTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87, // Correction de la couleur à la ligne 199 💜
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black38, size: 20),
      onTap: onTap ?? () {
        // Optionnel : feedback visuel si aucune route n'est configurée
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Option "$title" bientôt disponible !')),
        );
      },
    );
  }
}