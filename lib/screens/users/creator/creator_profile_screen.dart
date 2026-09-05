import 'dart:ui'; // ✅ Pour le flou (blur)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/messaging_service.dart';
import '../../../services/notification_service.dart';
import '../../../theme/app_colors.dart';
import '../messages/chat_screen.dart';
import 'post_detail_screen.dart';
import 'subscription_payment_screen.dart';
import '../../../widgets/tip_dialog.dart';
import '../../../widgets/report_dialog.dart';
import '../profile/view_story_screen.dart'; 
import '../profile/profile_screen.dart'; 

class CreatorProfileScreen extends StatefulWidget {
  final String creatorId;

  const CreatorProfileScreen({super.key, required this.creatorId});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final supabase = Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();
  final NotificationService _notificationService = NotificationService();

  Map<String, dynamic>? _creator;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _postsCount = 0;
  int _selectedTab = 0;

  List<Map<String, dynamic>> _stories = [];
  bool _hasActiveStories = false;

  Map<String, dynamic>? _currentSubscription;
  int _daysRemaining = 0;

  bool get _isSubscribed => _currentSubscription != null;
  bool get _isProSubscriber => _currentSubscription?['tier_type'] == 'pro';
  bool get _isPremiumSubscriber => _currentSubscription?['tier_type'] == 'premium';

