import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../creator/creator_profile_screen.dart';
import '../../../widgets/tip_dialog.dart';
import '../../../widgets/report_dialog.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late String _currentUserId;
  late String _currentUserName;
  bool _isLiked = false;
  bool _isFollowed = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _heartAnimation = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _currentUserName = 'Utilisateur';
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final userProfile = await Supabase.instance.client
        .from('profiles')
        .select('username, full_name')
        .eq('id', _currentUserId)
        .maybeSingle();
    if (userProfile != null) {
      _currentUserName = userProfile['full_name'] ?? userProfile['username'] ?? 'Utilisateur';
    }

    if (_currentUserId.isNotEmpty) {
      final likeResponse = await Supabase.instance.client
          .from('post_likes')
          .select('id')
          .eq('post_id', widget.post['id'])
          .eq('user_id', _currentUserId)
          .maybeSingle();
      setState(() {
        _isLiked = likeResponse != null;
        _likesCount = widget.post['likes_count'] ?? 0;
        _commentsCount = widget.post['comments_count'] ?? 0;
      });

      final creatorId = widget.post['user_id']?.toString() ?? '';
      if (creatorId != _currentUserId) {
        final followResponse = await Supabase.instance.client
            .from('follows')
            .select('id')
            .eq('follower_id', _currentUserId)
            .eq('following_id', creatorId)
            .maybeSingle();
        setState(() {
          _isFollowed = followResponse != null;
        });
      }
    } else {
      setState(() {
        _likesCount = widget.post['likes_count'] ?? 0;
        _commentsCount = widget.post['comments_count'] ?? 0;
      });
    }
  }

  void _handleDoubleTap() {
    if (!_isLiked) _handleLike();
    setState(() => _heartAnimation = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _heartAnimation = false);
    });
  }

  Future<void> _handleLike() async {
    if (_currentUserId.isEmpty) return;
    final postId = widget.post['id'].toString();

    try {
      if (_isLiked) {
        _likesCount = (_likesCount > 0) ? _likesCount - 1 : 0;
        await Supabase.instance.client.from('post_likes').delete().eq('post_id', postId).eq('user_id', _currentUserId);
      } else {
        _likesCount++;
        await Supabase.instance.client.from('post_likes').insert({'post_id': postId, 'user_id': _currentUserId});
      }
      await Supabase.instance.client.from('posts').update({'likes_count': _likesCount}).eq('id', postId);
      if (mounted) setState(() => _isLiked = !_isLiked);
    } catch (e) {
      debugPrint('❌ Erreur Like: $e');
    }
  }

  Future<void> _handleFollow() async {
    if (_currentUserId.isEmpty) return;
    final creatorId = widget.post['user_id']?.toString() ?? '';
    if (creatorId == _currentUserId) return;

    try {
      if (_isFollowed) {
        await Supabase.instance.client.from('follows').delete().eq('follower_id', _currentUserId).eq('following_id', creatorId);
      } else {
        await Supabase.instance.client.from('follows').insert({'follower_id': _currentUserId, 'following_id': creatorId});
      }
      if (mounted) setState(() => _isFollowed = !_isFollowed);
    } catch (e) {
      debugPrint('❌ Erreur Follow: $e');
    }
  }

  void _openComments(bool isDark) {
    final TextEditingController commentController = TextEditingController();
    final postId = widget.post['id'].toString();

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
                  Text('Commentaires',
                      style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client.from('comments').select().eq('post_id', postId).order('created_at', ascending: true),
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
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
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
                          icon: Icon(Icons.send, color: accentColor),
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
                              _commentsCount++;
                              await Supabase.instance.client.from('posts').update({'comments_count': _commentsCount}).eq('id', postId);
                              commentController.clear();
                              setModalState(() {});
                              setState(() {});
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
    final post = widget.post;
    final mediaUrl = post['media_url'];
    final creatorId = post['user_id']?.toString() ?? '';
    final creatorName = post['profiles']?['full_name'] ?? 'Créateur';
    final caption = post['content'] ?? '';
    final avatarUrl = post['profiles']?['avatar_url'];

    // ✅ Accent : noir en clair / blanc en sombre
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. IMAGE DE FOND
            if (mediaUrl != null && mediaUrl.toString().isNotEmpty)
              Image.network(mediaUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)))
            else
              Container(color: Colors.grey.shade900),

            // 2. DÉGRADÉ POUR LISIBILITÉ (toujours sombre sur image)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),

            // 3. ANIMATION CŒUR
            if (_heartAnimation) const Center(child: Icon(Icons.favorite, color: Colors.redAccent, size: 120)),

            // 4. BOUTON FERMER (HAUT GAUCHE)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),

            // 5. BLOC GAUCHE BAS : CRÉATEUR + LÉGENDE
            Positioned(
              left: 16, right: 80, bottom: 20,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId)));
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(creatorName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (creatorId != _currentUserId && !_isFollowed)
                            GestureDetector(
                              onTap: _handleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  // ✅ Bouton adaptatif
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('Suivre',
                                    style: TextStyle(
                                      color: accentTextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    )),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(caption.isEmpty ? '(Pas de légende)' : caption,
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
                  ],
                ),
              ),
            ),

            // 6. BLOC DROITE BAS : BOUTONS D'ACTION
            Positioned(
              right: 12, bottom: 20,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId)));
                    },
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 26) : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSideButton(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    '$_likesCount',
                    _handleLike,
                    iconColor: _isLiked ? Colors.redAccent : Colors.white,
                  ),
                  const SizedBox(height: 20),
                  _buildSideButton(Icons.chat_bubble_rounded, '$_commentsCount', () => _openComments(isDark)),
                  const SizedBox(height: 20),
                  _buildSideButton(
                    Icons.local_cafe,
                    '',
                    () => showDialog(context: context, builder: (context) => TipDialog(creatorId: creatorId, creatorName: creatorName)),
                    iconColor: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 20),
                  _buildSideButton(Icons.share, '', () => Share.share('Regarde ce post de $creatorName sur Afrifan : $caption')),
                  const SizedBox(height: 20),
                  _buildSideButton(Icons.more_vert, '', () {
                    final menuBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
                    final textColor = isDark ? Colors.white : Colors.black87;
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: menuBg,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                            title: Text('Signaler ce post', style: TextStyle(color: textColor)),
                            onTap: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) => ReportDialog(targetId: post['id'].toString(), targetType: 'post'),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
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
            Icon(icon, color: iconColor, size: 34),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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