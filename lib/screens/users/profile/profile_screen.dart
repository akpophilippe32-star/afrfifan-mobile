import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_posts_feed_screen.dart';
import '../settings/settings_screen.dart';
import '../validation/personal_info_step.dart'; 
import 'creator_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _userPosts = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  int _selectedTab = 0;

  int _totalPosts = 0;
  int _totalLikes = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() { _isLoading = false; _errorMessage = "Utilisateur non connecté."; });
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

      _profile = profileData ?? {
        'username': 'utilisateur',
        'full_name': 'Nouvel Utilisateur',
        'avatar_url': 'https://via.placeholder.com/150',
        'role': 'user',
        'is_verified': false,
      };

      final postsData = await Supabase.instance.client
          .from('posts')
          .select('id, media_url, title, created_at, likes_count, media_type')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(connectionTimeout);

      final List<dynamic> posts = postsData ?? [];
      
      int likes = 0;
      for (var post in posts) {
        likes += (post['likes_count'] ?? 0) as int;
      }

      setState(() { 
        _userPosts = posts;
        _totalPosts = _userPosts.length;
        _totalLikes = likes;
      });
    } catch (error) {
      debugPrint("🚨 ERREUR CHARGEMENT PROFIL : $error");
      setState(() { _errorMessage = "Erreur de chargement."; });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAvatar() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 500);
    if (image == null) return;

    setState(() { _isUploading = true; });

    try {
      final file = File(image.path);
      final String fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage.from('avatars').upload(fileName, file, fileOptions: const FileOptions(upsert: true));
      final String publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);

      await Supabase.instance.client.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
      setState(() { _profile?['avatar_url'] = publicUrl; });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo mise à jour !"), backgroundColor: Colors.white));
      }
    } catch (e) {
      debugPrint("🚨 ERREUR UPLOAD AVATAR : $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _getMonthYear() {
    final now = DateTime.now();
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // ✅ CHANGÉ : Indicateur blanc
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 60),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadProfileData, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final bool isCreator = _profile?['is_verified'] == true && _profile?['role'] == 'creator';

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        color: Colors.white, // ✅ CHANGÉ : Blanc
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                // ✅ CHANGÉ : Dégradé noir/gris très sombre, plus de violet
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Color(0xFF111111)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2), // ✅ CHANGÉ : Bordure blanche
                              ),
                              child: CircleAvatar(
                                backgroundColor: Colors.grey[900],
                                backgroundImage: _profile?['avatar_url'] != null ? NetworkImage(_profile!['avatar_url']) : null,
                                child: _profile?['avatar_url'] == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _profile?['full_name']?.toUpperCase() ?? 'UTILISATEUR',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCreator) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.white, // ✅ CHANGÉ : Icône blanche
                                      size: 22,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${_profile?['username'] ?? 'username'}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.grey, size: 12), // ✅ CHANGÉ : Icône grise
                                    const SizedBox(width: 4),
                                    Text(
                                      'Membre depuis ${_getMonthYear()}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white, size: 26),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // ✅ CONSERVÉ : Le bouton principal reste VIOLET comme demandé
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (isCreator) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatorDashboardScreen()));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalInfoStep()));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6), // ✅ VIOLET CONSERVÉ ICI
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isCreator ? Icons.dashboard : Icons.monetization_on, 
                                    color: Colors.white, 
                                    size: 20
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCreator ? 'Tableau de bord' : 'Activer le compte',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Action modifier profil
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Modifier le profil',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _buildStatCard(_formatCount(_totalLikes), 'Likes', Icons.favorite_border),
                    const SizedBox(width: 12),
                    _buildStatCard(_totalPosts.toString(), 'Posts', Icons.description_outlined),
                    const SizedBox(width: 12),
                    _buildStatCard(_formatCount((_totalLikes * 1.5).toInt()), 'Vues', Icons.visibility_outlined),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildTab('Posts', 0),
                    const SizedBox(width: 24),
                    _buildTab('Exclusifs', 1),
                    const SizedBox(width: 24),
                    _buildTab('À propos', 2),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: _userPosts.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _userPosts.length,
                        itemBuilder: (context, index) {
                          final post = _userPosts[index];
                          final imageUrl = post['media_url'];
                          final viewsCount = post['likes_count'] ?? 0;
                          final mediaType = post['media_type'] ?? 'image';

                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UserPostsFeedScreen(posts: _userPosts, initialIndex: index)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  imageUrl != null && imageUrl.toString().isNotEmpty
                                      ? Image.network(
                                          imageUrl.toString(),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.grey[900],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          ),
                                        )
                                      : Container(color: Colors.grey[900]),
                                  Container(color: Colors.black.withOpacity(0.2)),
                                  if (mediaType == 'video')
                                    const Positioned(top: 6, right: 6, child: Icon(Icons.play_circle, color: Colors.white, size: 20)),
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.black87, Colors.transparent],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                      ),
                                      child: Text(
                                        '${_formatCount(viewsCount)}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24), // ✅ CHANGÉ : Icône blanche
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), // ✅ CHANGÉ : Texte gris
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), // ✅ CHANGÉ : Fond blanc très transparent
                shape: BoxShape.circle,
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1), // ✅ CHANGÉ : Fond blanc transparent
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.description, color: Colors.white, size: 48), // ✅ CHANGÉ : Icône blanche
                ),
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white, // ✅ CHANGÉ : Rond blanc
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 20),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Aucune publication.',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Publiez du contenu pour le partager avec\nvotre communauté.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            // Action créer un post
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white), // ✅ CHANGÉ : Bordure blanche
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 20), // ✅ CHANGÉ : Icône blanche
                SizedBox(width: 8),
                Text(
                  'Créer un post',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), // ✅ CHANGÉ : Texte blanc
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Icon(
            index == 0 ? Icons.grid_view : index == 1 ? Icons.lock_outline : Icons.person_outline,
            color: isSelected ? Colors.white : Colors.grey, // ✅ CHANGÉ : Blanc si sélectionné, gris sinon
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey, // ✅ CHANGÉ : Blanc si sélectionné
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 2,
              width: 20,
              color: Colors.white, // ✅ CHANGÉ : Ligne blanche
            ),
        ],
      ),
    );
  }
}