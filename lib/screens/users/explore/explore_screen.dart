import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../../../services/notification_service.dart';
import '../notifications/notifications_screen.dart';
import '../creator/creator_profile_screen.dart';
import '../creator/subscription_payment_screen.dart';
import 'explore_post_detail_screen.dart';
import 'trending_creators_screen.dart';
import 'trending_posts_screen.dart';

final supabase = Supabase.instance.client;

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final NotificationService _notificationService = NotificationService();

  Set<String> _followedIds = {};
  Set<String> _subscribedCreatorIds = {};
  String? _currentUserId;
  String _searchQuery = '';

  List<Map<String, dynamic>> _creators = [];
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _hasLoadedOnce = false;

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

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadAllData() async {
    if (_hasLoadedOnce) {
      debugPrint('⏭️ Explore déjà en mémoire');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _fetchFollowedIds();
      await _fetchSubscriptions();
      await _fetchAndSetCreators();
      await _fetchAndSetPosts();
      _hasLoadedOnce = true;
    } catch (e) {
      debugPrint('❌ Erreur chargement Explore: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFollowedIds() async {
    if (_currentUserId == null) {
      if (mounted) setState(() => _followedIds = <String>{});
      return;
    }
    final response = await supabase.from('follows').select('following_id').eq('follower_id', _currentUserId!);
    if (mounted) {
      setState(() {
        _followedIds = response != null
            ? response.map<String>((row) => row['following_id'] as String).toSet()
            : <String>{};
      });
    }
  }

  Future<void> _fetchSubscriptions() async {
    if (_currentUserId == null) {
      if (mounted) setState(() => _subscribedCreatorIds = <String>{});
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
            : <String>{};
      });
    }
  }

  Future<void> _fetchAndSetCreators() async {
    var query = supabase.from('profiles').select('id, username, full_name, avatar_url');
    if (_currentUserId != null) {
      query = query.neq('id', _currentUserId!);
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
        .select('id, user_id, media_url, media_type, content, caption, background_color, access_level, likes_count, comments_count, created_at')
        .order('created_at', ascending: false)
        .limit(30);

    final posts = List<Map<String, dynamic>>.from(postsResponse);
    if (posts.isEmpty) return;

    final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
    final profilesResponse = await supabase
        .from('profiles')
        .select('id, username, avatar_url, role')
        .inFilter('id', userIds);
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
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    final cardColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final searchFill = isDark ? Colors.grey.shade900 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: textColor))
            : RefreshIndicator(
                onRefresh: () async {
                  _hasLoadedOnce = false;
                  await _loadAllData();
                },
                color: textColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Découvrir',
                              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () => Navigator.push(
                                context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                            icon: Icon(Icons.notifications, color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: textColor),
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Rechercher des créateurs, des vidéos...',
                          hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: subTextColor),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: subTextColor),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  })
                              : null,
                          filled: true,
                          fillColor: searchFill,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── CRÉATEURS TENDANCE ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: isDark ? Colors.white : Colors.black, size: 18),
                              const SizedBox(width: 6),
                              Text('Créateurs tendance',
                                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (context) => const TrendingCreatorsScreen())),
                            child: Text('Voir tout',
                                style: TextStyle(
                                    color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
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
                            final username =
                                (creator['username'] ?? creator['full_name'] ?? 'Anonyme').toString();
                            final avatarUrl = creator['avatar_url']?.toString();
                            final isFollowing = _followedIds.contains(creatorId);

                            return Container(
                              width: 130,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                CreatorProfileScreen(creatorId: creatorId))),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                      child: avatarUrl == null
                                          ? Icon(Icons.person, color: textColor, size: 30)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                CreatorProfileScreen(creatorId: creatorId))),
                                    child: Text(username,
                                        style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 28,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _toggleFollow(creatorId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing
                                            ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400)
                                            : (isDark ? Colors.white : Colors.black),
                                        foregroundColor: isDark ? Colors.black : Colors.white,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(isFollowing ? 'Suivi' : 'Suivre',
                                          style: const TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── POUR TOI ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: isDark ? Colors.white : Colors.black, size: 18),
                              const SizedBox(width: 6),
                              Text('Pour toi',
                                  style: TextStyle(
                                      color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (context) => const TrendingPostsScreen())),
                            child: Text('Voir tout',
                                style: TextStyle(
                                    color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ✅ GRILLE AVEC MINIATURES VIDÉO + POSTS TEXTE
                      _filteredPosts.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                  child: Text('Aucun résultat trouvé.',
                                      style: TextStyle(color: subTextColor))),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.75),
                              itemCount: _filteredPosts.length,
                              itemBuilder: (context, index) {
                                final post = _filteredPosts[index];
                                final creatorId = post['user_id']?.toString() ?? '';
                                final profileData = post['profiles'] as Map<String, dynamic>?;
                                final username = profileData != null
                                    ? '@${profileData['username'] ?? 'inconnu'}'
                                    : '@inconnu';
                                final likesCount = post['likes_count'] as int? ?? 0;
                                final mediaUrl = post['media_url']?.toString();
                                final mediaType = post['media_type']?.toString() ?? 'image';
                                final content = post['content']?.toString() ?? '';
                                final bgColorHex = post['background_color']?.toString();

                                final bool isMyOwnPost = (_currentUserId == creatorId);
                                final bool isCreator = profileData?['role'] == 'creator';
                                final bool isPostPremium = post['access_level'] == 'premium' ||
                                    post['access_level'] == 'pro';
                                final bool isLocked = isCreator &&
                                    isPostPremium &&
                                    !isMyOwnPost &&
                                    !_subscribedCreatorIds.contains(creatorId);

                                return GestureDetector(
                                  onTap: () {
                                    if (isLocked) {
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
                                          _hasLoadedOnce = false;
                                          _loadAllData();
                                        }
                                      });
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => ExplorePostDetailScreen(
                                                posts: _filteredPosts, initialIndex: index)),
                                      );
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // ✅ 1. AFFICHAGE DU MÉDIA selon le type
                                        if (mediaType == 'text')
                                          _buildTextPreview(content, bgColorHex, isDark, isLocked)
                                        else if (mediaType == 'video' && mediaUrl != null)
                                          _buildVideoThumbnail(mediaUrl, isLocked, isDark)
                                        else if (mediaUrl != null)
                                          isLocked
                                              ? ImageFiltered(
                                                  imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                                  child: Image.network(mediaUrl, fit: BoxFit.cover),
                                                )
                                              : Image.network(mediaUrl, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                                                      child: Icon(Icons.image_not_supported,
                                                          color: subTextColor)))
                                        else
                                          Container(
                                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade300),

                                        if (isLocked) Container(color: Colors.black.withOpacity(0.5)),

                                        // ✅ 2. CADENAS SI VERROUILLÉ
                                        if (isLocked)
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.8),
                                                      shape: BoxShape.circle),
                                                  child: const Icon(Icons.lock,
                                                      color: Colors.white, size: 22),
                                                ),
                                                const SizedBox(height: 6),
                                                const Text('Exclusif',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),

                                        // ✅ 3. ICÔNE PLAY (petit, en haut à droite) pour les vidéos non verrouillées
                                        if (mediaType == 'video' && !isLocked)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.play_arrow,
                                                  color: Colors.white, size: 16),
                                            ),
                                          ),

                                        // ✅ 4. OVERLAY INFO EN BAS
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.9)
                                                  ]),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                    child: Text(username,
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            shadows: [
                                                              Shadow(blurRadius: 3, color: Colors.black)
                                                            ]),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis)),
                                                Row(children: [
                                                  const Icon(Icons.favorite,
                                                      color: Colors.red, size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(likesCount.toString(),
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          shadows: [
                                                            Shadow(blurRadius: 3, color: Colors.black)
                                                          ])),
                                                ]),
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

  // ═══════════════════════════════════════════════════════════════
  //  🎬 MINIATURE VIDÉO (via video_thumbnail)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVideoThumbnail(String videoUrl, bool isLocked, bool isDark) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          final image = Image.memory(snapshot.data!, fit: BoxFit.cover);
          return isLocked
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: image,
                )
              : image;
        }
        // Fallback si la miniature échoue
        return Container(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
          child: Center(
            child: Icon(Icons.videocam, size: 40, color: isDark ? Colors.white54 : Colors.black54),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  📝 APERÇU POST TEXTE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTextPreview(String content, String? bgColorHex, bool isDark, bool isLocked) {
    Color bgColor;
    if (bgColorHex != null && bgColorHex.isNotEmpty) {
      try {
        bgColor = Color(int.parse(bgColorHex.replaceAll('#', '0xFF')));
      } catch (_) {
        bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
      }
    } else {
      bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    }

    final textColor = bgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          content.isEmpty ? '...' : content,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}