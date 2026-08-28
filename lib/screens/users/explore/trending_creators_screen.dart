import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../creator/creator_profile_screen.dart';

class TrendingCreatorsScreen extends StatefulWidget {
  const TrendingCreatorsScreen({super.key});

  @override
  State<TrendingCreatorsScreen> createState() => _TrendingCreatorsScreenState();
}

// ✅ 1. AJOUT DU MIXIN POUR GARDER L'ÉCRAN EN MÉMOIRE
class _TrendingCreatorsScreenState extends State<TrendingCreatorsScreen> with AutomaticKeepAliveClientMixin {
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _creators = [];
  Set<String> _followedIds = {};
  String? _currentUserId;
  bool _isLoading = true;
  bool _hasLoadedOnce = false; // ✅ Pour charger une seule fois

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadData();
  }

  // ✅ 2. DIT À FLUTTER DE NE PAS DÉTRUIRE CET ÉCRAN
  @override
  bool get wantKeepAlive => true;

  Future<void> _loadData() async {
    // ✅ Si déjà chargé, on ne fait rien (gain de temps et de données)
    if (_hasLoadedOnce) {
      debugPrint('⏭️ TrendingCreators déjà en mémoire, pas de rechargement');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Récupérer les IDs des créateurs déjà suivis
      if (_currentUserId != null) {
        final followsResponse = await supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', _currentUserId!);
        
        _followedIds = followsResponse.map<String>((row) => row['following_id'] as String).toSet();
      }

      // 2. Récupérer les profils (FILTRE .neq AVANT .limit)
      var query = supabase.from('profiles').select('id, username, full_name, avatar_url');
      if (_currentUserId != null) {
        query = query.neq('id', _currentUserId!);
      }
      final response = await query.limit(50);
      
      _creators = List<Map<String, dynamic>>.from(response);
      
      // ✅ On marque comme chargé pour la prochaine fois
      _hasLoadedOnce = true; 

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur chargement TrendingCreators: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fonction pour Suivre / Ne plus suivre
  Future<void> _toggleFollow(String creatorId) async {
    if (_currentUserId == null) return;

    final isFollowing = _followedIds.contains(creatorId);

    // Mise à jour immédiate de l'interface (Optimistic UI)
    setState(() {
      if (isFollowing) {
        _followedIds.remove(creatorId);
      } else {
        _followedIds.add(creatorId);
      }
    });

    try {
      if (isFollowing) {
        await supabase.from('follows').delete().match({
          'follower_id': _currentUserId!,
          'following_id': creatorId,
        });
      } else {
        await supabase.from('follows').insert({
          'follower_id': _currentUserId!,
          'following_id': creatorId,
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur toggle follow: $e');
      // En cas d'erreur, on annule le changement visuel
      setState(() {
        if (isFollowing) {
          _followedIds.add(creatorId);
        } else {
          _followedIds.remove(creatorId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 3. OBLIGATOIRE QUAND ON UTILISE AutomaticKeepAliveClientMixin
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
          'Créateurs Populaires',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _creators.isEmpty
              ? const Center(child: Text('Aucun créateur trouvé.', style: TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  // ✅ 4. LE PULL-TO-REFRESH FORCE LE RECHARGEMENT
                  onRefresh: () async {
                    _hasLoadedOnce = false;
                    await _loadData();
                  },
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _creators.length,
                    itemBuilder: (context, index) {
                      final creator = _creators[index];
                      final creatorId = creator['id'] as String;
                      final username = creator['username'] ?? 'Anonyme';
                      final fullName = creator['full_name'] ?? '';
                      final avatarUrl = creator['avatar_url']?.toString();
                      final isFollowing = _followedIds.contains(creatorId);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.all(16), // ✅ Plus d'espace pour respirer
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A), // ✅ Fond sombre élégant sans bordure agressive
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // ✅ Avatar cliquable (légèrement plus grand et propre)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreatorProfileScreen(creatorId: creatorId),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.grey.shade800,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            
                            // ✅ Nom et Username (PROTÉGÉS CONTRE LES TEXTES TROP LONGS)
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreatorProfileScreen(creatorId: creatorId),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName.isNotEmpty ? fullName : username,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1, // ✅ Empêche le texte de passer à la ligne
                                      overflow: TextOverflow.ellipsis, // ✅ Ajoute "..." si trop long
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@$username',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                      maxLines: 1, // ✅ Empêche le texte de passer à la ligne
                                      overflow: TextOverflow.ellipsis, // ✅ Ajoute "..." si trop long
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ✅ Bouton Suivre / Suivi (Compact et élégant)
                            SizedBox(
                              height: 34,
                              width: 85, // ✅ Largeur fixe pour éviter qu'il n'écrase le texte
                              child: ElevatedButton(
                                onPressed: () => _toggleFollow(creatorId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey.shade800 : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20), // ✅ Forme de pilule
                                    side: isFollowing ? BorderSide(color: Colors.grey.shade700) : BorderSide.none,
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                ),
                                child: Text(
                                  isFollowing ? 'Suivi' : 'Suivre',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}