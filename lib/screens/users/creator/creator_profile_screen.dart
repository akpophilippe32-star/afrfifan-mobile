import 'dart:ui';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/messaging_service.dart';
import '../../../services/notification_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../messages/chat_screen.dart';
import 'post_detail_screen.dart';
import 'subscription_payment_screen.dart';
import 'product_detail_screen.dart';
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
  List<Map<String, dynamic>> _shopProducts = [];
  bool _isLoading = true;
  bool _isLoadingShop = true;
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
    // ✅ Cache des miniatures vidéos
  final Map<String, Uint8List?> _videoThumbnailCache = {};

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
        _loadCreatorShop(),
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
          .select('id, username, role, full_name, avatar_url, bio, is_verified, premium_price, pro_price, created_at')
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
          .select('id, media_url, media_type, content, caption, title, access_level, created_at, likes_count, comments_count') // ✅ AJOUT DE 'content' ICI
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

  Future<void> _loadCreatorShop() async {
    try {
      final response = await supabase
          .from('digital_products')
          .select('*')
          .eq('creator_id', widget.creatorId)
          .eq('status', 'published')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _shopProducts = List<Map<String, dynamic>>.from(response);
          _isLoadingShop = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement boutique: $e');
      if (mounted) setState(() => _isLoadingShop = false);
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
      debugPrint('Erreur loadFollowersCount: $e');
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

  void _openChat(bool isDark) {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour envoyer un message'), backgroundColor: Colors.red),
      );
      return;
    }

    final bool isCreator = _creator?['role'] == 'creator';
    if (isCreator && !_isProSubscriber) {
      final dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black87;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: dialogBg,
          title: Row(
            children: [
              Icon(Icons.lock, color: textColor),
              const SizedBox(width: 8),
              Text('Contenu Réservé', style: TextStyle(color: textColor)),
            ],
          ),
          content: Text(
            'Les messages privés avec ce créateur sont réservés aux abonnés PRO. Mettez à niveau votre abonnement pour débloquer cette fonctionnalité.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
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
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: const Text('Devenir Abonné PRO'),
            ),
          ],
        ),
      );
      return;
    }

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

 void _openPostDetail(int index, bool isDark) {
  final bool isCreatorCheck = _creator?['role'] == 'creator';
  // ✅ MÊME LOGIQUE QUE ExploreScreen et PostDetailScreen : TOUT le contenu d'un créateur est verrouillé si pas abonné
  final bool isLocked = isCreatorCheck && !_isSubscribed;

  if (isLocked) {
    // ✅ Redirige vers le paiement au lieu du snackbar
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPaymentScreen(
          creatorId: widget.creatorId,
          creatorName: _creator?['full_name'] ?? _creator?['username'] ?? 'Créateur',
          tierType: 'premium',
          price: (_creator?['premium_price'] ?? 0).toDouble() > 0 
              ? (_creator?['premium_price'] as num).toDouble() 
              : 2000.0,
        ),
      ),
    ).then((success) {
      if (success == true) _loadCreatorData();
    });
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
    Color _getTextBgColor(String? bgColorHex, bool isDark) {
    if (bgColorHex == null || bgColorHex.isEmpty) {
      return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    }
    try {
      String hex = bgColorHex.replaceAll('#', '0xFF');
      return Color(int.parse(hex));
    } catch (e) {
      return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    }
  }
  Future<Uint8List?> _getVideoThumbnail(String videoUrl) async {
    if (_videoThumbnailCache.containsKey(videoUrl)) {
      return _videoThumbnailCache[videoUrl];
    }
    try {
      final thumb = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
      );
      _videoThumbnailCache[videoUrl] = thumb;
      return thumb;
    } catch (e) {
      debugPrint('❌ Erreur miniature vidéo: $e');
      _videoThumbnailCache[videoUrl] = null;
      return null;
    }
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
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade500 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final accentColor = isDark ? Colors.white : Colors.black;

    final bool isVerifiedCreator = _creator?['is_verified'] == true;
    final bool isCreator = _creator?['role'] == 'creator';
    final double premiumPrice = (_creator?['premium_price'] ?? 0).toDouble();
    final double proPrice = (_creator?['pro_price'] ?? 0).toDouble();
    final bool hasPrices = premiumPrice > 0 || proPrice > 0;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: textColor)),
      );
    }

    if (_creator == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: Text('Profil introuvable', style: TextStyle(color: textColor))),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: bgColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black12,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: textColor, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                color: cardColor,
                icon: Icon(Icons.more_vert, color: textColor, size: 28),
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
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 12),
                        Text('Signaler ce profil', style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                // ✅ Plus de gradient violet
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB),
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
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: accentColor, width: 2),
                                    )
                                  : null,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                backgroundImage: _creator?['avatar_url'] != null
                                    ? NetworkImage(_creator!['avatar_url'].toString())
                                    : null,
                                child: _creator?['avatar_url'] == null
                                    ? Icon(Icons.person, color: textColor, size: 50)
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: bgColor, width: 2),
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
                                    style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerifiedCreator) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.verified, color: textColor, size: 22),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('@${_creator?['username'] ?? 'utilisateur'}',
                                style: TextStyle(color: subTextColor, fontSize: 14)),
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
                            backgroundColor: _isFollowing
                                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                                : (isDark ? Colors.white : Colors.black),
                            foregroundColor: _isFollowing
                                ? (isDark ? Colors.white70 : Colors.black54)
                                : (isDark ? Colors.black : Colors.white),
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
                            foregroundColor: textColor,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openChat(isDark),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                          color: isCreator && !_isProSubscriber ? Colors.orange : borderColor,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: Icon(
                        isCreator && !_isProSubscriber ? Icons.lock_outline : Icons.message_outlined,
                        size: 18,
                      ),
                      label: Text(
                        isCreator && !_isProSubscriber ? 'Message (Nécessite PRO)' : 'Message privé',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  if (_creator?['bio'] != null && _creator!['bio'].toString().isNotEmpty)
                    Text(_creator!['bio'].toString(),
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.group, _formatCount(_followersCount), 'Abonnés', accentColor, textColor, subTextColor),
                      Container(width: 1, height: 40, color: dividerColor),
                      _buildStatItem(Icons.grid_view, _formatCount(_postsCount), 'Posts', accentColor, textColor, subTextColor),
                    ],
                    
                  ),
                  
                  const SizedBox(height: 24),

                  if (isCreator && hasPrices) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Abonnements',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
                              isPro: false,
                              currentTier: _currentSubscription?['tier_type'],
                              daysRemaining: _daysRemaining,
                              isDark: isDark,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              accentColor: accentColor,
                            ),
                          if (premiumPrice > 0 && proPrice > 0) const SizedBox(width: 16),
                          if (proPrice > 0)
                            _buildMembershipCard(
                              'PRO', 'Membre VIP', proPrice,
                              ['Tout le contenu Premium', 'Vidéos exclusives', 'Messages privés', 'Appels vidéo/audio'],
                              isPro: true,
                              currentTier: _currentSubscription?['tier_type'],
                              daysRemaining: _daysRemaining,
                              isDark: isDark,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              accentColor: accentColor,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Row(
                    children: [
                      _buildTab('POSTS', 0, textColor, subTextColor, accentColor),
                      const SizedBox(width: 16),
                      _buildTab('BOUTIQUE', 1, textColor, subTextColor, accentColor),
                      const SizedBox(width: 16),
                      _buildTab('À PROPOS', 2, textColor, subTextColor, accentColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          if (_selectedTab == 0)
            (_posts.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Aucune publication pour le moment', style: TextStyle(color: subTextColor)),
                      ),
                    ),
                  )
                : SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = _posts[index];
                        final mediaUrl = post['media_url']?.toString();
                        final mediaType = post['media_type']?.toString() ?? 'image';
                        final likesCount = post['likes_count'] ?? 0;
final title = (post['content'] ?? post['title'] ?? post['caption'] ?? '').toString();
                   final bool isCreatorCheck = _creator?['role'] == 'creator';
// ✅ MÊME LOGIQUE : tout le contenu d'un créateur est verrouillé
final bool isLocked = isCreatorCheck && !_isSubscribed;

                        return GestureDetector(
                          onTap: () => _openPostDetail(index, isDark),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                if (mediaType == 'text')
  // ✅ POST TEXTE : flouté avec couleur de fond si verrouillé
  ImageFiltered(
    imageFilter: isLocked ? ImageFilter.blur(sigmaX: 15, sigmaY: 15) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
    child: Container(
      color: _getTextBgColor(post['background_color']?.toString(), isDark),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            (post['content'] ?? post['caption'] ?? post['title'] ?? '').toString(),
                        style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  )
else if (mediaType == 'video' && mediaUrl != null && mediaUrl.isNotEmpty)
  // ✅ MINIATURE VIDÉO RÉELLE
  FutureBuilder<Uint8List?>(
    future: _getVideoThumbnail(mediaUrl),
    builder: (context, snapshot) {
      Widget mediaWidget;
      if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data == null) {
        mediaWidget = Container(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
          child: Center(
            child: Icon(Icons.videocam, color: subTextColor, size: 32),
          ),
        );
      } else {
        mediaWidget = Image.memory(snapshot.data!, fit: BoxFit.cover);
      }
      return isLocked
          ? ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: mediaWidget,
            )
          : mediaWidget;
    },
  )
else if (mediaUrl != null && mediaUrl.isNotEmpty)
  isLocked
      ? ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Image.network(mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.broken_image, color: subTextColor))),
        )
      : Image.network(mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
              child: Icon(Icons.broken_image, color: subTextColor)))
