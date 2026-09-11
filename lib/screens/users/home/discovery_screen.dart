import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../profile/profile_screen.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
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

  final Map<String, String?> _tapIndicators = {};
  final Map<String, DateTime> _lastTapTime = {};

  String? _currentUserId;
  String _currentUserName = 'Utilisateur';
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _isRefreshing = false;

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
    _videoControllers.values.forEach((c) => c.dispose());
    _videoControllers.clear();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ═══════════════════════════════════════════════════════════════
  //  TAP VIDÉO (style YouTube)
  // ═══════════════════════════════════════════════════════════════
  void _handleVideoTap(String postId, double tapX, double screenWidth) {
    final controller = _videoControllers[postId];
    if (controller == null || !controller.value.isInitialized) return;

    final now = DateTime.now();
    final lastTap = _lastTapTime[postId];
    final isDoubleTap = lastTap != null && now.difference(lastTap).inMilliseconds < 300;
    _lastTapTime[postId] = now;

    if (isDoubleTap) return;

    final third = screenWidth / 3;
    String zone;
    if (tapX < third) {
      zone = 'rewind';
    } else if (tapX > screenWidth - third) {
      zone = 'forward';
    } else {
      zone = 'center';
    }

    if (zone == 'rewind') {
      final newPos = controller.value.position - const Duration(seconds: 10);
      controller.seekTo(newPos.isNegative ? Duration.zero : newPos);
      _showTapIndicator(postId, 'rewind');
    } else if (zone == 'forward') {
      final maxDur = controller.value.duration;
      final newPos = controller.value.position + const Duration(seconds: 10);
      controller.seekTo(newPos > maxDur ? maxDur : newPos);
      _showTapIndicator(postId, 'forward');
    } else {
      if (controller.value.isPlaying) {
        controller.pause();
        _showTapIndicator(postId, 'pause');
      } else {
        controller.play();
        _showTapIndicator(postId, 'play');
      }
    }
  }

  void _showTapIndicator(String postId, String type) {
    setState(() => _tapIndicators[postId] = type);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _tapIndicators[postId] == type) {
        setState(() => _tapIndicators[postId] = null);
      }
    });
  }

  Widget _buildTapIndicator(String postId) {
    final type = _tapIndicators[postId];
    if (type == null) return const SizedBox.shrink();

    IconData icon;
    String label = '';
    switch (type) {
      case 'play':
        icon = Icons.play_arrow_rounded;
        break;
      case 'pause':
        icon = Icons.pause_rounded;
        break;
      case 'forward':
        icon = Icons.fast_forward_rounded;
        label = '+10s';
        break;
      case 'rewind':
        icon = Icons.fast_rewind_rounded;
        label = '-10s';
        break;
      default:
        icon = Icons.circle;
    }

    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 48),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
      if (_hasLoadedOnce && !_isRefreshing) return;

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
      if (mounted) setState(() => _heartAnimations[postId] = false);
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

  void _openComments(BuildContext context, String postId, bool isDark) {
    final TextEditingController commentController = TextEditingController();
    final sheetBg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final inputBg = isDark ? Colors.black : Colors.white;
    final border = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
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
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Commentaires',
                    style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
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
                          return Center(child: CircularProgressIndicator(color: textColor));
                        }
                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 60, color: isDark ? Colors.grey : Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun commentaire',
                                  style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 16, fontWeight: FontWeight.w500),
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
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment['user_name'] ?? 'Utilisateur',
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    comment['content'] ?? '',
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, height: 1.4),
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
                      color: inputBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ajouter un commentaire...',
                              hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
                              border: InputBorder.none,
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: textColor),
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
                                  final index = _posts.indexWhere((p) => p['id'].toString() == postId);
                                  if (index != -1) _posts[index]['comments_count'] = newCount;
                                });
                              }
                              commentController.clear();
                              setModalState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Commentaire ajouté'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
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
  //  FRONT-END
  // ════════════════════════════════════════════════════════════════

  Widget _buildPostsPageView(List<Map<String, dynamic>> postsList, bool isDark) {
    if (postsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_collection_outlined, size: 60, color: isDark ? Colors.white54 : Colors.black38),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 0 ? 'Aucune publication de vos abonnements' : 'Aucune publication pour le moment',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 14),
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
          if (backgroundColorHex == null) {
            return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
          }
          try {
            String hex = backgroundColorHex.replaceAll('#', '0xFF');
            return Color(int.parse(hex));
          } catch (e) {
            return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // ─── MÉDIA ──────────────────
            if (mediaType == 'text')
              GestureDetector(
                onDoubleTap: () => _handleDoubleTap(postId, int.tryParse(likesCount) ?? 0, index, postsList),
                child: Container(
                  color: getBgColor(),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        caption.isEmpty ? '...' : caption,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              )
            else if (mediaType == 'video')
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    _handleVideoTap(postId, details.localPosition.dx, MediaQuery.of(context).size.width);
                  },
                  onDoubleTap: () => _handleDoubleTap(postId, int.tryParse(likesCount) ?? 0, index, postsList),
                  child: _SmartMediaWidget(
                    localPath: null,
                    mediaUrl: mediaUrl,
                    mediaType: 'video',
                    onControllerReady: (controller) {
                      _videoControllers[postId] = controller;
                    },
                  ),
                ),
              )
            else
              (mediaUrl != null && mediaUrl.toString().isNotEmpty)
                  ? GestureDetector(
                      onDoubleTap: () => _handleDoubleTap(postId, int.tryParse(likesCount) ?? 0, index, postsList),
                      child: Image.network(mediaUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image,
                                  color: isDark ? Colors.white54 : Colors.black38))),
                    )
                  : Container(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                      child: Center(
                          child: Icon(Icons.image_not_supported,
                              size: 50, color: isDark ? Colors.white54 : Colors.black38)),
                    ),

            // ─── CADENAS ──────────────
            if (isLocked)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.white, size: 48),
                      SizedBox(height: 12),
                      Text('Contenu réservé aux abonnés',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

            // ─── CŒUR ANIMÉ ──────────────────
            if (showHeart)
              const Center(child: Icon(Icons.favorite, color: Colors.redAccent, size: 100)),

            // ─── DÉGRADÉ LISIBILITÉ (UNIQUEMENT POUR VIDÉO/IMAGE) ──────────────────
            if (mediaType != 'text')
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

            // ─── INDICATEUR DE TAP ───
            if (mediaType == 'video' && !isLocked)
              Positioned.fill(child: _buildTapIndicator(postId)),

            // ─── INFOS CRÉATEUR ───
            Positioned(
              left: 16,
              right: 80,
              bottom: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (isMyOwnPost) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId)));
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
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
                              shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isFollowed && !isMyOwnPost)
                          GestureDetector(
                            onTap: () => _handleFollow(creatorId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'S\'abonner',
                                style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.3,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // ─── BOUTONS D'ACTION ───
            Positioned(
              right: 12,
              bottom: 90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTikTokButton(
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? const Color(0xFFFF2D55) : Colors.white, size: 34),
                    label: likesCount,
                    onTap: () => _handleLike(postId, int.tryParse(likesCount) ?? 0, index, postsList),
                  ),
                  const SizedBox(height: 16),
                  _buildTikTokButton(
                    icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 32),
                    label: commentsCount,
                    onTap: () => _openComments(context, postId, isDark),
                  ),
                  const SizedBox(height: 16),
                  _buildTikTokButton(
                    icon: const Icon(Icons.diamond_outlined, color: Color(0xFFFFB800), size: 32),
                    label: 'Soutenir',
                    onTap: () => _openTipDialog(context, creatorId, creatorName),
                  ),
                  const SizedBox(height: 16),
                  _buildTikTokButton(
                    icon: Transform.rotate(angle: 3.14159, child: const Icon(Icons.reply, color: Colors.white, size: 36)),
                    label: 'Partager',
                    onTap: () => _handleShare(post),
                  ),
                  const SizedBox(height: 16),
                  if (mediaType != 'text') ...[
                    _buildTikTokButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 30),
                      label: 'Sauver',
                      onTap: () async {
                        if (mediaUrl == null) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Téléchargement...'), duration: Duration(seconds: 1), backgroundColor: Colors.black87),
                        );
                        final localPath = await OfflineManager.downloadVideoForOffline(postId, mediaUrl, post);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(localPath != null ? '✅ Sauvegardé' : '❌ Échec'),
                              backgroundColor: localPath != null ? Colors.green : Colors.red,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                    child: _buildTikTokButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.white, size: 30),
                      label: '',
                      onTap: () {
                        final menuBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
                        final textColor = isDark ? Colors.white : Colors.black87;
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: menuBg,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => Column(
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
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 28),
                                title: Text('Signaler ce contenu',
                                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                                onTap: () {
                                  Navigator.pop(context);
                                  showDialog(
                                    context: context,
                                    builder: (context) => ReportDialog(targetId: postId, targetType: 'post'),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ─── BARRE DE PROGRESSION ───
            if (mediaType == 'video')
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomVideoSlider(controller: _videoControllers[postId]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTikTokButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1))],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ✅ ÉCOUTE DU THÈME
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
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    final followedPosts = _posts.where((post) {
      final creatorId = post['user_id']?.toString() ?? '';
      return _followedCreatorIds.contains(creatorId);
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: textColor))
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
                      setState(() => _selectedTab = index);
                    },
                    children: [
                      _buildPostsPageView(followedPosts, isDark),
                      _buildPostsPageView(_posts, isDark),
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
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black54 : Colors.white70,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(color: textColor, strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text('Actualisation...',
                                style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ✅ HEADER ADAPTATIF
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
                            Text('LIVE',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildTopTab('Abonnés', 0, isDark),
                          const SizedBox(width: 20),
                          _buildTopTab('Pour toi', 1, isDark),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const ExploreScreen())),
                            child: Icon(Icons.search, color: textColor, size: 26),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                            child: Icon(Icons.notifications_none, color: textColor, size: 26),
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

  Widget _buildTopTab(String title, int index, bool isDark) {
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
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white60 : Colors.black45),
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
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGET _SmartMediaWidget
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
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (widget.mediaType.toLowerCase().contains('image') ||
        widget.mediaUrl?.toLowerCase().endsWith('.jpg') == true ||
        widget.mediaUrl?.toLowerCase().endsWith('.png') == true) {
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        return Image.file(File(widget.localPath!), fit: BoxFit.cover);
      } else if (widget.mediaUrl != null) {
        return Image.network(widget.mediaUrl!, fit: BoxFit.cover);
      }
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGET _BottomVideoSlider
// ═══════════════════════════════════════════════════════════════════
class _BottomVideoSlider extends StatefulWidget {
  final VideoPlayerController? controller;
  const _BottomVideoSlider({this.controller});

  @override
  State<_BottomVideoSlider> createState() => _BottomVideoSliderState();
}

class _BottomVideoSliderState extends State<_BottomVideoSlider> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
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
    }
  }

  @override
  void didUpdateWidget(covariant _BottomVideoSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_update);
      if (widget.controller != null) {
        widget.controller!.addListener(_update);
        _update();
        if (mounted) setState(() => _isReady = true);
      } else {
        if (mounted) setState(() => _isReady = false);
      }
    }
  }

  void _update() {
    if (!mounted || widget.controller == null) return;
    setState(() {
      _isPlaying = widget.controller!.value.isPlaying;
      _position = widget.controller!.value.position;
      _duration = widget.controller!.value.duration;
    });
  }

  void _togglePlayPause() {
    if (!_isReady || widget.controller == null) return;
    if (_isPlaying) {
      widget.controller!.pause();
    } else {
      widget.controller!.play();
    }
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
    // ✅ Le slider reste blanc (au-dessus de la vidéo) pour la lisibilité
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 16, top: 4, bottom: 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isReady && _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _isReady
                    ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                    : '--:-- / --:--',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _isReady && _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onChanged: _isReady
                  ? (value) {
                      setState(() {
                        _position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
                      });
                    }
                  : null,
              onChangeEnd: _isReady
                  ? (value) {
                      widget.controller!.seekTo(Duration(milliseconds: (value * _duration.inMilliseconds).round()));
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}