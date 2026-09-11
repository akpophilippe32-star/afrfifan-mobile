import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../../../widgets/tip_dialog.dart';
import '../../../widgets/report_dialog.dart';
import '../creator/creator_profile_screen.dart';
import '../creator/subscription_payment_screen.dart';

class ExplorePostDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;

  const ExplorePostDetailScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<ExplorePostDetailScreen> createState() => _ExplorePostDetailScreenState();
}

class _ExplorePostDetailScreenState extends State<ExplorePostDetailScreen> {
  late PageController _pageController;
  final supabase = Supabase.instance.client;

  String? _currentUserId;
  String _currentUserName = 'Utilisateur';
  String? _currentUserAvatar;

  Set<String> _likedPostIds = {};
  Set<String> _subscribedCreatorIds = {};

  VideoPlayerController? _currentVideoController;
  String? _currentVideoPostId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentUserId = supabase.auth.currentUser?.id;
    _loadUserData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentVideoController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_currentUserId == null) return;
    try {
      final userProfile = await supabase.from('profiles').select('username, full_name, avatar_url').eq('id', _currentUserId!).maybeSingle();
      if (userProfile != null) {
        _currentUserName = userProfile['full_name'] ?? userProfile['username'] ?? 'Utilisateur';
        _currentUserAvatar = userProfile['avatar_url'];
      }

      final subsResponse = await supabase.from('subscriptions').select('creator_id').eq('fan_id', _currentUserId!).eq('status', 'active');
      if (mounted) {
        setState(() {
          _subscribedCreatorIds = subsResponse.map<String>((row) => row['creator_id'] as String).toSet();
        });
      }

      final postIds = widget.posts.map((p) => p['id'].toString()).toList();
      final likesResponse = await supabase.from('post_likes').select('post_id').inFilter('post_id', postIds).eq('user_id', _currentUserId!);
      if (mounted) {
        setState(() {
          _likedPostIds = likesResponse.map((row) => row['post_id'].toString()).toSet();
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement données utilisateur: $e');
    }
  }

  Future<void> _handleLike(String postId, int currentLikes, int postIndex) async {
    if (_currentUserId == null) return;
    final isLiked = _likedPostIds.contains(postId);
    try {
      int newLikes = currentLikes;
      if (isLiked) {
        newLikes = (currentLikes > 0) ? currentLikes - 1 : 0;
        await supabase.from('post_likes').delete().eq('post_id', postId).eq('user_id', _currentUserId!);
        setState(() => _likedPostIds.remove(postId));
      } else {
        newLikes = currentLikes + 1;
        await supabase.from('post_likes').insert({'post_id': postId, 'user_id': _currentUserId!});
        setState(() => _likedPostIds.add(postId));
      }
      await supabase.from('posts').update({'likes_count': newLikes}).eq('id', postId);
      setState(() {
        if (postIndex < widget.posts.length) widget.posts[postIndex]['likes_count'] = newLikes;
      });
    } catch (e) { debugPrint('❌ Erreur like: $e'); }
  }

  void _openComments(String postId, int postIndex, bool isDark) {
    final TextEditingController commentController = TextEditingController();

    final sheetBg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final inputBg = isDark ? Colors.black : Colors.white;
    final border = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final accentColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Commentaires', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: supabase.from('comments').select().eq('post_id', postId).order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: accentColor));
                        }
                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 60,
                                    color: isDark ? Colors.grey : Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text('Aucun commentaire',
                                    style: TextStyle(color: subTextColor, fontSize: 16)),
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
                              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment['user_name'] ?? 'Utilisateur',
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Text(comment['content'] ?? '',
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, height: 1.4)),
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
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: accentColor, size: 24),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            commentController.clear();
                            try {
                              await supabase.from('comments').insert({'post_id': postId, 'user_id': _currentUserId, 'user_name': _currentUserName, 'content': text});
                              final totalComments = await supabase.from('comments').count(CountOption.exact).eq('post_id', postId);
                              await supabase.from('posts').update({'comments_count': totalComments}).eq('id', postId);
                              setModalState(() {});
                              setState(() {
                                if (postIndex < widget.posts.length) widget.posts[postIndex]['comments_count'] = totalComments;
                              });
                            } catch (e) { debugPrint('❌ Erreur commentaire: $e'); }
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _onVideoControllerReady(VideoPlayerController controller, String postId) {
    setState(() {
      _currentVideoController = controller;
      _currentVideoPostId = postId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    // ✅ Accent noir/blanc selon thème
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          final postId = post['id']?.toString() ?? '';
          final creatorId = post['user_id']?.toString() ?? '';
          final caption = post['content'] ?? post['caption'] ?? post['title'] ?? '';
          final mediaUrl = post['media_url'];
          final mediaType = post['media_type']?.toString() ?? 'image';
          final backgroundColorHex = post['background_color'];

          final creatorName = post['profiles']?['username'] ?? 'Créateur';
          final creatorAvatar = post['profiles']?['avatar_url'];
          final likesCount = post['likes_count'] ?? 0;
          final commentsCount = post['comments_count'] ?? 0;
          final isLiked = _likedPostIds.contains(postId);

          final bool isMyOwnPost = (_currentUserId == creatorId);
          final bool isCreator = post['profiles']?['role'] == 'creator';
          final String accessLevel = post['access_level']?.toString() ?? 'public';
          final bool isPostPremium = accessLevel == 'premium' || accessLevel == 'pro';
          final bool isLocked = isCreator && isPostPremium && !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);

          Color getBgColor() {
            if (backgroundColorHex == null) return Colors.grey.shade800;
            try {
              String hex = backgroundColorHex.replaceAll('#', '0xFF');
              return Color(int.parse(hex));
            } catch (e) {
              return Colors.grey.shade800;
            }
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // ─── 1. MÉDIA ──────────────────────────────────────
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
                  child: _DetailVideoPlayer(
                    mediaUrl: mediaUrl,
                    isLocked: isLocked,
                    postId: postId,
                    onControllerReady: _onVideoControllerReady,
                    isDark: isDark,
                  ),
                )
              else
                (mediaUrl != null && mediaUrl.toString().isNotEmpty)
                    ? (isLocked
                        ? ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54))),
                          )
                        : Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54))))
                    : Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54))),

              // ─── 2. DÉGRADÉ ───────────────────────────────────
              if (mediaType != 'text')
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),

              // ─── 3. OVERLAY DE VERROUILLAGE ──────────────────
              if (isLocked)
                GestureDetector(
                  onTap: () {
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
                      if (success == true) _loadUserData();
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ Cadenas neutre adaptatif
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock, color: accentTextColor, size: 32),
                          ),
                          const SizedBox(height: 12),
                          const Text('Contenu Exclusif', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Abonne-toi pour voir ce post', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ─── 4. BOUTON RETOUR ─────────────────────────────
              Positioned(
                top: 40, left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),

              // ─── 5. BOUTONS VERTICAUX À DROITE ──────────────
              if (!isLocked)
                Positioned(
                  right: 12, bottom: 100,
                  child: Column(
                    children: [
                      _buildSideButton(isLiked ? Icons.favorite : Icons.favorite_border, _formatCount(likesCount), () => _handleLike(postId, likesCount, index), iconColor: isLiked ? Colors.redAccent : Colors.white),
                      const SizedBox(height: 18),
                      _buildSideButton(Icons.chat_bubble_rounded, _formatCount(commentsCount), () => _openComments(postId, index, isDark)),
                      const SizedBox(height: 18),
                      _buildSideButton(Icons.local_cafe, 'Tip', () => showDialog(context: context, builder: (context) => TipDialog(creatorId: creatorId, creatorName: creatorName)), iconColor: Colors.orangeAccent),
                      const SizedBox(height: 18),
                      _buildSideButton(Icons.share, 'Partager', () => Share.share('Regarde ce post de @$creatorName sur Afrifan : $caption'), iconColor: Colors.white),
                      const SizedBox(height: 18),
                      PopupMenuButton<String>(
                        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                        onSelected: (value) {
                          if (value == 'report') showDialog(context: context, builder: (context) => ReportDialog(targetId: postId, targetType: 'post'));
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Row(children: [
                              const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 12),
                              Text('Signaler', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // ─── 6. INFOS EN BAS À GAUCHE ──────────────────────
              Positioned(
                left: 16, right: 80, bottom: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId))),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade800, backgroundImage: creatorAvatar != null ? NetworkImage(creatorAvatar) : null, child: creatorAvatar == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null),
                          const SizedBox(width: 10),
                          Text('@$creatorName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (mediaType != 'text')
                      Text(caption.isEmpty ? '📝 (Pas de légende)' : caption, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))])),
                  ],
                ),
              ),

              // ─── 7. BARRE DE CONTRÔLE VIDÉO ──────
              if (mediaType == 'video' && _currentVideoPostId == postId && _currentVideoController != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _VideoControls(
                    controller: _currentVideoController,
                    isLocked: isLocked,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSideButton(IconData icon, String label, VoidCallback onTap, {Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 32),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1))],
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGET LECTEUR VIDÉO
// ═══════════════════════════════════════════════════════════════════
class _DetailVideoPlayer extends StatefulWidget {
  final String? mediaUrl;
  final bool isLocked;
  final String postId;
  final void Function(VideoPlayerController, String)? onControllerReady;
  final bool isDark;

