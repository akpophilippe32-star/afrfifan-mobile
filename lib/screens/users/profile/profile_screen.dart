import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ IMPORTS DES ÉCRANS
import 'my_subscriptions_screen.dart';
import 'my_followers_screen.dart';
import 'my_following_screen.dart';
import 'user_posts_feed_screen.dart';
import 'my_purchases_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/personal_info_screen.dart';
import 'creator_dashboard_screen.dart';
import 'create_story_screen.dart';
import 'view_story_screen.dart';
import '../validation/personal_info_step.dart';
import '../downloads/downloads_screen.dart';
import '../../../theme/theme_notifier.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _userPosts = [];
  List<Map<String, dynamic>> _userStories = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  int _selectedTab = 0;
  int _totalPosts = 0;
  int _totalLikes = 0;
  bool _hasLoadedOnce = false;
  String _applicationStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (_hasLoadedOnce) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Utilisateur non connecté.";
      });
      return;
    }

    try {
      const connectionTimeout = Duration(seconds: 15);

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle()
          .timeout(connectionTimeout);

      _profile = profileData ??
          {
            'username': 'utilisateur',
            'full_name': 'Nouvel Utilisateur',
            'avatar_url': 'https://via.placeholder.com/150',
            'role': 'user',
            'is_verified': false,
          };

      if (_profile?['role'] == 'creator' && _profile?['is_verified'] == true) {
        _applicationStatus = 'accepted';
      } else {
        final appData = await Supabase.instance.client
            .from('creator_applications')
            .select('status')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        _applicationStatus = appData != null ? appData['status'] : 'none';
      }

      final postsData = await Supabase.instance.client
          .from('posts')
          .select(
              'id, media_url, title, content, caption, background_color, created_at, likes_count, media_type, views_count')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(connectionTimeout);

      final List<dynamic> posts = postsData ?? [];
      int likes = 0;
      for (var post in posts) {
        likes += (post['likes_count'] ?? 0) as int;
      }

      final storiesData = await Supabase.instance.client
          .from('stories')
          .select('id, media_url, media_type, text_content, background_color, created_at')
          .eq('creator_id', userId)
          .order('created_at', ascending: false)
          .timeout(connectionTimeout);

      if (mounted) {
        setState(() {
          _userPosts = posts;
          _totalPosts = _userPosts.length;
          _totalLikes = likes;
          _userStories = List<Map<String, dynamic>>.from(storiesData ?? []);
          _hasLoadedOnce = true;
        });
      }
    } catch (error) {
      debugPrint("🚨 ERREUR CHARGEMENT PROFIL : $error");
      if (mounted) setState(() => _errorMessage = "Erreur de chargement.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  MENU
  // ═══════════════════════════════════════════════════════════════
  void _showHamburgerMenu(bool isDark) {
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final dividerColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    // ✅ Icône neutre (gris) au lieu de violet
    final iconBg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final iconColor = isDark ? Colors.white70 : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    controller: scrollController,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuItem(
                        icon: Icons.group,
                        label: 'Abonnés',
                        subtitle: 'Voir qui te suit',
                        textColor: textColor,
                        subTextColor: subTextColor,
                        iconBg: iconBg,
                        iconColor: iconColor,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFollowersScreen()));
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.people,
                        label: 'Suivis',
                        subtitle: 'Voir qui tu suis',
                        textColor: textColor,
                        subTextColor: subTextColor,
                        iconBg: iconBg,
                        iconColor: iconColor,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFollowingScreen()));
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.star,
                        label: 'Abonnements',
                        subtitle: 'Tes abonnements payants',
                        textColor: textColor,
                        subTextColor: subTextColor,
                        iconBg: iconBg,
                        iconColor: iconColor,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MySubscriptionsScreen()));
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.shopping_bag,
                        label: 'Mes achats',
                        subtitle: 'Tes produits et contenus achetés',
                        textColor: textColor,
                        subTextColor: subTextColor,
                        iconBg: iconBg,
                        iconColor: iconColor,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPurchasesScreen()));
                        },
                      ),
                      Divider(color: dividerColor, height: 1),
                      _buildMenuItem(
                        icon: Icons.download_for_offline,
                        label: 'Téléchargé',
                        subtitle: 'Tes vidéos et images hors ligne',
                        textColor: textColor,
                        subTextColor: subTextColor,
                        iconBg: iconBg,
                        iconColor: iconColor,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.settings,
                        label: 'Paramètres',
                        subtitle: 'Configuration du compte',
                        textColor: textColor,
                        subTextColor: subTextColor,
                        iconBg: iconBg,
                        iconColor: iconColor,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(username: _profile?['full_name']),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color subTextColor,
    required Color iconBg,
    required Color iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 13)),
      trailing: Icon(Icons.chevron_right, color: subTextColor, size: 24),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  AVATAR
  // ═══════════════════════════════════════════════════════════════
  void _showAvatarOptions(bool isDark) {
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.zoom_in, color: textColor),
              title: Text('Voir en grand', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _viewAvatarFullScreen();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: textColor),
              title: Text('Modifier la photo', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _updateAvatar();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _viewAvatarFullScreen() {
    final avatarUrl = _profile?['avatar_url'];
    if (avatarUrl == null || avatarUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(avatarUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateAvatar() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 500);
    if (image == null) return;
    setState(() => _isUploading = true);
    try {
      final file = File(image.path);
      final String fileName = '$userId/avatar.jpg';
      final oldAvatarUrl = _profile?['avatar_url'];
      if (oldAvatarUrl != null && oldAvatarUrl.contains(fileName)) {
        try {
          await Supabase.instance.client.storage.from('avatars').remove([fileName]);
        } catch (_) {}
      }
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(fileName, file, fileOptions: const FileOptions(upsert: true));
      final String publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      await Supabase.instance.client.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
      if (mounted) {
        setState(() => _profile?['avatar_url'] = publicUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo mise à jour !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("🚨 ERREUR UPLOAD AVATAR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec de la mise à jour."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD AVEC ÉCOUTE DU THÈME
  // ═══════════════════════════════════════════════════════════════
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
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: textColor)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: textColor, size: 60),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: TextStyle(color: textColor)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _hasLoadedOnce = false;
                  _loadProfileData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColor,
                  foregroundColor: bgColor,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final bool isCreator = _profile?['is_verified'] == true && _profile?['role'] == 'creator';

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: () async {
          _hasLoadedOnce = false;
          await _loadProfileData();
        },
        color: textColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.menu, color: textColor, size: 28),
                          tooltip: 'Menu',
                          onPressed: () => _showHamburgerMenu(isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _showAvatarOptions(isDark),
                      child: Stack(
                        children: [
                          // ✅ Plus de gradient violet/rose
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardColor,
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: CircleAvatar(
                              backgroundColor: bgColor,
                              backgroundImage: _profile?['avatar_url'] != null
                                  ? NetworkImage(_profile!['avatar_url'])
                                  : null,
                              child: _profile?['avatar_url'] == null
                                  ? Icon(Icons.person, size: 60, color: textColor)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(color: bgColor, width: 3),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: isDark ? Colors.black : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _profile?['full_name']?.toUpperCase() ?? 'UTILISATEUR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: textColor,
                            letterSpacing: 1,
                          ),
                        ),
                        if (isCreator) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.verified, color: textColor, size: 24),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${_profile?['username'] ?? 'username'}',
                      style: TextStyle(color: subTextColor, fontSize: 15),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_applicationStatus == 'accepted') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreatorDashboardScreen()),
                                );
                              } else if (_applicationStatus == 'pending') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Votre demande est en cours de vérification. Veuillez patienter.'),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PersonalInfoStep()),
                                );
                              }
                            },
                            icon: Icon(
                              _applicationStatus == 'accepted'
                                  ? Icons.dashboard
                                  : (_applicationStatus == 'pending'
                                      ? Icons.hourglass_top
                                      : Icons.monetization_on),
                              size: 20,
                            ),
                            label: Text(
                              _applicationStatus == 'accepted'
                                  ? 'Tableau de bord'
                                  : (_applicationStatus == 'pending'
                                      ? 'En cours...'
                                      : 'Activer le compte'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              // ✅ Bouton adaptatif noir/blanc
                              backgroundColor: _applicationStatus == 'pending'
                                  ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400)
                                  : (isDark ? Colors.white : Colors.black),
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
                            ),
                            icon: const Icon(Icons.edit, size: 20),
                            label: const Text('Modifier',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: borderColor, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    _buildStatCard(_formatCount(_totalLikes), 'Likes', Icons.favorite,
                        const Color(0xFFEF4444), cardColor, borderColor, textColor, subTextColor),
                    const SizedBox(width: 12),
                    _buildStatCard(_totalPosts.toString(), 'Posts', Icons.grid_view,
                        const Color(0xFF3B82F6), cardColor, borderColor, textColor, subTextColor),
                    const SizedBox(width: 12),
                    _buildStatCard(
                        _formatCount(_userPosts.fold(0, (sum, p) => sum + ((p['views_count'] ?? 0) as int))),
                        'Vues',
                        Icons.visibility,
                        const Color(0xFF10B981),
                        cardColor,
                        borderColor,
                        textColor,
                        subTextColor),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: borderColor),
                    bottom: BorderSide(color: borderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTab('STATUTS', 0, textColor, subTextColor, isDark),
                    const SizedBox(width: 60),
                    _buildTab('POSTS', 1, textColor, subTextColor, isDark),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: _selectedTab == 0
                  ? SliverToBoxAdapter(child: _buildStoryTabContent(textColor, subTextColor, isDark))
                  : SliverToBoxAdapter(
                      child: _userPosts.isEmpty
                          ? _buildEmptyState(textColor, subTextColor)
                          : _buildPostsGrid()),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index, Color textColor, Color subTextColor, bool isDark) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? textColor : subTextColor,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                // ✅ Soulignement noir en clair, blanc en sombre
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoryTabContent(Color textColor, Color subTextColor, bool isDark) {
    if (_userStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: textColor.withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(Icons.camera_alt_outlined, color: textColor, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Partagez un moment éphémère',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Votre statut disparaîtra après 24h.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
              ).then((_) => _loadProfileData()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Créer un statut', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                // ✅ Bouton adaptatif
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('Vos statuts récents',
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _userStories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildAddStoryButton(textColor);
              return _buildUserStoryItem(_userStories[index - 1], textColor, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddStoryButton(Color textColor) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
      ).then((_) => _loadProfileData()),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: textColor.withOpacity(0.3), width: 2),
              ),
              child: Icon(Icons.add, color: textColor, size: 28),
            ),
            const SizedBox(height: 6),
            Text('Ajouter', style: TextStyle(color: textColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStoryItem(Map<String, dynamic> story, Color textColor, bool isDark) {
    final mediaType = story['media_type'] ?? 'image';
    final mediaUrl = story['media_url'];
    final bgColor = story['background_color'];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewStoryScreen(
            stories: _userStories,
            creatorName: _profile?['full_name'] ?? 'Moi',
            creatorId: _profile?['id'] ?? '',
            creatorAvatar: _profile?['avatar_url'],
            initialIndex: _userStories.indexOf(story),
          ),
        ),
      ).then((_) => _loadProfileData()),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          children: [
            Container(
              width: 65,
              height: 65,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ✅ Contour adaptatif au lieu du gradient violet
                border: Border.all(
                  color: isDark ? Colors.white : Colors.black,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                ),
                child: ClipOval(child: _getStoryPreview(mediaType, mediaUrl, bgColor)),
              ),
            ),
            const SizedBox(height: 6),
            Text('Story', style: TextStyle(color: textColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _getStoryPreview(String mediaType, String? mediaUrl, String? bgColor) {
    if (mediaType == 'text' && bgColor != null) {
      try {
        return Container(
          color: Color(int.parse(bgColor.replaceAll('#', '0xFF'))),
          child: const Center(child: Icon(Icons.text_fields, color: Colors.white, size: 28)),
        );
      } catch (e) {
        return Container(
          color: Colors.grey,
          child: const Center(child: Icon(Icons.text_fields, color: Colors.white, size: 28)),
        );
      }
    } else if (mediaUrl != null) {
      return Image.network(mediaUrl,
          fit: BoxFit.cover,
          width: 65,
          height: 65,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image, color: Colors.grey, size: 28));
    }
    return const Icon(Icons.image, color: Colors.grey, size: 28);
  }

  Widget _buildPostsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final imageUrl = post['media_url'];
        final viewsCount = post['likes_count'] ?? 0;
        final mediaType = post['media_type'] ?? 'image';
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => UserPostsFeedScreen(posts: _userPosts, initialIndex: index)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl != null && imageUrl.toString().isNotEmpty
                    ? Image.network(imageUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.image, color: Colors.grey)))
                    : Container(color: Colors.grey[900]),
                Container(color: Colors.black.withOpacity(0.2)),
                if (mediaType == 'video')
                  const Positioned(
                      top: 6, right: 6, child: Icon(Icons.play_circle, color: Colors.white, size: 20)),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black87, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Text('${_formatCount(viewsCount)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: textColor.withOpacity(0.05), shape: BoxShape.circle),
          child: Icon(Icons.photo_library_outlined, color: subTextColor, size: 48),
        ),
        const SizedBox(height: 16),
        Text('Aucune publication.',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Partagez votre premier moment\navec votre communauté.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 13)),
      ],
    );
  }
}