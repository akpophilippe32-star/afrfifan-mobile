import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class UserPostsFeedScreen extends StatefulWidget {
  final List<dynamic> posts;
  final int initialIndex;

  const UserPostsFeedScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<UserPostsFeedScreen> createState() => _UserPostsFeedScreenState();
}

class _UserPostsFeedScreenState extends State<UserPostsFeedScreen> {
  late PageController _pageController;
  final SupabaseClient _supabase = Supabase.instance.client;

  late List<bool> _isLikedList;
  late List<bool> _isSavedList;
  late List<int> _likesCountList;
  late List<int> _commentsCountList;

  // ✅ Stockage des contrôleurs vidéo par postId
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);

    final count = widget.posts.length;
    _isLikedList = List.generate(count, (index) => false);
    _isSavedList = List.generate(count, (index) => widget.posts[index]['is_saved'] == true);
    _likesCountList = List.generate(count, (index) => widget.posts[index]['likes_count'] ?? 0);
    _commentsCountList = List.generate(count, (index) => widget.posts[index]['comments_count'] ?? 0);

    _checkUserExistingLikes();
  }

  Future<void> _checkUserExistingLikes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    List<String> postIds = widget.posts.map((p) => p['id'].toString()).toList();

    try {
      final response = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('user_id', user.id)
          .filter('post_id', 'in', postIds);

      List<String> likedPostIds = (response as List).map((item) => item['post_id'].toString()).toList();

      if (mounted) {
        setState(() {
          for (int i = 0; i < widget.posts.length; i++) {
            String currentPostId = widget.posts[i]['id'].toString();
            if (likedPostIds.contains(currentPostId)) {
              _isLikedList[i] = true;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Erreur vérification likes : $e");
    }
  }

  void _onVideoControllerReady(VideoPlayerController controller, String postId) {
    setState(() {
      _videoControllers[postId] = controller;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ─── ACTIONS ──────────────────────────────────────────────

  void _toggleLike(int index, String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLikedList[index] = !_isLikedList[index];
      if (_isLikedList[index]) {
        _likesCountList[index]++;
      } else {
        _likesCountList[index]--;
      }
    });

    try {
      if (_isLikedList[index]) {
        await _supabase.from('post_likes').insert({'post_id': postId, 'user_id': user.id});
      } else {
        await _supabase.from('post_likes').delete().eq('post_id', postId).eq('user_id', user.id);
      }
    } catch (e) {
      debugPrint("Erreur Like : $e");
    }
  }

  void _handleDoubleTap(int index, String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null || _isLikedList[index]) return;

    setState(() {
      _isLikedList[index] = true;
      _likesCountList[index]++;
    });

    try {
      await _supabase.from('post_likes').insert({'post_id': postId, 'user_id': user.id});
    } catch (e) {
      debugPrint("Erreur Double Tap Like : $e");
    }
  }

  void _sharePost(String title, String imageUrl) async {
    try {
      await Share.share(
        'Regarde cette publication incroyable !\n\n* $title *\n\nDécouvre le média ici : $imageUrl',
        subject: 'Regarde ce post !',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir le partage natif.")),
      );
    }
  }

  void _openComments(BuildContext context, String postId, int index) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 12),
                  Text(
                    "Commentaires (${_commentsCountList[index]})",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(color: Colors.grey, height: 20),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: _supabase
                          .from('comments')
                          .select('id, content, created_at, profiles(username, avatar_url)')
                          .eq('post_id', postId)
                          .order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                        }
                        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text("Aucun commentaire. Soyez le premier !", style: TextStyle(color: Colors.grey)),
                          );
                        }

                        final comments = snapshot.data!;
                        return ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, cIndex) {
                            final comment = comments[cIndex];
                            final profile = comment['profiles'];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: NetworkImage(
                                      profile?['avatar_url'] ?? 'https://via.placeholder.com/150'
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile?['username'] ?? 'Anonyme',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment['content'] ?? '',
                                          style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Ajouter un commentaire...",
                              hintStyle: const TextStyle(color: Colors.white54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1A1A1A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF8B5CF6)),
                          onPressed: () async {
                            final user = _supabase.auth.currentUser;
                            if (user == null || commentController.text.trim().isEmpty) return;

                            try {
                              await _supabase.from('comments').insert({
                                'post_id': postId,
                                'user_id': user.id,
                                'content': commentController.text.trim(),
                              });
                              commentController.clear();
                              setState(() {
                                _commentsCountList[index]++;
                              });
                              setModalState(() {});
                            } catch (e) {
                              debugPrint("Erreur envoi commentaire : $e");
                            }
                          }
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

  // ─── WIDGET MÉDIA (CORRIGÉ ET BLINDÉ) ──────────────
  Widget _buildMediaWidget(int index) {
    final post = widget.posts[index];
    final postId = post['id']?.toString() ?? '';
    final mediaType = (post['media_type']?.toString() ?? 'image').toLowerCase();
    final mediaUrl = post['media_url']?.toString();
    
    // ✅ Extraction robuste du texte (vérifie toutes les clés possibles)
    final caption = (post['content'] ?? post['caption'] ?? post['text'] ?? post['description'] ?? '').toString().trim();
    final backgroundColorHex = post['background_color']?.toString();

    // 🔍 DEBUG : Regarde ta console pour voir EXACTEMENT ce que reçoit ce widget
    debugPrint('🔍 POST $index -> mediaType: "$mediaType" | caption: "$caption" | bgColor: "$backgroundColorHex"');

    // ─── TEXTE ──────────────────────────────────────────────
    if (mediaType == 'text') {
      Color getBgColor() {
        if (backgroundColorHex == null || backgroundColorHex.isEmpty) return Colors.grey.shade800;
        try {
          String hex = backgroundColorHex.startsWith('#') 
              ? backgroundColorHex.replaceAll('#', '0xFF') 
              : '0xFF$backgroundColorHex';
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
              caption.isEmpty 
                  ? '⚠️ AUCUN TEXTE TROUVÉ\n\nVérifiez que la requête SQL de l\'écran précédent inclut bien les colonnes "content", "caption" ou "description" !' 
                  : caption,
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

    // ─── FALLBACK ULTIME ─────────────────────────────────────
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 50),
            const SizedBox(height: 16),
            const Text('Type de média non reconnu ou URL manquante', style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Type: $mediaType\nURL: $mediaUrl', style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.posts.length,
            itemBuilder: (context, index) {
              final post = widget.posts[index];
              final postId = post['id']?.toString() ?? '';
              final title = post['title'] ?? post['content'] ?? post['caption'] ?? '';
              final mediaType = post['media_type']?.toString() ?? 'image';

              return Stack(
                fit: StackFit.expand,
                children: [
                  // ─── 1. MÉDIA (image, texte, vidéo sans barre) ──
                  GestureDetector(
                    onDoubleTap: () => _handleDoubleTap(index, postId),
                    child: _buildMediaWidget(index),
                  ),

                  // ─── 2. DÉGRADÉ ──────────────────────────────
                  if (mediaType != 'text')
                    IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                  // ─── 3. INFOS BAS GAUCHE ────────────────────
                  Positioned(
                    left: 16,
                    bottom: 100,
                    right: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "#artlife #creative #posts",
                          style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // ─── 4. BOUTONS DROITE ──────────────────────
                  Positioned(
                    right: 16,
                    bottom: 120,
                    child: Column(
                      children: [
                        _buildActionButton(
                          icon: _isLikedList[index] ? Icons.favorite : Icons.favorite_border,
                          iconColor: _isLikedList[index] ? Colors.purpleAccent : Colors.white,
                          label: _likesCountList[index].toString(),
                          onTap: () => _toggleLike(index, postId),
                        ),
                        const SizedBox(height: 20),
                        _buildActionButton(
                          icon: Icons.chat_bubble_outline,
                          iconColor: Colors.white,
                          label: _commentsCountList[index].toString(),
                          onTap: () => _openComments(context, postId, index),
                        ),
                        const SizedBox(height: 20),
                        _buildActionButton(
                          icon: _isSavedList[index] ? Icons.bookmark : Icons.bookmark_border,
                          iconColor: _isSavedList[index] ? Colors.purpleAccent : Colors.white,
                          label: _isSavedList[index] ? "Sauvé" : "Sauver",
                          onTap: () {
                            // À implémenter
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildActionButton(
                          icon: Icons.share,
                          iconColor: Colors.white,
                          label: "Partager",
                          onTap: () => _sharePost(title, post['media_url'] ?? ''),
                        ),
                      ],
                    ),
                  ),

                  // ─── 5. BARRE DE CONTRÔLE VIDÉO (EN DERNIER) ──
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

          // ─── BOUTON RETOUR ──────────────────────────────────
          Positioned(
            top: 50,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 35),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
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