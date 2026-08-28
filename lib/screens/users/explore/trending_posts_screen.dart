import 'dart:ui'; // Pour l'effet de flou (ImageFilter)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../creator/subscription_payment_screen.dart';
import 'explore_post_detail_screen.dart';

class TrendingPostsScreen extends StatefulWidget {
  const TrendingPostsScreen({super.key});

  @override
  State<TrendingPostsScreen> createState() => _TrendingPostsScreenState();
}

// ✅ 1. AJOUT DU MIXIN POUR GARDER L'ÉCRAN EN MÉMOIRE
class _TrendingPostsScreenState extends State<TrendingPostsScreen> with AutomaticKeepAliveClientMixin {
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _posts = [];
  Set<String> _subscribedCreatorIds = {};
  String? _currentUserId;
  bool _isLoading = true;
  bool _hasLoadedOnce = false; // ✅ 2. Pour charger une seule fois

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadData();
  }

  // ✅ 3. DIT À FLUTTER DE NE PAS DÉTRUIRE CET ÉCRAN
  @override
  bool get wantKeepAlive => true;

  Future<void> _loadData() async {
    // ✅ Si déjà chargé, on ne fait rien (gain de temps et de données énorme)
    if (_hasLoadedOnce) {
      debugPrint('⏭️ TrendingPosts déjà en mémoire, pas de rechargement');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Récupérer les abonnements actifs de l'utilisateur (pour déverrouiller le contenu)
      if (_currentUserId != null) {
        final subsResponse = await supabase
            .from('subscriptions')
            .select('creator_id')
            .eq('fan_id', _currentUserId!)
            .eq('status', 'active');
        
        _subscribedCreatorIds = subsResponse.map<String>((sub) => sub['creator_id'] as String).toSet();
      }

      // 2. Récupérer les posts les plus populaires (triés par nombre de likes)
      final postsResponse = await supabase
          .from('posts')
          .select('id, user_id, media_url, media_type, content, likes_count, comments_count, created_at')
          .order('likes_count', ascending: false)
          .limit(50); // On charge les 50 plus populaires

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      if (posts.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 3. Récupérer les profils des créateurs de ces posts
      final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', userIds);
      
      final profiles = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profiles) p['id'] as String: p};

      // 4. Fusionner les posts avec les profils
      _posts = posts.map((post) {
        final creatorId = post['user_id'] as String;
        return {
          ...post,
          'profiles': profilesMap[creatorId],
        };
      }).toList();

      // ✅ 5. On marque comme chargé pour la prochaine fois
      _hasLoadedOnce = true;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur chargement TrendingPosts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 6. OBLIGATOIRE QUAND ON UTILISE AutomaticKeepAliveClientMixin
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Contenu Populaire',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _posts.isEmpty
              ? const Center(child: Text('Aucun contenu populaire pour le moment.', style: TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  // ✅ 7. LE PULL-TO-REFRESH FORCE LE RECHARGEMENT
                  onRefresh: () async {
                    _hasLoadedOnce = false;
                    await _loadData();
                  },
                  color: AppColors.primary,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final creatorId = post['user_id']?.toString() ?? '';
                      final mediaUrl = post['media_url']?.toString();
                      final likesCount = post['likes_count'] ?? 0;
                      final creatorName = post['profiles']?['username'] ?? 'Créateur';
                      
                      // ✅ LOGIQUE DE VERROUILLAGE (CLOCHE/CADENAS)
                      final bool isMyOwnPost = (_currentUserId == creatorId);
                      final bool isLocked = !isMyOwnPost && !_subscribedCreatorIds.contains(creatorId);

                      return GestureDetector(
                        onTap: () {
                          if (isLocked) {
                            // Si verrouillé, on ouvre l'écran de paiement
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
                                _hasLoadedOnce = false; // Force le rechargement après un paiement réussi
                                _loadData();
                              }
                            });
                          } else {
                            // Si déverrouillé, on ouvre le détail du post
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExplorePostDetailScreen(
                                  posts: _posts,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. IMAGE / VIDÉO DE FOND
                              if (mediaUrl != null && mediaUrl.isNotEmpty)
                                isLocked
                                    ? ImageFiltered(
                                        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                        child: Image.network(mediaUrl, fit: BoxFit.cover),
                                      )
                                    : Image.network(mediaUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800))
                              else
                                Container(color: Colors.grey.shade800),

                              // 2. OVERLAY SOMBRE SI VERROUILLÉ
                              if (isLocked)
                                Container(color: Colors.black.withOpacity(0.5)),

                              // 3. ICÔNE CADENAS/CLOCHE + TEXTE (SI VERROUILLÉ)
                              if (isLocked)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.lock, color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Contenu Exclusif',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),

                              // 4. ICÔNE VIDEO SI C'EST UNE VIDÉO
                              if (post['media_type'] == 'video' && !isLocked)
                                const Center(
                                  child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40),
                                ),

                              // 5. INFOS EN BAS (NOM + LIKES)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '@$creatorName',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.favorite, color: Colors.redAccent, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            likesCount.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 11),
                                          ),
                                        ],
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
                  ),
                ),
    );
  }
}