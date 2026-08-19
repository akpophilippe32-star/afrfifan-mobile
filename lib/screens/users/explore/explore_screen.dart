import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../services/notification_service.dart'; // 👈 AJOUT 1 : Import du service
import '../notifications/notifications_screen.dart';
import '../creator/creator_profile_screen.dart'; // 👈 AJOUT
final supabase = Supabase.instance.client;

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 👇 AJOUT 2 : Instance du service de notification
  final NotificationService _notificationService = NotificationService();

  // Stocke les IDs des créateurs que l'utilisateur actuel suit déjà
  Set<String> _followedIds = {};

  @override
  void initState() {
    super.initState();
    print('🔄 Lancement de ExploreScreen...');
    _fetchFollowedIds();
  }

  // Récupère la liste des créateurs suivis par l'utilisateur connecté
  Future<void> _fetchFollowedIds() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('⚠️ Aucun utilisateur connecté.');
      return;
    }

    try {
      final response = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id);
      
      if (mounted) {
        setState(() {
          _followedIds = response.map<String>((row) => row['following_id'] as String).toSet();
        });
      }
      print('✅ Follows chargés : $_followedIds');
    } catch (e) {
      print('❌ Erreur chargement follows: $e');
    }
  }

  // Gère le clic sur le bouton Suivre / Suivi
  Future<void> _toggleFollow(String creatorId) async {
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour suivre ce créateur.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    final isFollowing = _followedIds.contains(creatorId);

    try {
      if (isFollowing) {
        // UNFOLLOW
        await supabase.from('follows').delete().match({
          'follower_id': user.id, 
          'following_id': creatorId
        });
        if (mounted) setState(() => _followedIds.remove(creatorId));
        print('👎 Unfollow réussi pour $creatorId');
      } else {
        // FOLLOW
        await supabase.from('follows').insert({
          'follower_id': user.id,
          'following_id': creatorId,
        });
        if (mounted) setState(() => _followedIds.add(creatorId));
        print('👍 Follow réussi pour $creatorId');

        // 👇 AJOUT 3 : Envoyer une notification à la personne suivie
        await _notificationService.sendNewFollowerNotification(
          followerId: user.id,
          followedUserId: creatorId,
        );
        print('🔔 Notification envoyée à $creatorId');
      }
    } catch (e) {
      print('❌ Erreur toggle follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCreators() async {
    try {
      final currentUser = supabase.auth.currentUser;

      var query = supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url');

      if (currentUser != null) {
        query = query.neq('id', currentUser.id);
      }

      final response = await query.limit(10);
      
      final creators = List<Map<String, dynamic>>.from(response);
      print('✅ CRÉATEURS RÉCUPÉRÉS (${creators.length}) : $creators');
      return creators;
    } catch (e) {
      print('❌ Erreur fetch creators: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    try {
      final postsResponse = await supabase
          .from('posts')
          .select('id, user_id, media_url, created_at')
          .order('created_at', ascending: false)
          .limit(20);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      print('✅ POSTS BRUTS RÉCUPÉRÉS (${posts.length})');

      if (posts.isEmpty) return [];

      final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();

      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, avatar_url')
          .inFilter('id', userIds);

      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profiles) p['id'] as String: p};

      final postIds = posts.map((p) => p['id'] as String).toList();
      final likesResponse = await supabase
          .from('post_likes')
          .select('post_id')
          .inFilter('post_id', postIds);

      final allLikes = List<Map<String, dynamic>>.from(likesResponse);
      final likesCount = <String, int>{};
      for (var like in allLikes) {
        final postId = like['post_id'] as String;
        likesCount[postId] = (likesCount[postId] ?? 0) + 1;
      }

      final finalPosts = posts.map((post) {
        final userId = post['user_id'] as String;
        final profile = profilesMap[userId];
        return {
          ...post,
          'profiles': profile,
          'likes_count': likesCount[post['id'] as String] ?? 0,
          'caption': post['caption'] ?? '',
          'media_type': post['media_type'] ?? 'image',
        };
      }).toList();

      print('✅ POSTS FUSIONNÉS : ${finalPosts.length} posts');
      return finalPosts;

    } catch (e, stack) {
      print('❌ Erreur fetch posts: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Découvrir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  },
  icon: const Icon(Icons.notifications, color: Colors.white),
),
                ],
              ),
              const SizedBox(height: 12),

              // 2. BARRE DE RECHERCHE
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher des créateurs, des vidéos...',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. SECTION "Créateurs tendance"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.purpleAccent, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Créateurs tendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text('Voir tout', style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),

              // CRÉATEURS DYNAMIQUES
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchCreators(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox(
                      height: 150,
                      child: Center(child: Text('Aucun créateur trouvé', style: TextStyle(color: Colors.white54))),
                    );
                  }

                  final creators = snapshot.data!;

                  return SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: creators.length,
                      itemBuilder: (context, index) {
                        final creator = creators[index];
                        final creatorId = creator['id'] as String;
                        final username = (creator['username'] ?? creator['full_name'] ?? 'Anonyme').toString();
                        final avatarUrl = creator['avatar_url']?.toString();
                        
                        final isFollowing = _followedIds.contains(creatorId);

                        return Container(
                          width: 130,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // 👇 Avatar cliquable
    GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreatorProfileScreen(
              creatorId: creatorId,
            ),
          ),
        );
      },
      child: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey.shade800,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null 
            ? const Icon(Icons.person, color: Colors.white, size: 30)
            : null,
      ),
    ),
    const SizedBox(height: 8),
    // 👇 Nom cliquable
    GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreatorProfileScreen(
              creatorId: creatorId,
            ),
          ),
        );
      },
      child: Text(
        username,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(height: 10),
                              SizedBox(
  height: 28,
  width: double.infinity,
  child: ElevatedButton(
    // 👇 Logique différente selon qu'on suit déjà ou pas
    onPressed: () {
      if (isFollowing) {
        // Déjà suivi → aller au profil du créateur
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreatorProfileScreen(
              creatorId: creatorId,
            ),
          ),
        );
      } else {
        // Pas encore suivi → faire le follow
        _toggleFollow(creatorId);
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: isFollowing ? Colors.grey.shade700 : AppColors.primary,
      foregroundColor: Colors.white,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    child: Text(
      isFollowing ? 'Voir profil' : 'Suivre',  // 👈 Texte modifié
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  ),
),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 4. SECTION "Pour toi" (Publications)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Pour toi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text('Voir tout', style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),

              // PUBLICATIONS DYNAMIQUES (GRILLE)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchPosts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('Aucune publication disponible', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  final posts = snapshot.data!;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      
                      final profileData = post['profiles'] as Map<String, dynamic>?;
                      final username = profileData != null ? '@${profileData['username'] ?? 'inconnu'}' : '@inconnu';
                      
                      final int likesCount = post['likes_count'] as int? ?? 0;

                      final mediaUrl = post['media_url']?.toString();
                      final mediaType = post['media_type']?.toString() ?? 'image';

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.grey.shade800,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              mediaUrl != null
                                  ? Image.network(mediaUrl, fit: BoxFit.cover)
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.purple.shade900, Colors.black],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                              
                              if (mediaType == 'video')
                              const Center(
                                child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 45),
                              ),
                              
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.favorite, color: Colors.red, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          likesCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white, 
                                            fontSize: 11, 
                                            shadows: [Shadow(blurRadius: 3, color: Colors.black)]
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  
}