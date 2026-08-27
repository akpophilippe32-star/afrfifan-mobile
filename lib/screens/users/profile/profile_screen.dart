import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_posts_feed_screen.dart';
import '../settings/settings_screen.dart';
import '../validation/personal_info_step.dart'; 
import 'creator_dashboard_screen.dart';
import 'create_story_screen.dart';
import 'view_story_screen.dart'; // ✅ AJOUTÉ : Pour ouvrir les stories du créateur

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _userPosts = [];
  
  // ✅ NOUVEAU : Liste des stories de l'utilisateur
  List<Map<String, dynamic>> _userStories = [];

  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  int _selectedTab = 0; // 0 = Statuts, 1 = Posts, 2 = Exclusifs, 3 = À propos

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

      // ✅ NOUVEAU : Charger les stories de l'utilisateur (la RLS filtre automatiquement celles de >24h)
      final storiesData = await Supabase.instance.client
          .from('stories')
          .select('id, media_url, media_type, text_content, background_color, created_at')
          .eq('creator_id', userId)
          .order('created_at', ascending: false)
          .timeout(connectionTimeout);

      setState(() { 
        _userPosts = posts;
        _totalPosts = _userPosts.length;
        _totalLikes = likes;
        _userStories = List<Map<String, dynamic>>.from(storiesData ?? []); // ✅ Stockage des stories
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
        color: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
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
                            GestureDetector(
                              onTap: _updateAvatar,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: CircleAvatar(
                                  backgroundColor: Colors.grey[900],
                                  backgroundImage: _profile?['avatar_url'] != null ? NetworkImage(_profile!['avatar_url']) : null,
                                  child: _profile?['avatar_url'] == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2),
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
                                    const Icon(Icons.verified, color: Colors.white, size: 22),
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
                                    const Icon(Icons.calendar_today, color: Colors.grey, size: 12),
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
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isCreator ? Icons.dashboard : Icons.monetization_on, color: Colors.white, size: 20),
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
                    _buildTab('Statuts', 0),
                    const SizedBox(width: 16),
                    _buildTab('Posts', 1),
                    const SizedBox(width: 16),
                    _buildTab('Exclusifs', 2),
                    const SizedBox(width: 16),
                    _buildTab('À propos', 3),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: _selectedTab == 0 
                    ? _buildStoryTabContent() // ✅ LOGIQUE MODIFIÉE ICI
                    : _userPosts.isEmpty
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

  // ✅ NOUVEAU : Interface intelligente pour l'onglet Statuts
  Widget _buildStoryTabContent() {
    // CAS 1 : L'utilisateur n'a PAS de story active
    if (_userStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'Partagez un moment éphémère',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre statut disparaîtra automatiquement après 24h.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const CreateStoryScreen())
                ).then((_) => _loadProfileData()); // Rafraîchir après création
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Créer un statut',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // CAS 2 : L'utilisateur a DES stories actives (Affichage style Instagram)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            'Vos statuts récents',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _userStories.length + 1, // +1 pour le bouton "Ajouter"
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAddStoryButton();
              }
              final story = _userStories[index - 1];
              return _buildUserStoryItem(story);
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            'Cliquez sur un statut pour voir qui l\'a regardé.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ✅ Bouton pour ajouter une nouvelle story
  Widget _buildAddStoryButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateStoryScreen()),
        ).then((_) => _loadProfileData()); // Rafraîchir la liste après ajout
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade700, width: 2, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ✅ Affichage d'une story existante de l'utilisateur
  Widget _buildUserStoryItem(Map<String, dynamic> story) {
    final mediaType = story['media_type'] ?? 'image';
    final mediaUrl = story['media_url'];
    final bgColor = story['background_color'];

    return GestureDetector(
      onTap: () {
        // Ouvre le lecteur de story en mode créateur
      // Ouvre le lecteur de story en mode créateur
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ViewStoryScreen(
      stories: _userStories,
      creatorName: _profile?['full_name'] ?? 'Moi',
      creatorId: _profile?['id'] ?? '', // ✅ CETTE LIGNE A ÉTÉ AJOUTÉE
      creatorAvatar: _profile?['avatar_url'],
      initialIndex: _userStories.indexOf(story),
    ),
  ),
).then((_) => _loadProfileData()); // Rafraîchir au retour (au cas où la story a expiré)
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(2), // Pour la bordure dégradée
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)], // Dégradé Afrifan/Insta
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.grey.shade900,
                ),
                child: ClipOval(
                  child: _getStoryPreview(mediaType, mediaUrl, bgColor),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Votre story', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ✅ Helper pour l'aperçu de la story dans le cercle
  Widget _getStoryPreview(String mediaType, String? mediaUrl, String? bgColor) {
    if (mediaType == 'text' && bgColor != null) {
      return Container(
        color: Color(int.parse(bgColor.replaceAll('#', '0xFF'))),
        child: const Center(child: Icon(Icons.text_fields, color: Colors.white, size: 30)),
      );
    } else if (mediaUrl != null) {
      return Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        width: 70,
        height: 70,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey, size: 30),
      );
    }
    return const Icon(Icons.image, color: Colors.grey, size: 30);
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
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.description, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
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
            index == 0 ? Icons.flash_on : index == 1 ? Icons.grid_view : index == 2 ? Icons.lock_outline : Icons.person_outline,
            color: isSelected ? Colors.white : Colors.grey,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 2,
              width: 20,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}