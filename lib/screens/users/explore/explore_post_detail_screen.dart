import 'dart:ui'; // Pour l'effet de flou
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart'; // ✅ Pour le vrai partage
import '../../../theme/app_colors.dart';
import '../../../widgets/tip_dialog.dart';
import '../../../widgets/report_dialog.dart';
import '../creator/creator_profile_screen.dart'; // ✅ Pour aller au profil
import '../creator/subscription_payment_screen.dart'; // ✅ Pour le déverrouillage

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
  Set<String> _subscribedCreatorIds = {}; // ✅ Pour gérer le verrouillage

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
    super.dispose();
  }

  // ✅ Charge le nom, l'avatar de l'utilisateur et ses abonnements
  Future<void> _loadUserData() async {
    if (_currentUserId == null) return;

    try {
      // 1. Infos utilisateur pour les commentaires
      final userProfile = await supabase
          .from('profiles')
          .select('username, full_name, avatar_url')
          .eq('id', _currentUserId!)
          .maybeSingle();
      
      if (userProfile != null) {
        _currentUserName = userProfile['full_name'] ?? userProfile['username'] ?? 'Utilisateur';
        _currentUserAvatar = userProfile['avatar_url'];
      }

      // 2. Abonnements actifs (pour déverrouiller)
      final subsResponse = await supabase
          .from('subscriptions')
          .select('creator_id')
          .eq('fan_id', _currentUserId!)
          .eq('status', 'active');
      
      if (mounted) {
        setState(() {
          _subscribedCreatorIds = subsResponse.map<String>((row) => row['creator_id'] as String).toSet();
        });
      }

      // 3. Likes déjà donnés
      final postIds = widget.posts.map((p) => p['id'].toString()).toList();
      final likesResponse = await supabase
          .from('post_likes')
          .select('post_id')
          .inFilter('post_id', postIds)
          .eq('user_id', _currentUserId!);
      
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

  // ✅ COMMENTAIRES EN MODE SOMBRE (Identique à Home)
  void _openComments(String postId, int postIndex) {
    final TextEditingController commentController = TextEditingController();

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
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade800)),
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
                              fillColor: Colors.black, // ✅ Fond noir garanti
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primary, size: 24),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            commentController.clear();
                            try {
                              await supabase.from('comments').insert({
                                'post_id': postId, 
                                'user_id': _currentUserId,
                                'user_name': _currentUserName, // ✅ Vrai nom de l'utilisateur
                                'content': text
                              });
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
          final creatorId = post['user_id']?.toString() ?? '';
          final caption = post['content'] ?? post['caption'] ?? post['title'] ?? '';
          final mediaUrl = post['media_url'];
          final creatorName = post['profiles']?['username'] ?? 'Créateur';
          final creatorAvatar = post['profiles']?['avatar_url'];
          final likesCount = post['likes_count'] ?? 0;
          final commentsCount = post['comments_count'] ?? 0;
          final isLiked = _likedPostIds.contains(postId);

          // ✅ LOGIQUE DE VERROUILLAGE
          final bool isMyOwnPost = (_currentUserId == creatorId);
          final bool isLocked = !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. IMAGE/VIDÉO (Avec flou si verrouillé)
              if (mediaUrl != null && mediaUrl.toString().isNotEmpty)
                isLocked
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54))),
                      )
                    : Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)))
              else
                Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54))),

              // 2. DÉGRADÉ
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),

              // 3. OVERLAY DE VERROUILLAGE (Cliquable pour payer)
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
                      if (success == true) {
                        // Recharger les données pour déverrouiller
                        _loadUserData();
                      }
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.lock, color: Colors.white, size: 32),
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

              // 4. BOUTON RETOUR
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

              // 5. BOUTONS VERTICAUX À DROITE (Désactivés si verrouillé)
              if (!isLocked)
                Positioned(
                  right: 12, bottom: 100,
                  child: Column(
                    children: [
                      _buildSideButton(isLiked ? Icons.favorite : Icons.favorite_border, _formatCount(likesCount), () => _handleLike(postId, likesCount, index), iconColor: isLiked ? Colors.redAccent : Colors.white),
                      const SizedBox(height: 18),
                      _buildSideButton(Icons.chat_bubble_rounded, _formatCount(commentsCount), () => _openComments(postId, index)),
                      const SizedBox(height: 18),
                      _buildSideButton(Icons.local_cafe, 'Tip', () {
                        showDialog(context: context, builder: (context) => TipDialog(creatorId: creatorId, creatorName: creatorName));
                      }, iconColor: Colors.orangeAccent),
                      const SizedBox(height: 18),
                      _buildSideButton(Icons.share, 'Partager', () {
                        // ✅ VRAI PARTAGE NATIF
                        Share.share('Regarde ce post de @$creatorName sur Afrifan : $caption');
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

              // 6. INFOS EN BAS À GAUCHE (Avec Photo et Lien vers le Profil)
              Positioned(
                left: 16, right: 80, bottom: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId)),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: creatorAvatar != null ? NetworkImage(creatorAvatar) : null,
                            child: creatorAvatar == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                          ),
                          const SizedBox(width: 10),
                          Text('@$creatorName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(caption.isEmpty ? '📝 (Pas de légende)' : caption, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))])),
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