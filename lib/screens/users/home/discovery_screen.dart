import 'dart:ui'; // Pour l'effet de flou (ImageFilter)
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Pour le double-tap
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart'; // Pour le partage dynamique
import '../../../theme/app_colors.dart';
import '../explore/explore_screen.dart';
import '../notifications/notifications_screen.dart';
import '../creator/creator_profile_screen.dart';
import '../creator/subscription_payment_screen.dart';
import '../../../widgets/tip_dialog.dart';
import '../../../widgets/report_dialog.dart';
import 'watch_live_screen.dart';
import 'post_detail_screen.dart';
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

// ✅ AJOUT DU MIXIN NATIF DE FLUTTER POUR GARDER L'ÉCRAN EN MÉMOIRE
class _DiscoveryScreenState extends State<DiscoveryScreen> with AutomaticKeepAliveClientMixin {
  final PageController _horizontalPageController = PageController(initialPage: 1);
  int _selectedTab = 1; // 0 = Abonnés, 1 = Pour toi

  List<Map<String, dynamic>> _posts = [];
  final Set<String> _likedPostIds = {};
  final Set<String> _followedCreatorIds = {};
  final Set<String> _subscribedCreatorIds = {};

  // Pour l'animation du cœur au double-tap
  final Map<String, bool> _heartAnimations = <String, bool>{};
  
  String? _currentUserId;
  String _currentUserName = 'Utilisateur';
  bool _isLoading = true;
  
