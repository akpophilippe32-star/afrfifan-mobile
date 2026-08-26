import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'overview_tab.dart';
import 'wallet_tab.dart';
import 'subscribers_tab.dart';
import 'stats_tab.dart';
import 'settings_tab.dart';
import 'tips_tab.dart';
import 'go_live_screen.dart'; // ✅ AJOUTÉ : Import de l'écran pour lancer le Live

class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({super.key});

  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  final supabase = Supabase.instance.client;
  
  int _selectedIndex = 0;
  String _userName = "Créateur";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, username')
          .eq('id', userId)
          .maybeSingle();
          
      if (profile != null && mounted) {
        setState(() {
          _userName = profile['full_name'] ?? profile['username'] ?? "Créateur";
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement nom: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context); // Ferme le drawer après le clic
  }

  // ✅ NOUVEAU : Méthode pour ouvrir l'écran du Live
  void _goLive() {
    Navigator.pop(context); // Ferme le menu
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GoLiveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          OverviewTab(),
          WalletTab(),
          SubscribersTab(),
          StatsTab(),
          SettingsTab(),
          TipsTab(),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS UTILITAIRES (Drawer)
  // ==========================================
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF8B5CF6),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30, 
                  backgroundColor: Colors.white, 
                  child: Icon(Icons.person, color: Color(0xFF8B5CF6), size: 30)
                ),
                const SizedBox(height: 12),
                Text(
                  _userName, 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const Text(
                  'Espace Créateur', 
                  style: TextStyle(color: Colors.white70, fontSize: 14)
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildDrawerItem(0, Icons.dashboard_outlined, 'Vue d\'ensemble'),
                _buildDrawerItem(1, Icons.account_balance_wallet_outlined, 'Portefeuille'),
                _buildDrawerItem(2, Icons.people_outline, 'Abonnés'),
                _buildDrawerItem(3, Icons.bar_chart_outlined, 'Statistiques'),
                _buildDrawerItem(4, Icons.settings_outlined, 'Paramètres'),
                _buildDrawerItem(5, Icons.local_cafe, 'Pourboires'),
                
                // ✅ SÉPARATEUR POUR METTRE EN VALEUR L'ACTION LIVE
                const Divider(height: 32, color: Colors.white24, indent: 20, endIndent: 20),
                
                // ✅ BOUTON "LANCER UN LIVE" (Style spécial pour attirer l'œil)
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.redAccent, size: 28),
                  title: const Text(
                    '🔴 Lancer un Live',
                    style: TextStyle(
                      color: Colors.redAccent, 
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.redAccent, size: 16),
                  onTap: _goLive,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.chevron_right, color: Color(0xFF8B5CF6)) : null,
      onTap: () => _onItemTapped(index),
    );
  }

  String _getAppBarTitle() {
    const titles = ['Vue d\'ensemble', 'Portefeuille', 'Abonnés', 'Statistiques', 'Paramètres', 'Pourboires'];
    return titles[_selectedIndex];
  }
}