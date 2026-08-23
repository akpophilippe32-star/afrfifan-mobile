import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/tip_dialog.dart';
import '../../../widgets/report_dialog.dart';

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
  Set<String> _likedPostIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentUserId = supabase.auth.currentUser?.id;
    _loadLikes();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadLikes() async {
    final userId = _currentUserId;
    if (userId == null) return;
    final postIds = widget.posts.map((p) => p['id'].toString()).toList();
    final likesResponse = await supabase.from('post_likes').select('post_id').inFilter('post_id', postIds).eq('user_id', userId);
    if (mounted) {
      setState(() {
        _likedPostIds = likesResponse.map((row) => row['post_id'].toString()).toSet();
      });
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
        if (postIndex < widget.posts.length) widget.posts[postIndex]['likes_count'] = newLikes;
      });
    } catch (e) { debugPrint('❌ Erreur like: $e'); }
  }
  void _openComments(String postId, int currentComments, int postIndex) {
    final TextEditingController commentController = TextEditingController();
    final userId = _currentUserId;
    final currentUserName = 'Utilisateur'; // Tu pourras récupérer le vrai nom si besoin, ou le laisser ainsi pour l'instant

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
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.purple));
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
                          icon: const Icon(Icons.send, color: Colors.purple, size: 24),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            commentController.clear();
                            try {
                              await supabase.from('comments').insert({'post_id': postId, 'content': text, 'user_name': userId != null ? currentUserName : 'Utilisateur'});
                              final totalComments = await supabase.from('comments').count(CountOption.exact).eq('post_id', postId);
                              await supabase.from('posts').update({'comments_count': totalComments}).eq('id', postId);
                              setModalState(() {});
                              // Mettre à jour localement dans la liste
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
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
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
          final caption = post['caption'] ?? post['title'] ?? '';
          final mediaUrl = post['media_url'];
          final creatorName = post['profiles']?['username'] ?? 'Créateur';
          final likesCount = post['likes_count'] ?? 0;
          final isLiked = _likedPostIds.contains(postId);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. IMAGE/VIDÉO
              if (mediaUrl != null && mediaUrl.toString().isNotEmpty)
                Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)))
              else
                Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54))),

              // 2. DÉGRADÉ ÉCLAIRCI
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),

              // 3. BOUTON RETOUR
              Positioned(
                top: 40, left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),

              // 4. BOUTONS VERTICAUX À DROITE
              Positioned(
                right: 12, bottom: 100,
                child: Column(
                  children: [
                    _buildSideButton(isLiked ? Icons.favorite : Icons.favorite_border, _formatCount(likesCount), () => _handleLike(postId, likesCount, index), iconColor: isLiked ? Colors.redAccent : Colors.white),
                    const SizedBox(height: 18),
                                      _buildSideButton(Icons.chat_bubble_rounded, _formatCount(post['comments_count'] ?? 0), () {
                      _openComments(postId, post['comments_count'] ?? 0, index); // ✅ Maintenant ça appelle ta super fonction !
                    }),
                    const SizedBox(height: 18),
                    _buildSideButton(Icons.local_cafe, 'Tip', () {
                      showDialog(context: context, builder: (context) => TipDialog(creatorId: post['user_id'].toString(), creatorName: creatorName));
                    }, iconColor: Colors.orangeAccent),
                    const SizedBox(height: 18),
                    _buildSideButton(Icons.share, 'Partager', () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié !'), backgroundColor: Colors.green));
                    }, iconColor: Colors.white),
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
                        const PopupMenuItem<String>(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text('Signaler', style: TextStyle(color: Colors.white))])),
                      ],
                    ),
                  ],
                ),
              ),

              // 5. INFOS EN BAS À GAUCHE
              Positioned(
                left: 16, right: 80, bottom: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@$creatorName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text(caption.isEmpty ? '📝 (Pas de légende)' : caption, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                  ],
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
            if (label.isNotEmpty) ...[const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))],
          ],
        ),
      ),
    );
  }
}