else
  Center(
    child: Icon(
      Icons.image,
      color: subTextColor,
      size: 32,
    ),
  ),

                                  if (isLocked)
                                    Container(
                                      color: Colors.black.withOpacity(0.4),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock, color: Colors.white, size: 32),
                                            SizedBox(height: 8),
                                            Text('Exclusif',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),

                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (title.isNotEmpty)
                                            Text(title,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text('❤️ ${_formatCount(likesCount)}',
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // ✅ Plus d'icône play, seulement le type de média
                                  if (mediaType == 'text' && !isLocked)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.text_fields, color: Colors.white, size: 14),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
                  ))
          else if (_selectedTab == 1)
            _buildPublicShopGrid(isDark, textColor, subTextColor, cardColor, borderColor)
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Biographie',
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_creator?['bio'] ?? 'Aucune biographie pour le moment.',
                        style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 14, height: 1.5)),
                    const SizedBox(height: 24),
                    Text('Membre depuis',
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        _creator?['created_at'] != null
                            ? DateTime.parse(_creator!['created_at']).toString().split(' ')[0]
                            : 'Date inconnue',
                        style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 14)),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildPublicShopGrid(bool isDark, Color textColor, Color subTextColor, Color cardColor, Color borderColor) {
    if (_isLoadingShop) {
      return SliverToBoxAdapter(
        child: Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: textColor))),
      );
    }
    if (_shopProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Aucun produit en vente pour le moment', style: TextStyle(color: subTextColor)))),
      );
    }
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = _shopProducts[index];
          final title = product['title'] as String? ?? 'Sans titre';
          final price = (product['price'] as num?)?.toDouble() ?? 0;
          final mediaType = product['media_type'] as String? ?? 'file';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    product: product,
                    creatorId: widget.creatorId,
                    creatorName: _creator?['username'] ?? 'Créateur',
                  ),
                ),
              ).then((refresh) {
                if (refresh == true) _loadCreatorShop();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            mediaType == 'image' ? Icons.image : Icons.insert_drive_file,
                            color: subTextColor,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            '${price.toStringAsFixed(0)} FCFA',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: _shopProducts.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color accentColor, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: subTextColor, fontSize: 11)),
      ],
    );
  }

  Widget _buildMembershipCard(
    String badge,
    String title,
    double price,
    List<String> features, {
    required bool isPro,
    required String? currentTier,
    required int daysRemaining,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
  }) {
    bool isCurrentTier = currentTier == (isPro ? 'pro' : 'premium');
    bool isDowngradeBlocked = currentTier == 'pro' && !isPro;

    String buttonText = 'Rejoindre';
    bool isButtonEnabled = true;
    Color buttonColor = isPro
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white24 : Colors.black12);
    Color buttonTextColor = isPro
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);

    if (isCurrentTier) {
      buttonText = 'Déjà abonné ($daysRemaining j.)';
      isButtonEnabled = false;
      buttonColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
      buttonTextColor = isDark ? Colors.grey.shade400 : Colors.black45;
    } else if (isDowngradeBlocked) {
      buttonText = 'Disponible après période Pro';
      isButtonEnabled = false;
      buttonColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
      buttonTextColor = isDark ? Colors.grey.shade400 : Colors.black45;
    } else if (currentTier != null && !isPro) {
      buttonText = 'Passer à Pro';
    }

    final cardBg = isPro
        ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB))
        : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB));

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPro ? accentColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPro
                  ? accentColor.withOpacity(0.15)
                  : (isDark ? Colors.white10 : Colors.black12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badge,
                style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price.toStringAsFixed(0),
                  style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(' FCFA',
                  style: TextStyle(color: subTextColor, fontSize: 11)),
              Text(' /mois',
                  style: TextStyle(color: subTextColor, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: accentColor, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(feature,
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 11))),
                  ],
                ),
              )),
          const Spacer(),
          GestureDetector(
            onTap: isButtonEnabled
                ? () {
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
                  }
                : null,
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
                style: TextStyle(color: buttonTextColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, Color textColor, Color subTextColor, Color accentColor) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: isSelected ? textColor : subTextColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 8),
          Container(height: 2, width: 40, color: isSelected ? accentColor : Colors.transparent),
        ],
      ),
    );
  }
}