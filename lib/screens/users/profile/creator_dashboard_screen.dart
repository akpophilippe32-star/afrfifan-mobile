import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'overview_tab.dart';
import 'wallet_tab.dart';
import 'subscribers_tab.dart';
import 'stats_tab.dart';
import 'settings_tab.dart';
import 'tips_tab.dart';
import 'go_live_screen.dart';
import 'creator_shop_tab.dart';
import 'sales_tab.dart';

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
    Navigator.pop(context);
  }

  void _goLive() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GoLiveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: _buildDrawer(isDark),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: textColor, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
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
          CreatorShopTab(),
          SalesTab(),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    final drawerBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final headerBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final selectedTextColor = isDark ? Colors.white : Colors.black;
    final unselectedTextColor = isDark ? Colors.white : Colors.black87;
    final unselectedIconColor = isDark ? Colors.grey : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.white24 : Colors.black12;

    return Drawer(
      backgroundColor: drawerBg,
      child: Column(
        children: [
          // ─── EN-TÊTE ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: BoxDecoration(
              // ✅ Plus de fond violet → gris clair/foncé adaptatif
              color: headerBg,
              borderRadius: const BorderRadius.only(bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  // ✅ Avatar neutre
                  backgroundColor: accentColor,
                  child: Icon(Icons.person, color: accentTextColor, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  _userName,
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Espace Créateur',
                  style: TextStyle(color: subTextColor, fontSize: 14),
                ),
              ],
            ),
          ),

          // ─── MENU ───
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildDrawerItem(
                  index: 0, icon: Icons.dashboard_outlined, title: 'Vue d\'ensemble',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),
                _buildDrawerItem(
                  index: 1, icon: Icons.account_balance_wallet_outlined, title: 'Portefeuille',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),
                _buildDrawerItem(
                  index: 2, icon: Icons.people_outline, title: 'Abonnés',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),
                _buildDrawerItem(
                  index: 3, icon: Icons.bar_chart_outlined, title: 'Statistiques',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),
                _buildDrawerItem(
                  index: 4, icon: Icons.settings_outlined, title: 'Paramètres',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),
                _buildDrawerItem(
                  index: 5, icon: Icons.local_cafe, title: 'Pourboires',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),
                _buildDrawerItem(
                  index: 6, icon: Icons.storefront_outlined, title: 'Ma Boutique',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),
                _buildDrawerItem(
                  index: 7, icon: Icons.trending_up, title: 'Mes Ventes',
                  isDark: isDark, selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor, unselectedIconColor: unselectedIconColor,
                  accentColor: accentColor,
                ),

                Divider(height: 32, color: dividerColor, indent: 20, endIndent: 20),

                // ─── LANCER UN LIVE (rouge conservé) ───
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

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required String title,
    required bool isDark,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required Color unselectedIconColor,
    required Color accentColor,
  }) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        // ✅ Sélectionné : noir en clair / blanc en sombre
        color: isSelected ? accentColor : unselectedIconColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? selectedTextColor : unselectedTextColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.chevron_right, color: accentColor)
          : null,
      onTap: () => _onItemTapped(index),
    );
  }

  String _getAppBarTitle() {
    const titles = [
      'Vue d\'ensemble',
      'Portefeuille',
      'Abonnés',
      'Statistiques',
      'Paramètres',
      'Pourboires',
      'Ma Boutique',
      'Mes Ventes',
    ];
    return titles[_selectedIndex];
  }
}