  const _DetailVideoPlayer({
    Key? key,
    required this.mediaUrl,
    required this.isLocked,
    required this.postId,
    this.onControllerReady,
    this.isDark = true,
  }) : super(key: key);

  @override
  State<_DetailVideoPlayer> createState() => _DetailVideoPlayerState();
}

class _DetailVideoPlayerState extends State<_DetailVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.mediaUrl == null || widget.mediaUrl!.isEmpty) return;
    try {
      _controller = VideoPlayerController.network(widget.mediaUrl!);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        if (!widget.isLocked) {
          _controller!.play();
          _controller!.setLooping(true);
        }
        widget.onControllerReady?.call(_controller!, widget.postId);
      }
    } catch (e) {
      debugPrint('❌ Erreur init vidéo détail: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return Center(
        // ✅ Loader noir/blanc adaptatif
        child: CircularProgressIndicator(color: widget.isDark ? Colors.white : Colors.black),
      );
    }

    return GestureDetector(
      onTap: () {
        if (widget.isLocked) return;
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
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
//  WIDGET _VideoControls
// ═══════════════════════════════════════════════════════════════════
class _VideoControls extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool isLocked;
  const _VideoControls({this.controller, this.isLocked = false});

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
    if (!_isReady || widget.controller == null || widget.isLocked) return;
    if (_isPlaying) widget.controller!.pause();
    else widget.controller!.play();
  }

  void _toggleMute() {
    if (!_isReady || widget.controller == null || widget.isLocked) return;
    setState(() {
      _isMuted = !_isMuted;
      widget.controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _changeSpeed() {
    if (!_isReady || widget.controller == null || widget.isLocked) return;
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
    final isInteractive = _isReady && !widget.isLocked;

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
              Row(
                children: [
                  GestureDetector(
                    onTap: isInteractive ? _togglePlayPause : null,
                    child: Icon(
                      _isReady && _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: isInteractive ? Colors.white : Colors.white38,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isReady
                        ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                        : '--:-- / --:--',
                    style: TextStyle(
                      color: isInteractive ? Colors.white : Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: isInteractive ? _toggleMute : null,
                    child: Icon(
                      _isReady && _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: isInteractive ? Colors.white : Colors.white38,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: isInteractive ? _changeSpeed : null,
                    child: Text(
                      _isReady ? '${_speed}x' : '1x',
                      style: TextStyle(
                        color: isInteractive ? Colors.white : Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: isInteractive ? Colors.white : Colors.white38,
              overlayColor: Colors.white.withOpacity(0.2),
            ),
            child: Slider(
              value: _isReady && _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onChanged: isInteractive
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
              onChangeEnd: isInteractive
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