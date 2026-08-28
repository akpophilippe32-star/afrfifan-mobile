import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_posts_feed_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/personal_info_screen.dart'; 
import 'creator_dashboard_screen.dart';
import 'create_story_screen.dart';
import 'view_story_screen.dart';
import '../validation/personal_info_step.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
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
  
  // ✅ NOUVEAU : Pour suivre le statut de la demande créateur
  String _applicationStatus = 'none'; // 'none', 'pending', 'rejected', 'accepted'

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadProfileData() async {
    if (_hasLoadedOnce) return;

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

      // ✅ VÉRIFICATION INTELLIGENTE DU STATUT DE LA DEMANDE CRÉATEUR
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

        if (appData != null) {
          _applicationStatus = appData['status']; // Sera 'pending' ou 'rejected'
        } else {
          _applicationStatus = 'none'; // Aucune demande précédente
        }
      }

      final postsData = await Supabase.instance.client
          .from('posts')
          .select('id, media_url, title, created_at, likes_count, media_type, views_count')
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
      if (mounted) setState(() { _errorMessage = "Erreur de chargement."; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.zoom_in, color: Colors.white),
              title: const Text('Voir en grand', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _viewAvatarFullScreen(); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF8B5CF6)),
              title: const Text('Modifier la photo', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _updateAvatar(); },
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
          appBar: AppBar(backgroundColor: Colors.black, elevation: 0, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
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

    setState(() { _isUploading = true; });

    try {
      final file = File(image.path);
      final String fileName = '$userId/avatar.jpg'; 

      final oldAvatarUrl = _profile?['avatar_url'];
      if (oldAvatarUrl != null && oldAvatarUrl.contains(fileName)) {
        try { await Supabase.instance.client.storage.from('avatars').remove([fileName]); } catch (_) {}
      }

      await Supabase.instance.client.storage.from('avatars').upload(fileName, file, fileOptions: const FileOptions(upsert: true));
      final String publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);

      await Supabase.instance.client.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
      
      if (mounted) {
        setState(() { _profile?['avatar_url'] = publicUrl; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo mise à jour !"), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("🚨 ERREUR UPLOAD AVATAR : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Échec de la mise à jour."), backgroundColor: Colors.red));
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));
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
                onPressed: () { _hasLoadedOnce = false; _loadProfileData(); }, 
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
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
        onRefresh: () async { _hasLoadedOnce = false; await _loadProfileData(); },
        color: const Color(0xFF8B5CF6),
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
                          icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                          tooltip: 'Paramètres',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingsScreen(username: _profile?['full_name']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _showAvatarOptions,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                              boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: CircleAvatar(
                              backgroundColor: Colors.black,
                              backgroundImage: _profile?['avatar_url'] != null ? NetworkImage(_profile!['avatar_url']) : null,
                              child: _profile?['avatar_url'] == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                            ),
                          ),
                          Positioned(
                            bottom: 5, right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 3),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5)],
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_profile?['full_name']?.toUpperCase() ?? 'UTILISATEUR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white, letterSpacing: 1)),
                        if (isCreator) ...[const SizedBox(width: 8), const Icon(Icons.verified, color: Color(0xFF8B5CF6), size: 24)],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('@${_profile?['username'] ?? 'username'}', style: const TextStyle(color: Colors.grey, fontSize: 15)),
                    const SizedBox(height: 24),
                    
                    // ✅ BOUTON D'ACTION INTELLIGENT
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_applicationStatus == 'accepted') {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatorDashboardScreen()));
                              } else if (_applicationStatus == 'pending') {
                                // ✅ EMPÊCHE DE RELANCER LA DEMANDE
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Votre demande est en cours de vérification. Veuillez patienter.'),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                // ✅ 'none' ou 'rejected' : on lance ou relance l'activation
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalInfoStep()));
                              }
                            },
                            icon: Icon(
                              _applicationStatus == 'accepted' ? Icons.dashboard : 
                              (_applicationStatus == 'pending' ? Icons.hourglass_top : Icons.monetization_on), 
                              size: 20,
                            ),
                            label: Text(
                              _applicationStatus == 'accepted' ? 'Tableau de bord' : 
                              (_applicationStatus == 'pending' ? 'En cours...' : 'Activer le compte'), 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              // ✅ Le bouton devient gris si c'est en cours
                              backgroundColor: _applicationStatus == 'pending' ? Colors.grey.shade700 : const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalInfoScreen())),
                            icon: const Icon(Icons.edit, size: 20),
                            label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
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
                    _buildStatCard(_formatCount(_totalLikes), 'Likes', Icons.favorite, const Color(0xFFEF4444)),
                    const SizedBox(width: 12),
                    _buildStatCard(_totalPosts.toString(), 'Posts', Icons.grid_view, const Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    _buildStatCard(_formatCount(_userPosts.fold(0, (sum, p) => sum + ((p['views_count'] ?? 0) as int))), 'Vues', Icons.visibility, const Color(0xFF10B981)),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF2A2A2A)), bottom: BorderSide(color: Color(0xFF2A2A2A))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTab('STATUTS', 0),
                    const SizedBox(width: 60),
                    _buildTab('POSTS', 1),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: _selectedTab == 0 
                  ? SliverToBoxAdapter(child: _buildStoryTabContent())
                  : SliverToBoxAdapter(child: _userPosts.isEmpty ? _buildEmptyState() : _buildPostsGrid()),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          if (isSelected)
            Container(margin: const EdgeInsets.only(top: 8), height: 3, width: 40, decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildStoryTabContent() {
    if (_userStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle), child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 48)),
            const SizedBox(height: 16),
            const Text('Partagez un moment éphémère', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Votre statut disparaîtra après 24h.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateStoryScreen())).then((_) => _loadProfileData()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Créer un statut', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('Vos statuts récents', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _userStories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildAddStoryButton();
              return _buildUserStoryItem(_userStories[index - 1]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddStoryButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateStoryScreen())).then((_) => _loadProfileData()),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          children: [
            Container(width: 65, height: 65, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade700, width: 2, style: BorderStyle.solid)), child: const Center(child: Icon(Icons.add, color: Colors.white, size: 28))),
            const SizedBox(height: 6),
            const Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStoryItem(Map<String, dynamic> story) {
    final mediaType = story['media_type'] ?? 'image';
    final mediaUrl = story['media_url'];
    final bgColor = story['background_color'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewStoryScreen(
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
              width: 65, height: 65, padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)])),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2), color: Colors.grey.shade900),
                child: ClipOval(child: _getStoryPreview(mediaType, mediaUrl, bgColor)),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Story', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _getStoryPreview(String mediaType, String? mediaUrl, String? bgColor) {
    if (mediaType == 'text' && bgColor != null) {
      try {
        return Container(color: Color(int.parse(bgColor.replaceAll('#', '0xFF'))), child: const Center(child: Icon(Icons.text_fields, color: Colors.white, size: 28)));
      } catch (e) {
        return Container(color: const Color(0xFF8B5CF6), child: const Center(child: Icon(Icons.text_fields, color: Colors.white, size: 28)));
      }
    } else if (mediaUrl != null) {
      return Image.network(mediaUrl, fit: BoxFit.cover, width: 65, height: 65, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey, size: 28));
    }
    return const Icon(Icons.image, color: Colors.grey, size: 28);
  }

  Widget _buildPostsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final imageUrl = post['media_url'];
        final viewsCount = post['likes_count'] ?? 0;
        final mediaType = post['media_type'] ?? 'image';

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserPostsFeedScreen(posts: _userPosts, initialIndex: index))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl != null && imageUrl.toString().isNotEmpty
                    ? Image.network(imageUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[900], child: const Icon(Icons.image, color: Colors.grey)))
                    : Container(color: Colors.grey[900]),
                Container(color: Colors.black.withOpacity(0.2)),
                if (mediaType == 'video') const Positioned(top: 6, right: 6, child: Icon(Icons.play_circle, color: Colors.white, size: 20)),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black87, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
                    child: Text('${_formatCount(viewsCount)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle), child: const Icon(Icons.photo_library_outlined, color: Colors.grey, size: 48)),
        const SizedBox(height: 16),
        const Text('Aucune publication.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Partagez votre premier moment\navec votre communauté.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}