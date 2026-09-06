import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../profile/profile_screen.dart'; // ✅ AJOUTÉ : Pour rediriger vers ton propre profil
import '../../../theme/app_colors.dart';
import '../../../services/offline_manager.dart';
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

class _DiscoveryScreenState extends State<DiscoveryScreen> with AutomaticKeepAliveClientMixin {
  final PageController _horizontalPageController = PageController(initialPage: 1);
  int _selectedTab = 1;

  List<Map<String, dynamic>> _posts = [];
  final Set<String> _likedPostIds = {};
  final Set<String> _followedCreatorIds = {};
  final Set<String> _subscribedCreatorIds = {};
  final Map<String, bool> _heartAnimations = <String, bool>{};

  String? _currentUserId;
  String _currentUserName = 'Utilisateur';
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _isRefreshing = false;

  // Stockage des contrôleurs vidéo par postId
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchData();
  }

  @override
  void dispose() {
    _horizontalPageController.dispose();
    // Nettoyer les contrôleurs vidéo
    _videoControllers.values.forEach((c) => c.dispose());
    _videoControllers.clear();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _hasLoadedOnce = false;
    });
    await _fetchData();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _fetchData() async {
    try {
      if (_hasLoadedOnce && !_isRefreshing) {
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
          .select('id, user_id, content, media_url, media_type, likes_count, comments_count, created_at, background_color')
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
          .select('id, username, full_name, avatar_url, role')
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
        final postData = {...post, 'profiles': profilesMap[creatorId]};
        OfflineManager.saveViewedVideo(postData);
        return postData;
      }).toList();

      if (!mounted) return;
      setState(() {
        _posts = finalPosts;
        _isLoading = false;
      });

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez-vous pour liker'), backgroundColor: Colors.orange));
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
    if (!_likedPostIds.contains(postId)) _handleLike(postId, currentLikes, postIndex, postsList);
    setState(() {
      _heartAnimations[postId] = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() {
        _heartAnimations[postId] = false;
      });
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
    showDialog(context: context, builder: (context) => TipDialog(creatorId: creatorId, creatorName: creatorName));
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
                                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Aucun commentaire',
                                  style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
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
                              debugPrint('❌ Erreur commentaire: $e');
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
      final creatorName = profile != null ? (profile['full_name'] ?? profile['username'] ?? 'Créateur') : 'Créateur';
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
      debugPrint('❌ Erreur live: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  PARTIE FRONT-END
  // ════════════════════════════════════════════════════════════════

  Widget _buildPostsPageView(List<Map<String, dynamic>> postsList) {
    if (postsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_collection_outlined, size: 60, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 0 ? 'Aucune publication de vos abonnements' : 'Aucune publication pour le moment',
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
        final mediaType = post['media_type'] ?? 'image';
        final backgroundColorHex = post['background_color'];

        final creatorId = post['user_id']?.toString() ?? '';
        final creatorName = post['profiles']?['full_name'] ?? 'Créateur';
        final likesCount = post['likes_count']?.toString() ?? '0';
        final commentsCount = post['comments_count']?.toString() ?? '0';

        final bool isLiked = _likedPostIds.contains(postId);
        final bool isFollowed = _followedCreatorIds.contains(creatorId);
        final bool isMyOwnPost = (_currentUserId == creatorId);

        final String creatorRole = post['profiles']?['role'] ?? 'user';
        final bool isCreator = creatorRole == 'creator';
        final bool isLocked = isCreator && !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);
        final bool showHeart = _heartAnimations[postId] == true;

        Color getBgColor() {
          if (backgroundColorHex == null) return Colors.grey.shade800;
          try {
            String hex = backgroundColorHex.replaceAll('#', '0xFF');
            return Color(int.parse(hex));
          } catch (e) {
            return Colors.grey.shade800;
          }
        }

        return GestureDetector(
          onDoubleTap: () => _handleDoubleTap(postId, int.tryParse(likesCount) ?? 0, index, postsList),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── MÉDIA (VIDÉO OU IMAGE) ──────────────────
              if (mediaType == 'text')
                Container(
                  color: getBgColor(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        caption.isEmpty ? '...' : caption,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (mediaType == 'video')
                Positioned.fill(
                  child: _SmartMediaWidget(
                    localPath: null,
                    mediaUrl: mediaUrl,
                    mediaType: 'video',
                    onControllerReady: (controller) {
                      _videoControllers[postId] = controller;
                    },
                  ),
                )
              else
                (mediaUrl != null && mediaUrl.toString().isNotEmpty)
                    ? Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)))
                    : Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54))),

              // ─── CADENAS (ABONNEMENT REQUIS) ──────────────
              if (isLocked)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, color: Colors.white, size: 48),
                        SizedBox(height: 12),
                        Text('Contenu réservé aux abonnés', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

              // ─── CŒUR ANIMÉ (DOUBLE TAP) ──────────────────
              if (showHeart)
                const Center(
                  child: Icon(Icons.favorite, color: Colors.redAccent, size: 100),
                ),

              // ─── DÉGRADÉ POUR LISIBILITÉ ──────────────────
              if (mediaType != 'text')
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

              // ─── INFOS EN BAS À GAUCHE (AVATAR, NOM, LÉGENDE) ──
              Positioned(
                left: 12,
                right: 80,
                bottom: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ ALGORITHME DE REDIRECTION INTELLIGENTE
                    GestureDetector(
                      onTap: () {
                        if (isMyOwnPost) {
                          // Si c'est MON propre post, je vais sur mon profil personnel
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        } else {
                          // Si c'est le post d'un AUTRE créateur, je vais sur son profil
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatorProfileScreen(creatorId: creatorId),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: post['profiles']?['avatar_url'] != null
                                ? NetworkImage(post['profiles']!['avatar_url'])
                                : null,
                            child: post['profiles']?['avatar_url'] == null
                                ? const Icon(Icons.person, color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              creatorName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // ✅ On n'affiche le bouton "S'abonner" que si ce n'est PAS mon propre post
                          if (!isFollowed && !isMyOwnPost)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'S\'abonner',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (caption.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 40),
                        child: Text(
                          caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              // ─── BOUTONS D'ACTION À DROITE ──────────────────
              Positioned(
                right: 8,
                bottom: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like
                    _buildActionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: likesCount,
                      onTap: () => _handleLike(postId, int.tryParse(likesCount) ?? 0, index, postsList),
                      iconColor: isLiked ? Colors.red : Colors.white,
                    ),
                    const SizedBox(height: 14),

                    // Commentaires
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: commentsCount,
                      onTap: () => _openComments(context, postId),
                    ),
                    const SizedBox(height: 14),

                    // Tips (pourboire)
                    _buildActionButton(
                      icon: Icons.local_cafe,
                      label: '',
                      onTap: () => _openTipDialog(context, creatorId, creatorName),
                      iconColor: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 14),

                    // Partager
                    _buildActionButton(
                      icon: Icons.share,
                      label: '',
                      onTap: () => _handleShare(post),
                    ),
                    const SizedBox(height: 14),

                    // Télécharger
                    if (mediaType != 'text')
                      _buildActionButton(
                        icon: Icons.download_rounded,
                        label: '',
                        onTap: () async {
                          if (mediaUrl == null) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Téléchargement en cours...'), duration: Duration(seconds: 2)),
                          );
                          final localPath = await OfflineManager.downloadVideoForOffline(postId, mediaUrl, post);
                          if (mounted) {
                            if (localPath != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Sauvegardé !'), backgroundColor: Colors.green),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('❌ Échec'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        iconColor: Colors.blueAccent,
                      ),
                    if (mediaType != 'text') const SizedBox(height: 14),

                    // Menu trois points (signalement)
                    _buildActionButton(
                      icon: Icons.more_vert,
                      label: '',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF1A1A1A),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                                title: const Text('Signaler', style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    builder: (context) => ReportDialog(targetId: postId, targetType: 'post'),
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

              // ─── BARRE DE CONTRÔLE VIDÉO (TOUJOURS AFFICHÉE) ──
              if (mediaType == 'video')
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _VideoControls(controller: _videoControllers[postId]),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── BOUTON D'ACTION RÉUTILISABLE ──────────────────────────
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 30),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1))],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo is ScrollUpdateNotification && scrollInfo.metrics.pixels < 0 && !_isRefreshing) {
                      _handleRefresh();
                    }
                    return false;
                  },
                  child: PageView(
                    controller: _horizontalPageController,
                    scrollDirection: Axis.vertical,
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

                if (_isRefreshing)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Actualisation...', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
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
                            Icon(Icons.videocam, color: Colors.redAccent, size: 24),
                            SizedBox(width: 6),
                            Text('LIVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
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
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExploreScreen())),
                            child: const Icon(Icons.search, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                            child: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
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
              fontSize: 15,
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
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGET _SmartMediaWidget (UNIQUEMENT LA VIDÉO, SANS BARRE DE CONTRÔLE)
// ═══════════════════════════════════════════════════════════════════
class _SmartMediaWidget extends StatefulWidget {
  final String? localPath;
  final String? mediaUrl;
  final String mediaType;
  final void Function(VideoPlayerController)? onControllerReady;

  const _SmartMediaWidget({
    Key? key,
    this.localPath,
    this.mediaUrl,
    required this.mediaType,
    this.onControllerReady,
  }) : super(key: key);

  @override
  State<_SmartMediaWidget> createState() => _SmartMediaWidgetState();
}

class _SmartMediaWidgetState extends State<_SmartMediaWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.mediaType.toLowerCase().contains('image') ||
          widget.mediaUrl?.toLowerCase().endsWith('.jpg') == true ||
          widget.mediaUrl?.toLowerCase().endsWith('.png') == true) {
        setState(() => _initialized = true);
        return;
      }

      VideoPlayerController? controller;
      if (kIsWeb) {
        if (widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty) {
          controller = VideoPlayerController.network(widget.mediaUrl!);
        }
      } else {
        if (widget.localPath != null && widget.localPath!.isNotEmpty) {
          controller = VideoPlayerController.file(File(widget.localPath!));
        } else if (widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty) {
          controller = VideoPlayerController.network(widget.mediaUrl!);
        }
      }

      if (controller == null) {
        setState(() => _hasError = true);
        return;
      }

      _controller = controller;
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
        controller.play();
        controller.setLooping(true);
        widget.onControllerReady?.call(controller);
      }
    } catch (e) {
      debugPrint('❌ Erreur initialisation média: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    // Ne pas dispose le contrôleur ici car il est géré par le parent
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              SizedBox(height: 8),
              Text('Média non disponible', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Image
    if (widget.mediaType.toLowerCase().contains('image') ||
        widget.mediaUrl?.toLowerCase().endsWith('.jpg') == true ||
        widget.mediaUrl?.toLowerCase().endsWith('.png') == true) {
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        return Image.file(File(widget.localPath!), fit: BoxFit.cover);
      } else if (widget.mediaUrl != null) {
        return Image.network(widget.mediaUrl!, fit: BoxFit.cover);
      }
    }

    // Vidéo (sans barre de contrôle, uniquement la lecture)
    return GestureDetector(
      onTap: () {
        if (_controller != null) {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        }
      },
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGET _VideoControls (BARRE DE CONTRÔLE AVEC GESTION DU CHARGEMENT)
// ═══════════════════════════════════════════════════════════════════
class _VideoControls extends StatefulWidget {
  final VideoPlayerController? controller;
  const _VideoControls({this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _isPlaying = false;
  bool _isMuted = false;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _attachListener();
  }

  void _attachListener() {
    if (widget.controller != null) {
      widget.controller!.addListener(_update);
      _update();
      setState(() => _isReady = true);
    } else {
      setState(() => _isReady = false);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_update);
      _attachListener();
    }
  }

  void _update() {
    if (!mounted || widget.controller == null) return;
    setState(() {
      _isPlaying = widget.controller!.value.isPlaying;
      _position = widget.controller!.value.position;
      _duration = widget.controller!.value.duration;
      _isMuted = widget.controller!.value.volume == 0;
    });
  }

  void _togglePlayPause() {
    if (!_isReady || widget.controller == null) return;
    if (_isPlaying) widget.controller!.pause();
    else widget.controller!.play();
  }

  void _toggleMute() {
    if (!_isReady || widget.controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      widget.controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _changeSpeed() {
    if (!_isReady || widget.controller == null) return;
    setState(() {
      if (_speed == 1.0) _speed = 1.5;
      else if (_speed == 1.5) _speed = 2.0;
      else _speed = 1.0;
      widget.controller!.setPlaybackSpeed(_speed);
    });
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Play/Pause + Temps
              Row(
                children: [
                  GestureDetector(
                    onTap: _isReady ? _togglePlayPause : null,
                    child: Icon(
                      _isReady && _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isReady
                        ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                        : '--:-- / --:--',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // Mute + Vitesse
              Row(
                children: [
                  GestureDetector(
                    onTap: _isReady ? _toggleMute : null,
                    child: Icon(
                      _isReady && _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _isReady ? _changeSpeed : null,
                    child: Text(
                      _isReady ? '${_speed}x' : '1x',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Slider interactif
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
            ),
            child: Slider(
              value: _isReady && _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onChanged: _isReady
                  ? (value) {
                      setState(() {
                        _isDragging = true;
                        _position = Duration(
                          milliseconds: (value * _duration.inMilliseconds).round(),
                        );
                      });
                    }
                  : null,
              onChangeStart: (_) => _isDragging = true,
              onChangeEnd: _isReady
                  ? (value) {
                      final seekTo = Duration(
                        milliseconds: (value * _duration.inMilliseconds).round(),
                      );
                      widget.controller!.seekTo(seekTo);
                      setState(() => _isDragging = false);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}