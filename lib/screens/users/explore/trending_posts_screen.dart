import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../creator/subscription_payment_screen.dart';
import 'explore_post_detail_screen.dart';

class TrendingPostsScreen extends StatefulWidget {
  const TrendingPostsScreen({super.key});

  @override
  State<TrendingPostsScreen> createState() => _TrendingPostsScreenState();
}

class _TrendingPostsScreenState extends State<TrendingPostsScreen> with AutomaticKeepAliveClientMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _posts = [];
  Set<String> _subscribedCreatorIds = {};
  String? _currentUserId;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadData();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadData() async {
    if (_hasLoadedOnce) {
      debugPrint('⏭️ TrendingPosts déjà en mémoire, pas de rechargement');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_currentUserId != null) {
        final subsResponse = await supabase
            .from('subscriptions')
            .select('creator_id')
            .eq('fan_id', _currentUserId!)
            .eq('status', 'active');

        _subscribedCreatorIds = subsResponse.map<String>((sub) => sub['creator_id'] as String).toSet();
      }

      final postsResponse = await supabase
          .from('posts')
          .select('id, user_id, media_url, media_type, content, likes_count, comments_count, created_at')
          .order('likes_count', ascending: false)
          .limit(50);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      if (posts.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', userIds);

      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profiles) p['id'] as String: p};

      _posts = posts.map((post) {
        final creatorId = post['user_id'] as String;
        return {
          ...post,
          'profiles': profilesMap[creatorId],
        };
      }).toList();

      _hasLoadedOnce = true;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur chargement TrendingPosts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
    final subTextColor = isDark ? Colors.white54 : Colors.black45;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final emptyBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contenu Populaire',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _posts.isEmpty
              ? Center(
                  child: Text(
                    'Aucun contenu populaire pour le moment.',
                    style: TextStyle(color: subTextColor),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _hasLoadedOnce = false;
                    await _loadData();
                  },
                  color: accentColor,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final creatorId = post['user_id']?.toString() ?? '';
                      final mediaUrl = post['media_url']?.toString();
                      final likesCount = post['likes_count'] ?? 0;
                      final creatorName = post['profiles']?['username'] ?? 'Créateur';

                      final bool isMyOwnPost = (_currentUserId == creatorId);
                      final bool isLocked = !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);

                      return GestureDetector(
                        onTap: () {
                          if (isLocked) {
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
                              if (success == true) {
                                _hasLoadedOnce = false;
                                _loadData();
                              }
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExplorePostDetailScreen(
                                  posts: _posts,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. IMAGE DE FOND
                              if (mediaUrl != null && mediaUrl.isNotEmpty)
                                isLocked
                                    ? ImageFiltered(
                                        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                        child: Image.network(mediaUrl, fit: BoxFit.cover),
                                      )
                                    : Image.network(mediaUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: emptyBg))
                              else
                                Container(color: emptyBg),

                              // 2. OVERLAY SOMBRE SI VERROUILLÉ
                              if (isLocked)
                                Container(color: Colors.black.withOpacity(0.5)),

                              // 3. CADENAS + TEXTE (SI VERROUILLÉ)
                              if (isLocked)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          // ✅ Cadenas neutre adaptatif
                                          color: accentColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.lock, color: accentTextColor, size: 24),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Contenu Exclusif',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),

                              // 4. ICÔNE VIDÉO
                              if (post['media_type'] == 'video' && !isLocked)
                                const Center(
                                  child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40),
                                ),

                              // 5. INFOS EN BAS
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
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '@$creatorName',
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
                                          const Icon(Icons.favorite, color: Colors.redAccent, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            likesCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                                            ),
                                          ),
                                        ],
                                      ),
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
                ),
    );
  }
}