  final Color brandViolet = const Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRedirectIfOwnProfile();
    });
  }

  void _checkAndRedirectIfOwnProfile() {
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && currentUser.id == widget.creatorId) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      _loadCreatorData();
    }
  }

  Future<void> _loadCreatorData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadCreatorProfile(),
        _loadCreatorPosts(),
        _checkIfFollowing(),
        _loadFollowersCount(),
        _checkSubscriptionStatus(),
        _loadCreatorStories(), 
      ]);
    } catch (e) {
      debugPrint('❌ Erreur chargement données créateur: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCreatorStories() async {
    try {
      final response = await supabase
          .from('stories')
          .select('id, media_url, media_type, text_content, background_color, created_at')
          .eq('creator_id', widget.creatorId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _stories = List<Map<String, dynamic>>.from(response ?? []);
          _hasActiveStories = _stories.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement stories: $e');
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final response = await supabase
          .from('subscriptions')
          .select('*') 
          .eq('fan_id', currentUser.id)
          .eq('creator_id', widget.creatorId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle(); 

      if (mounted && response != null) {
        setState(() {
          _currentSubscription = response;
          DateTime endDate = DateTime.parse(response['end_date']);
          _daysRemaining = endDate.difference(DateTime.now()).inDays;
          if (_daysRemaining < 0) _daysRemaining = 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur vérif abonnement: $e');
    }
  }

  Future<void> _loadCreatorProfile() async {
    try {
      final response = await supabase
          .from('profiles')
          // ✅ NOUVELLE LOGIQUE : On récupère is_creator pour savoir comment se comporter
          .select('id, username, full_name, avatar_url, bio, is_verified, is_creator, premium_price, pro_price')
          .eq('id', widget.creatorId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _creator = response != null ? Map<String, dynamic>.from(response) : null;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur loadCreatorProfile: $e');
    }
  }

  Future<void> _loadCreatorPosts() async {
    try {
      final response = await supabase
          .from('posts')
          // ✅ NOUVELLE LOGIQUE : On récupère is_premium pour savoir quels posts flouter
          .select('id, media_url, media_type, caption, title, is_premium, created_at, likes_count, comments_count')
          .eq('user_id', widget.creatorId)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(response);
          _postsCount = _posts.length;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur loadCreatorPosts: $e');
    }
  }

  Future<void> _checkIfFollowing() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    try {
      final response = await supabase
          .from('follows')
          .select('follower_id')
          .eq('follower_id', currentUser.id)
          .eq('following_id', widget.creatorId)
          .maybeSingle();

      if (mounted) setState(() => _isFollowing = response != null);
    } catch (e) {
      debugPrint('❌ Erreur checkIfFollowing: $e');
    }
  }

  Future<void> _loadFollowersCount() async {
    try {
      final response = await supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', widget.creatorId);

      if (mounted) setState(() => _followersCount = List.from(response).length);
    } catch (e) {
      debugPrint(' Erreur loadFollowersCount: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour suivre.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (_isFollowing) {
        await supabase.from('follows').delete().match({'follower_id': currentUser.id, 'following_id': widget.creatorId});
        if (mounted) setState(() { _isFollowing = false; _followersCount--; });
      } else {
        await supabase.from('follows').insert({'follower_id': currentUser.id, 'following_id': widget.creatorId});
        await _notificationService.sendNewFollowerNotification(followerId: currentUser.id, followedUserId: widget.creatorId);
        if (mounted) setState(() { _isFollowing = true; _followersCount++; });
      }
    } catch (e) {
      debugPrint('❌ Erreur toggleFollow: $e');
    }
  }

  // ✅ NOUVELLE LOGIQUE : Gestion intelligente des messages
  void _openChat() {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour envoyer un message'), backgroundColor: Colors.red),
      );
      return;
    }

    final bool isCreator = _creator?['is_creator'] == true;

    // Si c'est un créateur ET que l'utilisateur n'est pas abonné PRO
    if (isCreator && !_isProSubscriber) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Text('Contenu Réservé', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'Les messages privés avec ce créateur sont réservés aux abonnés PRO. Mettez à niveau votre abonnement pour débloquer cette fonctionnalité.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Redirige vers l'écran de paiement pour le niveau PRO
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubscriptionPaymentScreen(
                      creatorId: widget.creatorId,
                      creatorName: _creator?['full_name'] ?? _creator?['username'] ?? 'Créateur',
                      tierType: 'pro',
                      price: (_creator?['pro_price'] ?? 0).toDouble(),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: brandViolet),
              child: const Text('Devenir Abonné PRO', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return; // On arrête ici, on n'ouvre pas le chat
    }

    // Si ce n'est pas un créateur, OU si l'utilisateur est abonné PRO : on ouvre le chat normalement
    final creatorName = (_creator?['username'] ?? _creator?['full_name'] ?? 'Utilisateur').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: widget.creatorId,
          otherUserName: creatorName,
          otherUserAvatar: _creator?['avatar_url']?.toString(),
        ),
      ),
    );
  }

  void _openStoriesViewer() {
    if (_stories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewStoryScreen(
          stories: _stories,
          creatorName: _creator?['full_name'] ?? _creator?['username'] ?? 'Créateur',
          creatorId: widget.creatorId, 
          creatorAvatar: _creator?['avatar_url'],
        ),
      ),
    );
  }

  void _openPostDetail(int index) {
    final bool isCreator = _creator?['is_creator'] == true;
    final bool isPostPremium = _posts[index]['is_premium'] == true;
    
    // ✅ NOUVELLE LOGIQUE : On ne bloque que si c'est un créateur ET que le post est premium ET qu'on n'est pas abonné
    final bool isLocked = isCreator && isPostPremium && !_isSubscribed;

    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abonnez-vous pour voir ce contenu exclusif'), backgroundColor: Color(0xFF8B5CF6)),
      );
      return;
    }
    
    final creatorName = _creator?['full_name'] ?? _creator?['username'] ?? 'Créateur';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          posts: _posts,
          initialIndex: index,
          creatorId: widget.creatorId,
          creatorName: creatorName,
        ),
      ),
    ).then((success) {
      if (success == true) _loadCreatorData();
    });
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bool isVerifiedCreator = _creator?['is_verified'] == true;
    final bool isCreator = _creator?['is_creator'] == true; // ✅ Variable clé
    final double premiumPrice = (_creator?['premium_price'] ?? 0).toDouble();
    final double proPrice = (_creator?['pro_price'] ?? 0).toDouble();
    final bool hasPrices = premiumPrice > 0 || proPrice > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _creator == null
              ? const Center(child: Text('Profil introuvable', style: TextStyle(color: Colors.white)))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 120,
                      pinned: true,
                      backgroundColor: Colors.black,
                      leading: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                        PopupMenuButton<String>(
                          color: const Color(0xFF1A1A1A),
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                          onSelected: (value) {
                            if (value == 'report') {
                              showDialog(
                                context: context,
                                builder: (context) => ReportDialog(
                                  targetId: widget.creatorId,
                                  targetType: 'profile',
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
                                  Text('Signaler ce profil', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF2d1b69)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: _hasActiveStories ? _openStoriesViewer : null,
                                      child: Container(
                                        padding: _hasActiveStories ? const EdgeInsets.all(3) : EdgeInsets.zero,
                                        decoration: _hasActiveStories
                                            ? const BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                                              )
                                            : null,
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Colors.grey.shade800,
                                          backgroundImage: _creator?['avatar_url'] != null 
                                              ? NetworkImage(_creator!['avatar_url'].toString()) 
                                              : null,
                                          child: _creator?['avatar_url'] == null 
                                              ? const Icon(Icons.person, color: Colors.white, size: 50) 
                                              : null,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 5, right: 5,
                                      child: Container(
                                        width: 16, height: 16,
                                        decoration: BoxDecoration(
                                          color: Colors.green, 
                                          shape: BoxShape.circle, 
                                          border: Border.all(color: Colors.black, width: 2)
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              (_creator?['full_name'] ?? _creator?['username'] ?? 'Utilisateur').toString(),
                                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isVerifiedCreator) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.verified, color: Color(0xFF8B5CF6), size: 22),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text('@${_creator?['username'] ?? 'utilisateur'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: _toggleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing ? Colors.grey.shade800 : brandViolet,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    child: Text(_isFollowing ? 'Suivi' : 'Suivre'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => TipDialog(
                                          creatorId: widget.creatorId,
                                          creatorName: _creator?['full_name'] ?? _creator?['username'] ?? 'Utilisateur',
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.local_cafe, size: 18),
                                    label: const Text('Tip'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: brandViolet,
                                      side: BorderSide(color: brandViolet),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // ✅ NOUVELLE LOGIQUE : Le bouton de message s'adapte au statut
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openChat, // La logique de blocage est DANS la fonction _openChat
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: isCreator && !_isProSubscriber ? Colors.orange : Colors.grey.shade700),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                icon: Icon(
                                  isCreator && !_isProSubscriber ? Icons.lock_outline : Icons.message_outlined, 
                                  size: 18
                                ),
                                label: Text(
                                  isCreator && !_isProSubscriber ? 'Message (Nécessite PRO)' : 'Message privé',
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            if (_creator?['bio'] != null && _creator!['bio'].toString().isNotEmpty)
                              Text(_creator!['bio'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(Icons.group, _formatCount(_followersCount), 'Abonnés'),
                                Container(width: 1, height: 40, color: Colors.grey.shade800),
                                _buildStatItem(Icons.grid_view, _formatCount(_postsCount), 'Posts'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // ✅ NOUVELLE LOGIQUE : On n'affiche les cartes d'abonnement QUE si c'est un créateur avec des prix
                            if (isCreator && hasPrices) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Abonnements', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 280,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    if (premiumPrice > 0)
                                      _buildMembershipCard(
                                        'PREMIUM', 'Fan', premiumPrice, 
                                        ['Accès à tous les posts', 'Accès aux lives', 'Contenu exclusif'], 
                                        isPro: false, currentTier: _currentSubscription?['tier_type'], daysRemaining: _daysRemaining,
                                      ),
                                    if (premiumPrice > 0 && proPrice > 0) const SizedBox(width: 16),
                                    if (proPrice > 0)
                                      _buildMembershipCard(
                                        'PRO', 'Membre VIP', proPrice, 
                                        ['Tout le contenu Premium', 'Vidéos exclusives', 'Messages privés', 'Appels vidéo/audio'], 
                                        isPro: true, currentTier: _currentSubscription?['tier_type'], daysRemaining: _daysRemaining,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            Row(
                              children: [
                                _buildTab('POSTS', 0),
                                const SizedBox(width: 24),
                                _buildTab('EXCLUSIFS', 1),
                                const SizedBox(width: 24),
                                _buildTab('À PROPOS', 2),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    _posts.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucune publication pour le moment', style: TextStyle(color: Colors.grey)))),
                          )
                        : SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final post = _posts[index];
                                final mediaUrl = post['media_url']?.toString();
                                final mediaType = post['media_type']?.toString() ?? 'image';
                                final likesCount = post['likes_count'] ?? 0;
                                final title = post['title'] ?? post['caption'] ?? '';

                                // ✅ NOUVELLE LOGIQUE ULTIME : 
                                // On floute SEULEMENT si : C'est un créateur ET le post est premium ET l'utilisateur n'est pas abonné
                                final bool isLocked = isCreator && (post['is_premium'] == true) && !_isSubscribed;

                                return GestureDetector(
                                  onTap: () => _openPostDetail(index),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      color: Colors.grey.shade900,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (mediaUrl != null)
                                            isLocked
                                                ? ImageFiltered(
                                                    imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                                    child: Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                                                  )
                                                : Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                                          
                                          if (isLocked)
                                            Container(
                                              color: Colors.black.withOpacity(0.4),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                                                      child: const Icon(Icons.lock, color: Colors.white, size: 24),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text('Contenu Exclusif', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 0, left: 0, right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (title.isNotEmpty) Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 4),
                                                  Text('❤️ ${_formatCount(likesCount)}', style: TextStyle(color: brandViolet, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (mediaType == 'video' && !isLocked)
                                            Positioned(
                                              top: 8, right: 8,
                                              child: Container(
                                                width: 24, height: 24,
                                                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                                child: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: _posts.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
                          ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: brandViolet, size: 18),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ],
    );
  }

  Widget _buildMembershipCard(
    String badge, String title, double price, List<String> features, 
    {required bool isPro, required String? currentTier, required int daysRemaining}
  ) {
    bool isCurrentTier = currentTier == (isPro ? 'pro' : 'premium');
    bool isDowngradeBlocked = currentTier == 'pro' && !isPro;

    String buttonText = 'Rejoindre';
    bool isButtonEnabled = true;
    Color buttonColor = isPro ? Colors.white : brandViolet;
    Color textColor = isPro ? brandViolet : Colors.white;

    if (isCurrentTier) {
      buttonText = 'Déjà abonné ($daysRemaining j.)';
      isButtonEnabled = false;
      buttonColor = Colors.grey.shade800;
      textColor = Colors.grey.shade400;
    } else if (isDowngradeBlocked) {
      buttonText = 'Disponible après période Pro';
      isButtonEnabled = false;
      buttonColor = Colors.grey.shade800;
      textColor = Colors.grey.shade400;
    } else if (currentTier != null && !isPro) {
      buttonText = 'Passer à Pro';
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isPro 
            ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF1A1A1A)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPro ? const Color(0xFF8B5CF6) : Colors.grey.shade800, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPro ? Colors.white.withOpacity(0.2) : const Color(0xFF8B5CF6).withOpacity(0.2), 
              borderRadius: BorderRadius.circular(8)
            ),
            child: Text(badge, style: TextStyle(color: isPro ? Colors.white : brandViolet, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const Text(' FCFA', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const Text(' /mois', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: isPro ? Colors.white : brandViolet, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(feature, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                  ],
                ),
              )),
          const Spacer(),
          GestureDetector(
            onTap: isButtonEnabled ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionPaymentScreen(
                    creatorId: widget.creatorId,
                    creatorName: _creator?['full_name'] ?? _creator?['username'] ?? 'Créateur',
                    tierType: isPro ? 'pro' : 'premium',
                    price: price,
                  ),
                ),
              ).then((success) {
                if (success == true) _loadCreatorData();
              });
            } : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 8),
          Container(height: 2, width: 40, color: isSelected ? brandViolet : Colors.transparent),
        ],
      ),
    );
  }
}