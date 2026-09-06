import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/tip_dialog.dart';
import '../../../widgets/report_dialog.dart';
import '../../../services/share_service.dart';

class PostDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;
  final String creatorId;
  final String creatorName;

  const PostDetailScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
    required this.creatorId,
    required this.creatorName,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PageController _pageController;
  final supabase = Supabase.instance.client;
  String? _currentUserId;
  String _currentUserName = 'Utilisateur';

  Set<String> _likedPostIds = {};
  bool _isFollowing = false;

  // Stockage des contrôleurs vidéo par postId
  final Map<String, VideoPlayerController> _videoControllers = {};

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
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Callback pour recevoir le contrôleur vidéo
  void _onVideoControllerReady(VideoPlayerController controller, String postId) {
    setState(() {
      _videoControllers[postId] = controller;
    });
  }

  Future<void> _loadUserData() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final userProfile = await supabase.from('profiles').select('username, full_name').eq('id', userId).maybeSingle();
      if (userProfile != null) {
        _currentUserName = userProfile['full_name'] ?? userProfile['username'] ?? 'Utilisateur';
      }

      final followCheck = await supabase.from('follows').select().eq('follower_id', userId).eq('following_id', widget.creatorId).maybeSingle();
      if (mounted) setState(() => _isFollowing = followCheck != null);

      final postIds = widget.posts.map((p) => p['id'].toString()).toList();
      final likesResponse = await supabase.from('post_likes').select('post_id').inFilter('post_id', postIds).eq('user_id', userId);
      if (mounted) {
        setState(() {
          _likedPostIds = likesResponse.map((row) => row['post_id'].toString()).toSet();
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement user: $e');
    }
  }

  Future<void> _handleLike(String postId, int currentLikes, int postIndex) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final isLiked = _likedPostIds.contains(postId);
    try {
      int newLikes = currentLikes;
      if (isLiked) {
        newLikes = (currentLikes > 0) ? currentLikes - 1 : 0;
        await supabase.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
        setState(() => _likedPostIds.remove(postId));
      } else {
        newLikes = currentLikes + 1;
        await supabase.from('post_likes').insert({'post_id': postId, 'user_id': userId});
        setState(() => _likedPostIds.add(postId));
      }
      await supabase.from('posts').update({'likes_count': newLikes}).eq('id', postId);

      setState(() {
        if (postIndex < widget.posts.length) {
          widget.posts[postIndex]['likes_count'] = newLikes;
        }
      });
    } catch (e) {
      debugPrint('❌ Erreur like: $e');
    }
  }

  Future<void> _handleFollow() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      if (_isFollowing) {
        await supabase.from('follows').delete().eq('follower_id', userId).eq('following_id', widget.creatorId);
      } else {
        await supabase.from('follows').insert({'follower_id': userId, 'following_id': widget.creatorId});
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      debugPrint('❌ Erreur follow: $e');
    }
  }

  void _openComments(String postId, int currentComments, int postIndex) {
    final TextEditingController commentController = TextEditingController();
    final userId = _currentUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Commentaires', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: supabase.from('comments').select().eq('post_id', postId).order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey), SizedBox(height: 16), Text('Aucun commentaire', style: TextStyle(color: Colors.grey, fontSize: 16))]));
                        }
                        return ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment['user_name'] ?? 'Utilisateur', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Text(comment['content'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
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
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade800)),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(hintText: 'Ajouter un commentaire...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primary, size: 24),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            commentController.clear();
                            try {
                              await supabase.from('comments').insert({'post_id': postId, 'content': text, 'user_name': userId != null ? _currentUserName : 'Utilisateur'});
                              final totalComments = await supabase.from('comments').count(CountOption.exact).eq('post_id', postId);
                              await supabase.from('posts').update({'comments_count': totalComments}).eq('id', postId);
                              setModalState(() {});
                              setState(() {
                                if (postIndex < widget.posts.length) widget.posts[postIndex]['comments_count'] = totalComments;
                              });
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

  void _openTipDialog() {
    showDialog(
      context: context,
      builder: (context) => TipDialog(
        creatorId: widget.creatorId,
        creatorName: widget.creatorName,
      ),
    );
  }

  void _handleShare(Map<String, dynamic> post) {
    // Utilisation de votre service de partage
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien du post copié !'), backgroundColor: Colors.green));
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // ─── WIDGET DE MÉDIA ──────────────────────────────────────

  Widget _buildMediaWidget(Map<String, dynamic> post, String postId) {
    final mediaType = post['media_type']?.toString() ?? 'image';
    final mediaUrl = post['media_url']?.toString();
    final caption = post['caption'] ?? post['content'] ?? post['title'] ?? '';
    final backgroundColorHex = post['background_color'];

    // ─── TEXTE ──────────────────────────────────────────────
    if (mediaType == 'text') {
      Color getBgColor() {
        if (backgroundColorHex == null) return Colors.grey.shade800;
        try {
          String hex = backgroundColorHex.replaceAll('#', '0xFF');
          return Color(int.parse(hex));
        } catch (e) {
          return Colors.grey.shade800;
        }
      }
      return Container(
        color: getBgColor(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              caption.isEmpty ? '📝 (Contenu texte vide)' : caption,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // ─── VIDÉO ──────────────────────────────────────────────
    if (mediaType == 'video' && mediaUrl != null && mediaUrl.isNotEmpty) {
      return _PostVideoPlayer(
        mediaUrl: mediaUrl,
        postId: postId,
        onControllerReady: _onVideoControllerReady,
      );
    }

    // ─── IMAGE ──────────────────────────────────────────────
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      return Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade900,
          child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54, size: 50)),
        ),
      );
    }

    // Fallback
    return Container(
      color: Colors.grey.shade900,
      child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54, size: 50)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          final postId = post['id']?.toString() ?? '';
          final caption = post['caption'] ?? post['content'] ?? post['title'] ?? '';
          final mediaType = post['media_type']?.toString() ?? 'image';
          final likesCount = post['likes_count'] ?? 0;
          final commentsCount = post['comments_count'] ?? 0;
          final isLiked = _likedPostIds.contains(postId);
          final createdAt = post['created_at'] != null ? DateTime.parse(post['created_at']) : DateTime.now();

          return Stack(
            fit: StackFit.expand,
            children: [
              // ─── 1. MÉDIA ──────────────────────────────────────
              _buildMediaWidget(post, postId),

              // ─── 2. DÉGRADÉ (sauf pour les posts texte déjà colorés) ──
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

              // ─── 3. BOUTON RETOUR ─────────────────────────────
              Positioned(
                top: 40,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),

              // ─── 4. BOUTONS DROITE ────────────────────────────
              Positioned(
                right: 12,
                bottom: 100, // remonté pour la barre
                child: Column(
                  children: [
                    _buildSideButton(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      _formatCount(likesCount),
                      () => _handleLike(postId, likesCount, index),
                      iconColor: isLiked ? Colors.redAccent : Colors.white,
                    ),
                    const SizedBox(height: 18),
                    _buildSideButton(
                      Icons.chat_bubble_rounded,
                      _formatCount(commentsCount),
                      () => _openComments(postId, commentsCount, index),
                    ),
                    const SizedBox(height: 18),
                    _buildSideButton(
                      Icons.local_cafe,
                      'Tip',
                      () => _openTipDialog(),
                      iconColor: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 18),
                    _buildSideButton(
                      Icons.share,
                      'Partager',
                      () => _handleShare(post),
                      iconColor: Colors.white,
                    ),
                    const SizedBox(height: 18),
                    PopupMenuButton<String>(
                      color: const Color(0xFF1A1A1A),
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                      onSelected: (value) {
                        if (value == 'report') {
                          showDialog(context: context, builder: (context) => ReportDialog(targetId: postId, targetType: 'post'));
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'report',
                          child: Row(children: [
                            Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Text('Signaler', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── 5. INFOS BAS GAUCHE ──────────────────────────
              Positioned(
                left: 16,
                right: 80,
                bottom: 100, // remonté pour la barre
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '@${widget.creatorName}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        if (!_isFollowing)
                          GestureDetector(
                            onTap: _handleFollow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                              child: const Text(
                                'Suivre',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.check_circle, color: Colors.grey, size: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      caption.isEmpty ? '📝 (Pas de légende)' : caption,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // ─── 6. BARRE DE CONTRÔLE VIDÉO (EN DERNIER) ──────
              if (mediaType == 'video' && _videoControllers.containsKey(postId))
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _VideoControlsBar(controller: _videoControllers[postId]!),
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
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGET LECTEUR VIDÉO (UNIQUEMENT LA VIDÉO, SANS BARRE)
// ═══════════════════════════════════════════════════════════════════
class _PostVideoPlayer extends StatefulWidget {
  final String mediaUrl;
  final String postId;
  final void Function(VideoPlayerController, String)? onControllerReady;

  const _PostVideoPlayer({
    required this.mediaUrl,
    required this.postId,
    this.onControllerReady,
  });

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.network(widget.mediaUrl);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        _controller!.play();
        _controller!.setLooping(true);
        widget.onControllerReady?.call(_controller!, widget.postId);
      }
    } catch (e) {
      debugPrint('❌ Erreur init vidéo post ${widget.postId}: $e');
    }
  }

  @override
  void dispose() {
    // Ne pas dispose ici, car le parent gère la durée de vie
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  WIDGET BARRE DE CONTRÔLE VIDÉO (AVEC MUTE ET VITESSE)
// ═══════════════════════════════════════════════════════════════════
class _VideoControlsBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoControlsBar({required this.controller});

  @override
  State<_VideoControlsBar> createState() => _VideoControlsBarState();
}

class _VideoControlsBarState extends State<_VideoControlsBar> {
  bool _isPlaying = false;
  bool _isMuted = false;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    _update();
  }

  void _update() {
    if (!mounted) return;
    setState(() {
      _isPlaying = widget.controller.value.isPlaying;
      _position = widget.controller.value.position;
      _duration = widget.controller.value.duration;
      _isMuted = widget.controller.value.volume == 0;
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _changeSpeed() {
    setState(() {
      if (_speed == 1.0) _speed = 1.5;
      else if (_speed == 1.5) _speed = 2.0;
      else _speed = 1.0;
      widget.controller.setPlaybackSpeed(_speed);
    });
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
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
              // ── Play/Pause + Temps ──
              Row(
                children: [
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // ── Mute + Vitesse ──
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _changeSpeed,
                    child: Text(
                      '${_speed}x',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
            ),
            child: Slider(
              value: _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                final seekTo = Duration(
                  milliseconds: (value * _duration.inMilliseconds).round(),
                );
                widget.controller.seekTo(seekTo);
                setState(() {
                  _position = seekTo;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}