  // ✅ NOUVEAU : Pour charger les données une seule fois
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchData();
  }

  @override
  void dispose() {
    _horizontalPageController.dispose();
    super.dispose();
  }

  // ✅ DIT À FLUTTER DE NE PAS DÉTRUIRE CET ÉCRAN QUAND ON CHANGE D'ONGLET
  @override
  bool get wantKeepAlive => true;

  // ✅ PULL-TO-REFRESH : Force le rechargement
  Future<void> _handleRefresh() async {
    _hasLoadedOnce = false; // On réinitialise pour forcer le téléchargement
    await _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // ✅ SI DÉJÀ CHARGÉ, ON NE FAIT RIEN (Gain de temps et de données énorme)
      if (_hasLoadedOnce) {
        debugPrint('⏭️ Données déjà en mémoire, pas de rechargement');
        return;
      }

      debugPrint('⏳ [FETCH] Récupération des données...');
      final userId = _currentUserId;

      if (userId != null) {
        final userProfile = await Supabase.instance.client
            .from('profiles')
            .select('username, full_name')
            .eq('id', userId)
            .maybeSingle();
        if (userProfile != null) {
          _currentUserName = userProfile['full_name'] ?? userProfile['username'] ?? 'Utilisateur';
        }

        final followsResponse = await Supabase.instance.client
            .from('follows')
            .select('following_id')
            .eq('follower_id', userId);
        _followedCreatorIds.clear();
        for (var row in followsResponse) {
          _followedCreatorIds.add(row['following_id'].toString());
        }

        final subsResponse = await Supabase.instance.client
            .from('subscriptions')
            .select('creator_id')
            .eq('fan_id', userId)
            .eq('status', 'active');
        _subscribedCreatorIds.clear();
        for (var sub in subsResponse) {
          _subscribedCreatorIds.add(sub['creator_id'].toString());
        }
      }

      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select('id, user_id, content, media_url, media_type, likes_count, comments_count, created_at')
          .order('created_at', ascending: false);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      if (posts.isEmpty) {
        if (!mounted) return;
        setState(() {
          _posts = [];
          _isLoading = false;
        });
        return;
      }

      final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', userIds);
      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profiles) p['id'] as String: p};

      if (userId != null) {
        final postIds = posts.map((p) => p['id'] as String).toList();
        final likesResponse = await Supabase.instance.client
            .from('post_likes')
            .select('post_id')
            .inFilter('post_id', postIds)
            .eq('user_id', userId);
        _likedPostIds.clear();
        for (var row in likesResponse) {
          _likedPostIds.add(row['post_id'].toString());
        }
      }

      final finalPosts = posts.map((post) {
        final creatorId = post['user_id'] as String;
        return {...post, 'profiles': profilesMap[creatorId]};
      }).toList();

      if (!mounted) return;
      setState(() {
        _posts = finalPosts;
        _isLoading = false;
      });
      
      // ✅ ON MARQUE COMME CHARGÉ POUR LA PROCHAINE FOIS
      _hasLoadedOnce = true; 
      
    } catch (e) {
      debugPrint('❌ [ERROR] Erreur lors du chargement : $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLike(String postId, int currentLikes, int postIndex, List<Map<String, dynamic>> postsList) async {
    final userId = _currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour liker'), backgroundColor: Colors.orange),
      );
      return;
    }

    final bool isAlreadyLiked = _likedPostIds.contains(postId);
    try {
      int newLikes = currentLikes;
      if (isAlreadyLiked) {
        newLikes = (currentLikes > 0) ? currentLikes - 1 : 0;
        await Supabase.instance.client.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
        _likedPostIds.remove(postId);
      } else {
        newLikes = currentLikes + 1;
        await Supabase.instance.client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
        _likedPostIds.add(postId);
      }
      await Supabase.instance.client.from('posts').update({'likes_count': newLikes}).eq('id', postId);

      if (!mounted) return;
      setState(() {
        final realIndex = _posts.indexWhere((p) => p['id'].toString() == postId);
        if (realIndex != -1) _posts[realIndex]['likes_count'] = newLikes;
      });
    } catch (e) {
      debugPrint('❌ [ERROR] Erreur Like : $e');
    }
  }

  void _handleDoubleTap(String postId, int currentLikes, int postIndex, List<Map<String, dynamic>> postsList) {
    if (!_likedPostIds.contains(postId)) {
      _handleLike(postId, currentLikes, postIndex, postsList);
    }
    setState(() {
      _heartAnimations[postId] = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _heartAnimations[postId] = false;
        });
      }
    });
  }

  Future<void> _handleFollow(String creatorId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final bool isAlreadyFollowed = _followedCreatorIds.contains(creatorId);
    try {
      if (isAlreadyFollowed) {
        await Supabase.instance.client.from('follows').delete().eq('follower_id', userId).eq('following_id', creatorId);
        _followedCreatorIds.remove(creatorId);
      } else {
        await Supabase.instance.client.from('follows').insert({'follower_id': userId, 'following_id': creatorId});
        _followedCreatorIds.add(creatorId);
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('❌ [ERROR] Erreur Follow : $e');
    }
  }

  void _openTipDialog(BuildContext context, String creatorId, String creatorName) {
    showDialog(
      context: context,
      builder: (context) => TipDialog(creatorId: creatorId, creatorName: creatorName),
    );
  }

  void _openSubscriptionPayment(BuildContext context, String creatorId, String creatorName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPaymentScreen(
          creatorId: creatorId,
          creatorName: creatorName,
          tierType: 'premium',
          price: 2000.0,
        ),
      ),
    ).then((success) {
      if (success == true) _fetchData();
    });
  }

  void _openComments(BuildContext context, String postId) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Commentaires',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client
                          .from('comments')
                          .select()
                          .eq('post_id', postId)
                          .order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Aucun commentaire',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment['user_name'] ?? 'Utilisateur',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    comment['content'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Ajouter un commentaire...',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              filled: true,
                              fillColor: Colors.black,
                              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primary),
                          onPressed: () async {
                            final content = commentController.text.trim();
                            if (content.isEmpty) return;

                            try {
                              await Supabase.instance.client.from('comments').insert({
                                'post_id': postId,
                                'user_id': _currentUserId,
                                'user_name': _currentUserName,
                                'content': content,
                              });

                              final post = _posts.firstWhere(
                                (p) => p['id'].toString() == postId,
                                orElse: () => {},
                              );
                              if (post.isNotEmpty) {
                                final newCount = (post['comments_count'] ?? 0) + 1;
                                await Supabase.instance.client
                                    .from('posts')
                                    .update({'comments_count': newCount})
                                    .eq('id', postId);

                                setState(() {
                                  final index = _posts.indexWhere(
                                    (p) => p['id'].toString() == postId,
                                  );
                                  if (index != -1) {
                                    _posts[index]['comments_count'] = newCount;
                                  }
                                });
                              }

                              commentController.clear();
                              setModalState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Commentaire ajouté'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            } catch (e) {
                              debugPrint('❌ Erreur lors de l\'ajout du commentaire : $e');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleShare(Map<String, dynamic> post) {
    final creatorName = post['profiles']?['full_name'] ?? 'Créateur';
    final caption = post['content'] ?? '';
    Share.share('Regarde ce post de $creatorName sur Afrifan : $caption');
  }

  Future<void> _joinLive() async {
    try {
      final lives = await Supabase.instance.client
          .from('live_streams')
          .select('id, creator_id, title')
          .eq('status', 'live')
          .limit(1);

      if (lives.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔴 Aucun live en cours pour le moment.'),
            backgroundColor: Color(0xFF424242),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final live = lives[0];
      final creatorId = live['creator_id'] as String;

      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name, avatar_url')
          .eq('id', creatorId)
          .limit(1);

      final profile = profiles.isNotEmpty ? profiles[0] : null;
      final creatorName = profile != null
          ? (profile['full_name'] ?? profile['username'] ?? 'Créateur')
          : 'Créateur';
      final creatorAvatar = profile != null ? profile['avatar_url'] : null;

      bool isSubscribed = false;
      if (_currentUserId != null) {
        final subs = await Supabase.instance.client
            .from('subscriptions')
            .select('id')
            .eq('fan_id', _currentUserId!)
            .eq('creator_id', creatorId)
            .eq('status', 'active')
            .limit(1);
        isSubscribed = subs.isNotEmpty;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WatchLiveScreen(
            liveId: live['id'],
            creatorName: creatorName,
            creatorAvatar: creatorAvatar,
            isSubscribed: isSubscribed,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de la recherche de live : $e');
    }
  }

  Widget _buildPostsPageView(List<Map<String, dynamic>> postsList) {
    if (postsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_collection_outlined,
              size: 60,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 0
                  ? 'Aucune publication de vos abonnements'
                  : 'Aucune publication pour le moment',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: postsList.length,
      itemBuilder: (context, index) {
        final post = postsList[index];
        final postId = post['id']?.toString() ?? '';
        final caption = post['content'] ?? '';
        final mediaUrl = post['media_url'];
        final creatorId = post['user_id']?.toString() ?? '';
        final creatorName = post['profiles']?['full_name'] ?? 'Créateur';
        final likesCount = post['likes_count']?.toString() ?? '0';
        final commentsCount = post['comments_count']?.toString() ?? '0';

        final bool isLiked = _likedPostIds.contains(postId);
        final bool isFollowed = _followedCreatorIds.contains(creatorId);
        final bool isMyOwnPost = (_currentUserId == creatorId);
        final bool isLocked = !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);
        final bool showHeart = _heartAnimations[postId] == true;

        return GestureDetector(
          onDoubleTap: () => _handleDoubleTap(
            postId,
            int.tryParse(likesCount) ?? 0,
            index,
            postsList,
          ),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (mediaUrl != null && mediaUrl.toString().isNotEmpty)
                isLocked
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54),
                          ),
                        ),
                      )
                    : Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54),
                        ),
                      )
              else
                Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54),
                  ),
                ),

              if (showHeart)
                const Center(
                  child: Icon(Icons.favorite, color: Colors.redAccent, size: 100),
                ),

              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              if (isLocked)
                GestureDetector(
                  onTap: () => _openSubscriptionPayment(context, creatorId, creatorName),
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.visibility_off,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Contenu réservé aux abonnés',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cliquez ici pour vous abonner',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                left: 16,
                right: 80,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorProfileScreen(creatorId: creatorId),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: post['profiles']?['avatar_url'] != null
                                ? NetworkImage(post['profiles']!['avatar_url'])
                                : null,
                            child: post['profiles']?['avatar_url'] == null
                                ? const Icon(Icons.person, color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              creatorName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isFollowed)
                            GestureDetector(
                              onTap: () => _handleFollow(creatorId),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Suivre',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                                        // ✅ BLOC LÉGENDE AVEC "VOIR PLUS"
                    GestureDetector(
                      onTap: () {
                        // Ouvre l'écran de détail complet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailScreen(post: post),
                          ),
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caption.isEmpty ? '📝 (Pas de légende)' : caption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                height: 1.4,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // ✅ AFFICHE "VOIR PLUS" SI LE TEXTE EST LONG
                            if (caption.length > 100)
                              const Text(
                                '... Voir plus',
                                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                right: 12,
                bottom: 20,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorProfileScreen(creatorId: creatorId),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: post['profiles']?['avatar_url'] != null
                                ? NetworkImage(post['profiles']!['avatar_url'])
                                : null,
                            child: post['profiles']?['avatar_url'] == null
                                ? const Icon(Icons.person, color: Colors.white, size: 24)
                                : null,
                          ),
                          if (!isFollowed)
                            Positioned(
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSideButton(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      likesCount,
                      () => _handleLike(
                        postId,
                        int.tryParse(likesCount) ?? 0,
                        index,
                        postsList,
                      ),
                      iconColor: isLiked ? Colors.redAccent : Colors.white,
                    ),
                    const SizedBox(height: 20),
                    _buildSideButton(
                      Icons.chat_bubble_rounded,
                      commentsCount,
                      () => _openComments(context, postId),
                    ),
                    const SizedBox(height: 20),
                    _buildSideButton(
                      Icons.local_cafe,
                      '',
                      () => _openTipDialog(context, creatorId, creatorName),
                      iconColor: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 20),
                    _buildSideButton(
                      Icons.share,
                      '',
                      () => _handleShare(post),
                    ),
                    const SizedBox(height: 20),
                    _buildSideButton(
                      Icons.more_vert,
                      '',
                      () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF1A1A1A),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.flag_outlined,
                                  color: Colors.redAccent,
                                ),
                                title: const Text(
                                  'Signaler ce post',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    builder: (context) => ReportDialog(
                                      targetId: postId,
                                      targetType: 'post',
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ OBLIGATOIRE QUAND ON UTILISE AutomaticKeepAliveClientMixin
    super.build(context); 
    
    final followedPosts = _posts.where((post) {
      final creatorId = post['user_id']?.toString() ?? '';
      return _followedCreatorIds.contains(creatorId);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppColors.primary,
                  child: PageView(
                    controller: _horizontalPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedTab = index;
                      });
                    },
                    children: [
                      _buildPostsPageView(followedPosts),
                      _buildPostsPageView(_posts),
                    ],
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _joinLive,
                        child: const Row(
                          children: [
                            Icon(
                              Icons.videocam,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildTopTab('Abonnés', 0),
                          const SizedBox(width: 20),
                          _buildTopTab('Pour toi', 1),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ExploreScreen(),
                              ),
                            ),
                            child: const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationsScreen(),
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopTab(String title, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        _horizontalPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 32),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}