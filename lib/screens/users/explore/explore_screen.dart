import 'dart:ui'; // ✅ Pour l'effet de flou (ImageFilter)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../services/notification_service.dart';
import '../notifications/notifications_screen.dart';
import '../creator/creator_profile_screen.dart';
import '../creator/subscription_payment_screen.dart'; // ✅ Pour le paiement
import 'explore_post_detail_screen.dart';
import 'trending_creators_screen.dart';
import 'trending_posts_screen.dart';

final supabase = Supabase.instance.client;

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

// ✅ 1. AJOUT DU MIXIN POUR GARDER L'ÉCRAN EN MÉMOIRE
class _ExploreScreenState extends State<ExploreScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final NotificationService _notificationService = NotificationService();

  Set<String> _followedIds = {};
  Set<String> _subscribedCreatorIds = {}; // ✅ Pour gérer le contenu masqué
  String? _currentUserId;
  String _searchQuery = '';
  
  List<Map<String, dynamic>> _creators = [];
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false; // ✅ Pour charger une seule fois

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ 2. DIT À FLUTTER DE NE PAS DÉTRUIRE CET ÉCRAN
  @override
  bool get wantKeepAlive => true;

  // ✅ 3. CHARGEMENT UNIQUE + RÉINITIALISATION AU PULL-TO-REFRESH
  Future<void> _loadAllData() async {
    if (_hasLoadedOnce) {
      debugPrint('⏭️ Explore déjà en mémoire, pas de rechargement');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _fetchFollowedIds();
      await _fetchSubscriptions(); // ✅ Récupère les abonnements payants
      await _fetchAndSetCreators();
      await _fetchAndSetPosts();
      
      _hasLoadedOnce = true; // ✅ Marque comme chargé
    } catch (e) {
      debugPrint('❌ Erreur chargement Explore: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<void> _fetchFollowedIds() async {
    if (_currentUserId == null) {
      if (mounted) setState(() => _followedIds = <String>{}); // ✅ Initialise avec un Set vide
      return;
    }
    
    final response = await supabase.from('follows').select('following_id').eq('follower_id', _currentUserId!);
    if (mounted) {
      setState(() {
        _followedIds = response != null 
            ? response.map<String>((row) => row['following_id'] as String).toSet()
            : <String>{}; // ✅ Si response est null, utilise un Set vide
      });
    }
  }

  Future<void> _fetchSubscriptions() async {
    if (_currentUserId == null) {
      if (mounted) setState(() => _subscribedCreatorIds = <String>{}); // ✅ Initialise avec un Set vide
      return;
    }
    
    final response = await supabase
        .from('subscriptions')
        .select('creator_id')
        .eq('fan_id', _currentUserId!)
        .eq('status', 'active');
        
    if (mounted) {
      setState(() {
        _subscribedCreatorIds = response != null 
            ? response.map<String>((row) => row['creator_id'] as String).toSet()
            : <String>{}; // ✅ Si response est null, utilise un Set vide
      });
    }
  }

  Future<void> _fetchAndSetCreators() async {
    var query = supabase.from('profiles').select('id, username, full_name, avatar_url');
    if (_currentUserId != null) {
      query = query.neq('id', _currentUserId!); // ✅ .neq AVANT .limit
    }
    final response = await query.limit(50);
    
    if (mounted) {
      setState(() {
        _creators = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _fetchAndSetPosts() async {
    final postsResponse = await supabase
        .from('posts')
        .select('id, user_id, media_url, media_type, content, likes_count, comments_count, created_at')
        .order('created_at', ascending: false)
        .limit(30);

    final posts = List<Map<String, dynamic>>.from(postsResponse);
    if (posts.isEmpty) return;

    final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
    final profilesResponse = await supabase.from('profiles').select('id, username, avatar_url').inFilter('id', userIds);
    final profilesMap = {for (var p in List<Map<String, dynamic>>.from(profilesResponse)) p['id'] as String: p};

    if (mounted) {
      setState(() {
        _posts = posts.map((post) {
          final userId = post['user_id'] as String;
          return {
            ...post,
            'profiles': profilesMap[userId],
            'likes_count': post['likes_count'] ?? 0,
          };
        }).toList();
      });
    }
  }

  Future<void> _toggleFollow(String creatorId) async {
    if (_currentUserId == null) return;
    final isFollowing = _followedIds.contains(creatorId);

    setState(() {
      if (isFollowing) _followedIds.remove(creatorId);
      else _followedIds.add(creatorId);
    });

    try {
      if (isFollowing) {
        await supabase.from('follows').delete().match({'follower_id': _currentUserId!, 'following_id': creatorId});
      } else {
        await supabase.from('follows').insert({'follower_id': _currentUserId!, 'following_id': creatorId});
        await _notificationService.sendNewFollowerNotification(followerId: _currentUserId!, followedUserId: creatorId);
      }
    } catch (e) {
      debugPrint('❌ Erreur toggle follow: $e');
      setState(() {
        if (isFollowing) _followedIds.add(creatorId);
        else _followedIds.remove(creatorId);
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCreators {
    if (_searchQuery.isEmpty) return _creators;
    final query = _searchQuery.toLowerCase();
    return _creators.where((c) {
      final username = (c['username'] ?? '').toString().toLowerCase();
      final fullName = (c['full_name'] ?? '').toString().toLowerCase();
      return username.contains(query) || fullName.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPosts {
    if (_searchQuery.isEmpty) return _posts;
    final query = _searchQuery.toLowerCase();
    return _posts.where((p) {
      final caption = (p['content'] ?? '').toString().toLowerCase();
      final username = (p['profiles']?['username'] ?? '').toString().toLowerCase();
      return caption.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ OBLIGATOIRE AVEC AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                // ✅ 4. LE PULL-TO-REFRESH FORCE LE RECHARGEMENT
                onRefresh: () async {
                  _hasLoadedOnce = false;
                  await _loadAllData();
                },
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Découvrir', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                            icon: const Icon(Icons.notifications, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Rechercher des créateurs, des vidéos...',
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          suffixIcon: _searchQuery.isNotEmpty 
                              ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) 
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade900,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.star, color: Colors.purpleAccent, size: 18),
                              SizedBox(width: 6),
                              Text('Créateurs tendance', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrendingCreatorsScreen())),
                            child: const Text('Voir tout', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filteredCreators.length,
                          itemBuilder: (context, index) {
                            final creator = _filteredCreators[index];
                            final creatorId = creator['id'] as String;
                            final username = (creator['username'] ?? creator['full_name'] ?? 'Anonyme').toString();
                            final avatarUrl = creator['avatar_url']?.toString();
                            final isFollowing = _followedIds.contains(creatorId);

                            return Container(
                              width: 130,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId))),
                                    child: CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade800, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId))),
                                    child: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 28,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _toggleFollow(creatorId),
                                      style: ElevatedButton.styleFrom(backgroundColor: isFollowing ? Colors.grey.shade700 : AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: Text(isFollowing ? 'Suivi' : 'Suivre', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
                              SizedBox(width: 6),
                              Text('Pour toi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrendingPostsScreen())),
                            child: const Text('Voir tout', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ✅ 5. GRILLE DES POSTS AVEC SYSTÈME DE MASQUAGE (CADENAS/FLOU)
                      _filteredPosts.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucun résultat trouvé.', style: TextStyle(color: Colors.white54))))
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
                              itemCount: _filteredPosts.length,
                              itemBuilder: (context, index) {
                                final post = _filteredPosts[index];
                                final creatorId = post['user_id']?.toString() ?? '';
                                final profileData = post['profiles'] as Map<String, dynamic>?;
                                final username = profileData != null ? '@${profileData['username'] ?? 'inconnu'}' : '@inconnu';
                                final likesCount = post['likes_count'] as int? ?? 0;
                                final mediaUrl = post['media_url']?.toString();
                                final mediaType = post['media_type']?.toString() ?? 'image';

                                // ✅ LOGIQUE DE VERROUILLAGE
                                final bool isMyOwnPost = (_currentUserId == creatorId);
                                final bool isLocked = !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);

                                return GestureDetector(
                                  onTap: () {
                                    if (isLocked) {
                                      // Ouvre l'écran de paiement si c'est verrouillé
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SubscriptionPaymentScreen(
                                            creatorId: creatorId,
                                            creatorName: username,
                                            tierType: 'premium',
                                            price: 2000.0,
                                          ),
                                        ),
                                      ).then((success) {
                                        if (success == true) {
                                          _hasLoadedOnce = false; // Force le rechargement pour démasquer
                                          _loadAllData();
                                        }
                                      });
                                    } else {
                                      // Ouvre le détail si c'est déverrouillé
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => ExplorePostDetailScreen(posts: _filteredPosts, initialIndex: index)));
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Image avec flou si verrouillé
                                        if (mediaUrl != null)
                                          isLocked
                                              ? ImageFiltered(
                                                  imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                                  child: Image.network(mediaUrl, fit: BoxFit.cover),
                                                )
                                              : Image.network(mediaUrl, fit: BoxFit.cover)
                                        else
                                          Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple.shade900, Colors.black], begin: Alignment.topLeft, end: Alignment.bottomRight))),
                                        
                                        // Overlay sombre si verrouillé
                                        if (isLocked) Container(color: Colors.black.withOpacity(0.5)),

                                        // Icône Cadenas + Texte si verrouillé
                                        if (isLocked)
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.9), shape: BoxShape.circle),
                                                  child: const Icon(Icons.lock, color: Colors.white, size: 22),
                                                ),
                                                const SizedBox(height: 6),
                                                const Text('Exclusif', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),

                                        // Icône Play si vidéo (et non verrouillé)
                                        if (mediaType == 'video' && !isLocked) 
                                          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40)),

                                        // Infos en bas
                                        Positioned(
                                          bottom: 0, left: 0, right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.9)]),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(username, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 3, color: Colors.black)]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                Row(children: [const Icon(Icons.favorite, color: Colors.red, size: 12), const SizedBox(width: 4), Text(likesCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, shadows: [Shadow(blurRadius: 3, color: Colors.black)]))]),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}