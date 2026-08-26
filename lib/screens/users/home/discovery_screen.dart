import 'dart:ui'; // ✅ Pour l'effet de flou (ImageFilter)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../explore/explore_screen.dart';
import '../notifications/notifications_screen.dart';
import '../creator/creator_profile_screen.dart';
import '../creator/subscription_payment_screen.dart'; // ✅ Pour le paiement d'abonnement
import '../../../widgets/tip_dialog.dart'; // ✅ Pour le pourboire
import '../../../services/share_service.dart';
import '../../../widgets/report_dialog.dart'; // ✅ AJOUT : Pour le signalement
import 'watch_live_screen.dart'; // ✅ Ajouté pour accéder à l'écran du Live
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final PageController _horizontalPageController = PageController(initialPage: 1);
  int _selectedTab = 1; // 0 = Abonnés, 1 = Pour toi
  
  List<Map<String, dynamic>> _posts = [];
  final Set<String> _likedPostIds = {};
  final Set<String> _followedCreatorIds = {}; // Gratuit (Follow)
  final Set<String> _subscribedCreatorIds = {}; // Payant (Subscription)
  
  String? _currentUserId;
  String _currentUserName = 'Utilisateur';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchData();
  }

  @override
  void dispose() {
    _horizontalPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      debugPrint('⏳ [FETCH] Récupération des données...');
      final userId = _currentUserId;
      
      if (userId != null) {
        // 1. Récupérer le nom de l'utilisateur pour les commentaires
        final userProfile = await Supabase.instance.client
            .from('profiles')
            .select('username, full_name')
            .eq('id', userId)
            .maybeSingle();
        if (userProfile != null) {
          _currentUserName = userProfile['full_name'] ?? userProfile['username'] ?? 'Utilisateur';
        }

        // 2. Récupérer les follows (gratuit)
        final followsResponse = await Supabase.instance.client
            .from('follows')
            .select('following_id')
            .eq('follower_id', userId);
        _followedCreatorIds.clear();
        for (var row in followsResponse) {
          _followedCreatorIds.add(row['following_id'].toString());
        }

        // 3. ✅ NOUVEAU : Récupérer les abonnements PAYANTS (pour déverrouiller le contenu)
        final subsResponse = await Supabase.instance.client
            .from('subscriptions')
            .select('creator_id')
            .eq('fan_id', userId)
            .eq('status', 'active');
        _subscribedCreatorIds.clear();
        for (var sub in subsResponse) {
          _subscribedCreatorIds.add(sub['creator_id'].toString());
        }
      }

      // 4. Récupérer tous les posts
      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select('id, user_id, content, media_url, media_type, likes_count, comments_count, created_at')
          .order('created_at', ascending: false);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      if (posts.isEmpty) {
        if (!mounted) return;
        setState(() { _posts = []; _isLoading = false; });
        return;
      }

      // 5. Récupérer les profils des créateurs
      final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', userIds);
      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profiles) p['id'] as String: p};

      // 6. Récupérer les likes
      if (userId != null) {
        final postIds = posts.map((p) => p['id'] as String).toList();
        final likesResponse = await Supabase.instance.client
            .from('post_likes')
            .select('post_id')
            .inFilter('post_id', postIds)
            .eq('user_id', userId);
        _likedPostIds.clear();
        for (var row in likesResponse) {
          _likedPostIds.add(row['post_id'].toString());
        }
      }

      // 7. Fusionner posts + profils
      final finalPosts = posts.map((post) {
        final creatorId = post['user_id'] as String;
        return {...post, 'profiles': profilesMap[creatorId]};
      }).toList();

      if (!mounted) return;
      setState(() {
        _posts = finalPosts;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ [ERROR] Erreur lors du chargement : $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLike(String postId, int currentLikes, int postIndex, List<Map<String, dynamic>> postsList) async {
    final userId = _currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour liker'), backgroundColor: Colors.orange),
      );
      return;
    }

    final bool isAlreadyLiked = _likedPostIds.contains(postId);
    try {
      int newLikes = currentLikes;
      if (isAlreadyLiked) {
        newLikes = (currentLikes > 0) ? currentLikes - 1 : 0;
        await Supabase.instance.client.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
        _likedPostIds.remove(postId);
      } else {
        newLikes = currentLikes + 1;
        await Supabase.instance.client.from('post_likes').insert({'post_id': postId, 'user_id': userId});
        _likedPostIds.add(postId);
      }
      await Supabase.instance.client.from('posts').update({'likes_count': newLikes}).eq('id', postId);

      if (!mounted) return;
      setState(() {
        final realIndex = _posts.indexWhere((p) => p['id'].toString() == postId);
        if (realIndex != -1) _posts[realIndex]['likes_count'] = newLikes;
      });
    } catch (e) {
      debugPrint('❌ [ERROR] Erreur Like : $e');
    }
  }

  Future<void> _handleFollow(String creatorId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final bool isAlreadyFollowed = _followedCreatorIds.contains(creatorId);
    try {
      if (isAlreadyFollowed) {
        await Supabase.instance.client.from('follows').delete().eq('follower_id', userId).eq('following_id', creatorId);
        _followedCreatorIds.remove(creatorId);
      } else {
        await Supabase.instance.client.from('follows').insert({'follower_id': userId, 'following_id': creatorId});
        _followedCreatorIds.add(creatorId);
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('❌ [ERROR] Erreur Follow : $e');
    }
  }

  // ✅ OUVRIR LE DIALOG DE POURBOIRE
  void _openTipDialog(BuildContext context, String creatorId, String creatorName) {
    showDialog(
      context: context,
      builder: (context) => TipDialog(
        creatorId: creatorId,
        creatorName: creatorName,
      ),
    );
  }

  // ✅ OUVRIR L'ÉCRAN DE PAIEMENT SI LE CONTENU EST VERROUILLÉ
  void _openSubscriptionPayment(BuildContext context, String creatorId, String creatorName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPaymentScreen(
          creatorId: creatorId,
          creatorName: creatorName,
          tierType: 'premium', // Par défaut, on propose l'abonnement standard
          price: 2000.0, // À adapter selon tes prix réels
        ),
      ),
    ).then((success) {
      if (success == true) {
        _fetchData(); // Recharger pour déverrouiller le contenu
      }
    });
  }

  void _openComments(BuildContext context, String postId) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Commentaires', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client.from('comments').select().eq('post_id', postId).order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Aucun commentaire', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
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
                              await Supabase.instance.client.from('comments').insert({
                                'post_id': postId,
                                'content': text,
                                'user_name': _currentUserName, // ✅ CORRECTION : Utilise le vrai nom de l'utilisateur
                              });

                              final int totalComments = await Supabase.instance.client.from('comments').count(CountOption.exact).eq('post_id', postId);
                              await Supabase.instance.client.from('posts').update({'comments_count': totalComments}).eq('id', postId);

                              setModalState(() {});
                              setState(() {
                                final postIndex = _posts.indexWhere((p) => p['id'].toString() == postId);
                                if (postIndex != -1) _posts[postIndex]['comments_count'] = totalComments;
                              });
                            } catch (e) {
                              debugPrint('❌ [ERROR] Erreur commentaire : $e');
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

  void _handleShare(Map<String, dynamic> post) {
    final creatorName = post['profiles']?['full_name'] ?? 'Créateur';
    final caption = post['content'] ?? '';
    final postId = post['id'].toString();
    // shareService.shareFreePost(postId: postId, creatorName: creatorName, caption: caption, imageUrl: post['media_url']);
  }
  // ✅ NOUVEAU : Méthode pour rejoindre un Live dynamiquement
    // ✅ NOUVEAU : Méthode pour rejoindre un Live dynamiquement (CORRIGÉE)
  // ✅ NOUVEAU : Méthode pour rejoindre un Live dynamiquement (BLINDÉE CONTRE LES DOUBLONS)
  Future<void> _joinLive() async {
    try {
      // 1. Chercher s'il y a au moins un live en cours
      final lives = await Supabase.instance.client
          .from('live_streams')
          .select('id, creator_id, title')
          .eq('status', 'live')
          .limit(1);

      if (lives.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🔴 Aucun live en cours pour le moment. Reviens plus tard !'),
            backgroundColor: const Color(0xFF424242),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final live = lives[0];
      final creatorId = live['creator_id'] as String;

      // 2. Récupérer le profil (Sécurisé : on prend juste le premier si doublon)
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name, avatar_url')
          .eq('id', creatorId)
          .limit(1);
      
      final profile = profiles.isNotEmpty ? profiles[0] : null;
      final creatorName = profile != null 
          ? (profile['full_name'] ?? profile['username'] ?? 'Créateur') 
          : 'Créateur';
      final creatorAvatar = profile != null ? profile['avatar_url'] : null;

      // 3. Vérifier l'abonnement (Sécurisé : on prend juste le premier si doublon)
      bool isSubscribed = false;
      if (_currentUserId != null) {
        final subs = await Supabase.instance.client
            .from('subscriptions')
            .select('id')
            .eq('fan_id', _currentUserId!)
            .eq('creator_id', creatorId)
            .eq('status', 'active')
            .limit(1);
        
        isSubscribed = subs.isNotEmpty;
      }

      // 4. Ouvrir l'écran du Live
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WatchLiveScreen(
            liveId: live['id'],
            creatorName: creatorName,
            creatorAvatar: creatorAvatar,
            isSubscribed: isSubscribed,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de la recherche de live : $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de connexion au live'), backgroundColor: Colors.red),
      );
    }
  }
  Widget _buildPostsPageView(List<Map<String, dynamic>> postsList) {
    if (postsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_collection_outlined, size: 60, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 0 ? 'Aucune publication de vos abonnements' : 'Aucune publication pour le moment',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: postsList.length,
      itemBuilder: (context, index) {
        final post = postsList[index];
        final postId = post['id']?.toString() ?? '';
        final caption = post['content'] ?? '';
        final mediaUrl = post['media_url'];
        final creatorId = post['user_id']?.toString() ?? '';
        final creatorName = post['profiles']?['full_name'] ?? 'Créateur';
        final likesCount = post['likes_count']?.toString() ?? '0';
        final commentsCount = post['comments_count']?.toString() ?? '0';

        final bool isLiked = _likedPostIds.contains(postId);
        final bool isFollowed = _followedCreatorIds.contains(creatorId);

        // ✅ LOGIQUE DE VERROUILLAGE (Exactement comme dans creator_profile_screen)
        final bool isMyOwnPost = (_currentUserId == creatorId);
        // Verrouillé si ce n'est pas mon post ET que je ne suis pas abonné (payant) à ce créateur
        final bool isLocked = !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 🖼️ IMAGE DE FOND (Avec flou si verrouillé)
            if (mediaUrl != null && mediaUrl.toString().isNotEmpty)
              isLocked
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54))),
                    )
                  : Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)))
            else
              Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.white54))),

            // 🌫️ DÉGRADÉ POUR LA LISIBILITÉ
                        // 🌫️ DÉGRADÉ POUR LA LISIBILITÉ
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),

            // ⋮ MENU 3 POINTS (En haut à droite du post)
            Positioned(
              top: 16,
              right: 16,
              child: PopupMenuButton<String>(
                color: const Color(0xFF1A1A1A), // Fond sombre du menu
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                onSelected: (value) {
                  if (value == 'report') {
                    showDialog(
                      context: context,
                      builder: (context) => ReportDialog(
                        targetId: postId,
                        targetType: 'post',
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text('Signaler ce post', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 👁️ OVERLAY DE VERROUILLAGE (Si isLocked est true)
            if (isLocked)
              // ... (le reste de ton code ne change pas)

            // 👁️ OVERLAY DE VERROUILLAGE (Si isLocked est true)
            if (isLocked)
              GestureDetector(
                onTap: () => _openSubscriptionPayment(context, creatorId, creatorName),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.visibility_off, color: Colors.white, size: 32), // Œil barré
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Contenu réservé aux abonnés',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cliquez ici pour vous abonner',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 👤 BLOC GAUCHE : CRÉATEUR + LÉGENDE
            Positioned(
              left: 16, right: 80, bottom: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: creatorId))),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18, backgroundColor: Colors.grey.shade800,
                          backgroundImage: post['profiles']?['avatar_url'] != null ? NetworkImage(post['profiles']!['avatar_url']) : null,
                          child: post['profiles']?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (!isFollowed)
                          GestureDetector(
                            onTap: () => _handleFollow(creatorId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                              child: const Text('Suivre', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: Text(
                      caption.isEmpty ? '📝 (Pas de légende)' : caption,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14, height: 1.4, shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))]),
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 🎯 BLOC DROITE : BOUTONS D'ACTION
            Positioned(
              right: 12, bottom: 100,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _handleFollow(creatorId),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        CircleAvatar(
                          radius: 22, backgroundColor: Colors.grey.shade800,
                          backgroundImage: post['profiles']?['avatar_url'] != null ? NetworkImage(post['profiles']!['avatar_url']) : null,
                          child: post['profiles']?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        if (!isFollowed)
                          Positioned(
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.add, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSideButton(isLiked ? Icons.favorite : Icons.favorite_border, likesCount, () => _handleLike(postId, int.tryParse(likesCount) ?? 0, index, postsList), iconColor: isLiked ? Colors.redAccent : Colors.white),
                  const SizedBox(height: 18),
                  _buildSideButton(Icons.chat_bubble_rounded, commentsCount, () => _openComments(context, postId)),
                  const SizedBox(height: 18),
                  
                  // ✅ NOUVEAU : BOUTON POURBOIRE (TIP)
                  _buildSideButton(Icons.local_cafe, '', () => _openTipDialog(context, creatorId, creatorName), iconColor: Colors.orangeAccent),
                  
                  const SizedBox(height: 18),
                  _buildSideButton(Icons.share, '', () => _handleShare(post)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final followedPosts = _posts.where((post) {
      final creatorId = post['user_id']?.toString() ?? '';
      return _followedCreatorIds.contains(creatorId);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                PageView(
                  controller: _horizontalPageController,
                  onPageChanged: (index) {
                    setState(() { _selectedTab = index; });
                  },
                  children: [
                    _buildPostsPageView(followedPosts), // Page 0 : Abonnés (Follows)
                    _buildPostsPageView(_posts),        // Page 1 : Pour toi (Tous les posts)
                  ],
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16, right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
// ✅ BOUTON LIVE (Remplace le panier)
// ✅ BOUTON LIVE DYNAMIQUE
GestureDetector(
  onTap: _joinLive, // <-- Appelle directement la méthode qu'on vient de créer
  child: const Row(
    children: [
      Icon(Icons.videocam, color: Colors.redAccent, size: 28),
      SizedBox(width: 6),
      Text(
        'LIVE',
        style: TextStyle(
          color: Colors.redAccent, 
          fontWeight: FontWeight.bold, 
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    ],
  ),
),                     Row(
                        children: [
                          _buildTopTab('Abonnés', 0),
                          const SizedBox(width: 20),
                          _buildTopTab('Pour toi', 1),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExploreScreen())),
                            child: const Icon(Icons.search, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                            child: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopTab(String title, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        _horizontalPageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
          const SizedBox(height: 4),
          if (isSelected) Container(height: 3, width: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
        ],
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