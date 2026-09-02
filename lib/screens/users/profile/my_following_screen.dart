import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ 1. IMPORTS POUR LA NAVIGATION
import '../creator/creator_profile_screen.dart';
import '../explore/trending_creators_screen.dart'; // <-- Ajouté pour le bouton "Découvrir"

// Modèle de données pour les personnes suivies
class FollowingData {
  final String followingId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime followedAt;

  FollowingData({
    required this.followingId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.isVerified,
    required this.followedAt,
  });
}

class MyFollowingScreen extends StatefulWidget {
  const MyFollowingScreen({super.key});

  @override
  State<MyFollowingScreen> createState() => _MyFollowingScreenState();
}

class _MyFollowingScreenState extends State<MyFollowingScreen> {
  final supabase = Supabase.instance.client;
  List<FollowingData> _followings = [];
  bool _isLoading = true;
  
  // ✅ Pour gérer l'état de chargement de chaque bouton individuellement
  final Set<String> _unfollowingIds = {};

  // Couleurs identiques à Next.js
  final Color bg = const Color(0xFF0A0A0A);
  final Color card = const Color(0xFF1A1A1A);
  final Color border = const Color(0xFF2A2A2A);
  final Color primary = const Color(0xFF8B5CF6);
  final Color text = const Color(0xFFFFFFFF);
  final Color textMuted = const Color(0xFF9CA3AF);
  final Color green = const Color(0xFF10B981);
  final Color danger = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _fetchFollowings();
  }

  Future<void> _fetchFollowings() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Récupérer tous les following_id que cet utilisateur suit
      final followsRes = await supabase
          .from('follows')
          .select('following_id, created_at')
          .eq('follower_id', user.id)
          .order('created_at', ascending: false);

      if (followsRes.isEmpty) {
        setState(() {
          _followings = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Récupérer les profils de ces personnes suivies
      final followingIds = (followsRes as List).map((f) => f['following_id'] as String).toList();
      
      final profilesRes = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, is_verified')
          .inFilter('id', followingIds);

      // Créer une map pour une fusion rapide des données
      final profilesMap = {
        for (var p in profilesRes) p['id'] as String: p
      };

      // 3. Fusionner les données pour l'affichage
      final mergedFollowings = followsRes.map((follow) {
        final profile = profilesMap[follow['following_id']] ?? {};
        return FollowingData(
          followingId: follow['following_id'],
          username: profile['username'] ?? 'Utilisateur',
          fullName: profile['full_name'],
          avatarUrl: profile['avatar_url'],
          isVerified: profile['is_verified'] ?? false,
          followedAt: DateTime.parse(follow['created_at']),
        );
      }).toList();

      // ✅ 4. FILTRE DE SÉCURITÉ : On retire l'utilisateur actuel de la liste
      final filteredFollowings = mergedFollowings.where((f) => f.followingId != user.id).toList();

      setState(() {
        _followings = filteredFollowings; // On utilise la liste filtrée
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement des suivis: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ Fonction pour se désabonner d'un utilisateur (Corrigée pour Supabase v2+)
  Future<void> _handleUnfollow(String targetUserId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Ajouter l'ID à l'ensemble des chargements pour désactiver le bouton
    setState(() => _unfollowingIds.add(targetUserId));

    try {
      // Dans supabase_flutter v2+, delete() lève une exception en cas d'erreur.
      await supabase
          .from('follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', targetUserId);

      // Suppression réussie : on retire l'élément de la liste locale
      setState(() {
        _followings.removeWhere((f) => f.followingId == targetUserId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Désabonnement réussi'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur unfollow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de se désabonner pour le moment.'), 
            backgroundColor: Colors.red
          ),
        );
      }
    } finally {
      // Retirer l'ID de l'ensemble des chargements, que ça ait réussi ou échoué
      if (mounted) {
        setState(() => _unfollowingIds.remove(targetUserId));
      }
    }
  }

  // ✅ Fonction de navigation (avec sécurité en cas de bug)
  void _handleViewProfile(String targetUserId) {
    final currentUserId = supabase.auth.currentUser?.id;
    
    if (currentUserId == targetUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ceci est votre propre profil')),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatorProfileScreen(creatorId: targetUserId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mes Suivis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _followings.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _followings.length,
                  itemBuilder: (context, index) {
                    return _buildFollowingCard(_followings[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Tu ne suis personne pour le moment',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore la page Découvrir pour trouver des créateurs à suivre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            // ✅ BOUTON MODIFIÉ : Redirige vers l'écran d'exploration des créateurs
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrendingCreatorsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Découvrir des créateurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingCard(FollowingData following) {
    final isUnfollowing = _unfollowingIds.contains(following.followingId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: InkWell(
        onTap: () => _handleViewProfile(following.followingId),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: border,
                  image: following.avatarUrl != null
                      ? DecorationImage(image: NetworkImage(following.avatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: following.avatarUrl == null 
                    ? const Icon(Icons.person, size: 28, color: Colors.white) 
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            following.fullName ?? following.username,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (following.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${following.username}',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Bouton Se désabonner
              OutlinedButton(
                onPressed: isUnfollowing ? null : () => _handleUnfollow(following.followingId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: danger,
                  side: BorderSide(color: danger, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: isUnfollowing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                      )
                    : const Text(
                        'Retirer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}