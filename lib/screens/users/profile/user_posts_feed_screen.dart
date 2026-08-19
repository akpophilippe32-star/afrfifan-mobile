import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart'; // 🔥 Pour le vrai partage sur WhatsApp, etc.

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    
    _isLikedList = List.generate(widget.posts.length, (index) => false);
    _isSavedList = List.generate(widget.posts.length, (index) => widget.posts[index]['is_saved'] == true);
    _likesCountList = List.generate(widget.posts.length, (index) => widget.posts[index]['likes_count'] ?? 0);
    _commentsCountList = List.generate(widget.posts.length, (index) => widget.posts[index]['comments_count'] ?? 0);

    _checkUserExistingLikes();
  }

  Future<void> _checkUserExistingLikes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    List<String> postIds = widget.posts.map((p) => p['id'].toString()).toList();

    try {
      final response = await _supabase
          .from('post_likes') // 🛠️ Remplacement par 'post_likes'
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---
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
        // 🛠️ Remplacement par 'post_likes'
        await _supabase.from('post_likes').insert({'post_id': postId, 'user_id': user.id});
      } else {
        // 🛠️ Remplacement par 'post_likes'
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
      // 🛠️ Remplacement par 'post_likes'
      await _supabase.from('post_likes').insert({'post_id': postId, 'user_id': user.id});
    } catch (e) {
      debugPrint("Erreur Double Tap Like : $e");
    }
  }

  // 🔥 FONCTION DE PARTAGE NATIF
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

  // 🔥 OUVERTURE PANNEAU DES COMMENTAIRES DYNAMIQUES
  void _openComments(BuildContext context, String postId, int index) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet au clavier de ne pas cacher le champ
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder( // Permet de rafraîchir le panneau des commentaires de manière isolée
          builder: (BuildContext context, StateSetter setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Commentaires (${_commentsCountList[index]})", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)
                    ),
                  ),
                  const Divider(height: 1),
                  
                  // Flux futur/réel des commentaires récupérés depuis Supabase
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: _supabase
                          .from('comments')
                          .select('id, content, created_at, profiles(username, avatar_url)')
                          .eq('post_id', postId)
                          .order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.purple));
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
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                  profile?['avatar_url'] ?? 'https://via.placeholder.com/150'
                                ),
                              ),
                              title: Text(
                                profile?['username'] ?? 'Anonyme', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)
                              ),
                              subtitle: Text(
                                comment['content'] ?? '', 
                                style: const TextStyle(color: Colors.black87, fontSize: 14)
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  const Divider(height: 1),
                  // Zone de saisie d'un nouveau commentaire
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16, 
                      left: 16, 
                      right: 16, 
                      top: 8
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: "Ajouter un commentaire...",
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.purple), 
                          onPressed: () async {
                            final user = _supabase.auth.currentUser;
                            if (user == null || commentController.text.trim().isEmpty) return;

                            try {
                              // Insertion du commentaire en BDD
                              await _supabase.from('comments').insert({
                                'post_id': postId,
                                'user_id': user.id,
                                'content': commentController.text.trim(),
                              });

                              commentController.clear();
                              
                              // On met à jour le compteur global et on force le rafraîchissement du modal
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
              final imageUrl = post['media_url'] ?? 'https://via.placeholder.com/600';
              final title = post['title'] ?? 'Pas de description';

              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onDoubleTap: () => _handleDoubleTap(index, postId),
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                  
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

                  // Infos Bas Gauche
                  Positioned(
                    left: 16,
                    bottom: 40,
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

                  // Boutons Droite
                  Positioned(
                    right: 16,
                    bottom: 60,
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
                          onTap: () {},
                        ),
                        const SizedBox(height: 20),
                        
                        _buildActionButton(
                          icon: Icons.reply, 
                          iconColor: Colors.white,
                          label: "Partager",
                          onTap: () => _sharePost(title, imageUrl), // 🔥 Action de partage active !
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Bouton Retour
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