import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class ViewStoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final String creatorName;
  final String creatorId;
  final String? creatorAvatar;
  final int initialIndex;

  const ViewStoryScreen({
    super.key,
    required this.stories,
    required this.creatorName,
    required this.creatorId,
    this.creatorAvatar,
    this.initialIndex = 0,
  });

  @override
  State<ViewStoryScreen> createState() => _ViewStoryScreenState();
}

class _ViewStoryScreenState extends State<ViewStoryScreen> {
  int _currentIndex = 0;
  bool _isPaused = false;
  VideoPlayerController? _videoController;
  Timer? _progressTimer;
  double _progress = 0.0;
  
  // États pour les interactions
  bool _hasLiked = false;
  int _viewCount = 0;
  int _likeCount = 0;
  bool _isCreator = false;
  List<Map<String, dynamic>> _interactions = [];
  
  static const Duration _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadCurrentStory();
  }

  // ✅ Charge la story et enregistre la vue / récupère les stats
  Future<void> _loadCurrentStory() async {
    _stopTimers();
    _videoController?.dispose();
    _videoController = null;
    _progress = 0.0;

    final story = widget.stories[_currentIndex];
    final mediaType = story['media_type'] ?? 'image';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId != null) {
      _isCreator = (currentUserId == widget.creatorId);

      // 1. Enregistrer la vue (Upsert)
      try {
        await Supabase.instance.client.from('story_interactions').upsert({
          'story_id': story['id'],
          'viewer_id': currentUserId,
          'has_liked': _hasLiked,
        }, onConflict: 'story_id,viewer_id');
      } catch (e) {
        debugPrint("⚠️ [VIEW] Échec enregistrement vue (non bloquant) : $e");
      }

      // 2. Récupérer les données selon le rôle
      if (_isCreator) {
        final response = await Supabase.instance.client
            .from('story_interactions')
            .select('has_liked, viewer_id, profiles(username, full_name, avatar_url)')
            .eq('story_id', story['id']);

        if (mounted) {
          setState(() {
            _interactions = List<Map<String, dynamic>>.from(response ?? []);
            _viewCount = _interactions.length;
            _likeCount = _interactions.where((i) => i['has_liked'] == true).length;
          });
        }
      } else {
        final response = await Supabase.instance.client
            .from('story_interactions')
            .select('has_liked')
            .eq('story_id', story['id'])
            .eq('viewer_id', currentUserId)
            .maybeSingle();
            
        if (mounted && response != null) {
          setState(() => _hasLiked = response['has_liked'] ?? false);
        }
      }
    }

    // 3. Charger le média
    if (mediaType == 'video' && story['media_url'] != null) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(story['media_url']),
      )..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.play();
            _videoController?.addListener(_onVideoProgress);
            _startProgressTimer(isVideo: true);
          }
        }).catchError((e) => debugPrint("❌ Erreur vidéo : $e"));
    } else {
      _startProgressTimer(isVideo: false);
    }
  }

  void _startProgressTimer({required bool isVideo}) {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isPaused) return;
      setState(() {
        if (isVideo && _videoController != null && _videoController!.value.duration.inMilliseconds > 0) {
          _progress = _videoController!.value.position.inMilliseconds / _videoController!.value.duration.inMilliseconds;
        } else {
          _progress += 0.05 / (_storyDuration.inMilliseconds / 50);
        }
      });
      if (_progress >= 1.0) _goToNextStory();
    });
  }

  void _onVideoProgress() {
    if (_videoController != null && _videoController!.value.position >= _videoController!.value.duration) {
      _goToNextStory();
    }
  }

  void _stopTimers() {
    _progressTimer?.cancel();
  }

  void _goToNextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() { _currentIndex++; _progress = 0.0; });
      _loadCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _goToPreviousStory() {
    if (_currentIndex > 0) {
      setState(() { _currentIndex--; _progress = 0.0; });
      _loadCurrentStory();
    } else {
      setState(() => _progress = 0.0);
    }
  }

  // ✅ Basculer le like (Optimistic UI)
  Future<void> _toggleLike() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    final newLikeState = !_hasLiked;
    
    // Mise à jour IMMÉDIATE de l'interface (le cœur devient rose instantanément)
    setState(() => _hasLiked = newLikeState); 

    final story = widget.stories[_currentIndex];
    
    try {
      await Supabase.instance.client.from('story_interactions').upsert({
        'story_id': story['id'],
        'viewer_id': currentUserId,
        'has_liked': newLikeState,
      }, onConflict: 'story_id,viewer_id');
    } catch (e) {
      debugPrint("❌ [LIKE] Erreur base de données : $e");
      // Annuler le changement visuel si l'envoi échoue
      setState(() => _hasLiked = !newLikeState); 
    }
  }

  // ✅ Afficher la liste des vues/likes pour le créateur
  void _showInteractionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text(
                'Vues et J\'aime ($_viewCount total)',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _interactions.isEmpty
                    ? const Center(child: Text('Aucune vue pour le moment', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _interactions.length,
                        itemBuilder: (context, index) {
                          final interaction = _interactions[index];
                          final profile = interaction['profiles'] ?? {};
                          final name = profile['full_name'] ?? profile['username'] ?? 'Utilisateur';
                          final avatar = profile['avatar_url'];
                          final hasLiked = interaction['has_liked'] == true;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null ? const Icon(Icons.person, color: Colors.white) : null,
                            ),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: Icon(
                              hasLiked ? Icons.favorite : Icons.visibility,
                              color: hasLiked ? Colors.red : Colors.grey,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onLongPress() { setState(() => _isPaused = true); _videoController?.pause(); }
  void _onLongPressEnd() { setState(() => _isPaused = false); _videoController?.play(); }

  Color _getTextColor(String? hexColor) {
    if (hexColor == '#FFFFFF' || hexColor == '#FBBF24') return Colors.black;
    return Colors.white;
  }

  @override
  void dispose() {
    _stopTimers();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const Scaffold(backgroundColor: Colors.black);

    final story = widget.stories[_currentIndex];
    final mediaType = story['media_type'] ?? 'image';
    final mediaUrl = story['media_url'];
    final textContent = story['text_content'];
    final backgroundColor = story['background_color'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. CONTENU DE LA STORY
          Positioned.fill(child: _buildStoryContent(mediaType, mediaUrl, textContent, backgroundColor)),
          
          // 2. OVERLAY SOMBRE
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent, Colors.black.withOpacity(0.6)],
                ),
              ),
            ),
          ),

          // 3. HEADER (Barres de progression + Infos)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, left: 16, right: 16,
            child: Column(
              children: [
                Row(
                  children: List.generate(widget.stories.length, (index) {
                    final isActive = index == _currentIndex;
                    final isPast = index < _currentIndex;
                    return Expanded(
                      child: Container(
                        height: 2, margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: isPast ? 1.0 : (isActive ? _progress : 0.0),
                          child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18, backgroundColor: Colors.grey.shade800,
                      backgroundImage: widget.creatorAvatar != null ? NetworkImage(widget.creatorAvatar!) : null,
                      child: widget.creatorAvatar == null ? const Icon(Icons.person, size: 18, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(_getStoryTime(story['created_at']), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ],
            ),
          ),

          // 4. ZONE D'ACTION EN BAS (Like pour fan, Stats pour créateur)
          Positioned(
            bottom: 40, left: 16, right: 16,
            child: _isCreator
                ? GestureDetector(
                    onTap: _showInteractionsBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.visibility, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('$_viewCount vues • $_likeCount J\'aime', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: Icon(
                            _hasLiked ? Icons.favorite : Icons.favorite_border,
                            color: _hasLiked ? Colors.red : Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // 5. ✅ CORRECTION CRUCIALE : ZONES DE TAP (Gauche / Droite)
          // On utilise 'bottom: 100' pour NE PAS recouvrir le bouton Like/Stats en bas de l'écran !
          Positioned(
            left: 0,
            top: 0,
            bottom: 100, 
            width: MediaQuery.of(context).size.width / 2,
            child: GestureDetector(
              onTap: _goToPreviousStory,
              onLongPress: _onLongPress,
              onLongPressEnd: (_) => _onLongPressEnd(),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 100, 
            width: MediaQuery.of(context).size.width / 2,
            child: GestureDetector(
              onTap: _goToNextStory,
              onLongPress: _onLongPress,
              onLongPressEnd: (_) => _onLongPressEnd(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(String mediaType, String? mediaUrl, String? textContent, String? backgroundColor) {
    if (mediaType == 'text' && textContent != null) {
      return Container(
        color: backgroundColor != null ? Color(int.parse(backgroundColor.replaceAll('#', '0xFF'))) : const Color(0xFF8B5CF6),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(textContent, textAlign: TextAlign.center, style: TextStyle(color: _getTextColor(backgroundColor), fontSize: 26, fontWeight: FontWeight.bold, height: 1.4)),
        ),
      );
    } else if (mediaType == 'video' && mediaUrl != null) {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return Center(child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!)));
      } else {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
    } else if (mediaType == 'image' && mediaUrl != null) {
      return Image.network(mediaUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 60))));
    } else {
      return Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.error_outline, color: Colors.white54, size: 60)));
    }
  }

  String _getStoryTime(String? createdAt) {
    if (createdAt == null) return 'À l\'instant';
    try {
      final diff = DateTime.now().difference(DateTime.parse(createdAt));
      if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
      if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
      return 'À l\'instant';
    } catch (e) { return 'À l\'instant'; }
  }
}