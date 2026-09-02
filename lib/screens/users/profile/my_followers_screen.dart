import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ 1. AJOUT DE L'IMPORT VERS TON ÉCRAN DE PROFIL CRÉATEUR
// ⚠️ Vérifie que le chemin correspond bien à ton arborescence (ex: ../creator/creator_profile_screen.dart)
import '../creator/creator_profile_screen.dart'; 

// Modèle de données pour garder le code propre
class FollowerData {
  final String followerId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime followedAt;

  FollowerData({
    required this.followerId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.isVerified,
    required this.followedAt,
  });
}

class MyFollowersScreen extends StatefulWidget {
  const MyFollowersScreen({super.key});

  @override
  State<MyFollowersScreen> createState() => _MyFollowersScreenState();
}

class _MyFollowersScreenState extends State<MyFollowersScreen> {
  final supabase = Supabase.instance.client;
  List<FollowerData> _followers = [];
  bool _isLoading = true;

  // Couleurs identiques à Next.js
  final Color bg = const Color(0xFF0A0A0A);
  final Color card = const Color(0xFF1A1A1A);
  final Color border = const Color(0xFF2A2A2A);
  final Color primary = const Color(0xFF8B5CF6);
  final Color text = const Color(0xFFFFFFFF);
  final Color textMuted = const Color(0xFF9CA3AF);
  final Color green = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _fetchFollowers();
  }

  Future<void> _fetchFollowers() async {
  setState(() => _isLoading = true);
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final followsRes = await supabase
        .from('follows')
        .select('follower_id, created_at')
        .eq('following_id', user.id)
        .order('created_at', ascending: false);

    if (followsRes.isEmpty) {
      setState(() {
        _followers = [];
        _isLoading = false;
      });
      return;
    }

    final followerIds = (followsRes as List).map((f) => f['follower_id'] as String).toList();
    
    final profilesRes = await supabase
        .from('profiles')
        .select('id, username, full_name, avatar_url, is_verified')
        .inFilter('id', followerIds);

    final profilesMap = {
      for (var p in profilesRes) p['id'] as String: p
    };

    final mergedFollowers = followsRes.map((follow) {
      final profile = profilesMap[follow['follower_id']] ?? {};
      return FollowerData(
        followerId: follow['follower_id'],
        username: profile['username'] ?? 'Utilisateur',
        fullName: profile['full_name'],
        avatarUrl: profile['avatar_url'],
        isVerified: profile['is_verified'] ?? false,
        followedAt: DateTime.parse(follow['created_at']),
      );
    }).toList();

    // ✅ FILTRER : Retirer l'utilisateur actuel de la liste
    final filteredFollowers = mergedFollowers.where((f) => f.followerId != user.id).toList();

    setState(() {
      _followers = filteredFollowers;
      _isLoading = false;
    });
  } catch (e) {
    debugPrint('❌ Erreur chargement des followers: $e');
    setState(() => _isLoading = false);
  }
}

  // ✅ 2. FONCTION DE NAVIGATION ACTIVÉE
  void _handleViewProfile(String targetUserId) {
    final currentUserId = supabase.auth.currentUser?.id;
    
    if (currentUserId == targetUserId) {
      // Si l'utilisateur clique sur son propre nom, on ne fait rien ou on affiche un message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ceci est votre propre profil')),
      );
    } else {
      // ✅ Navigation vers le profil du créateur cliqué
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
        title: const Text('Mes Abonnés', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _followers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _followers.length,
                  itemBuilder: (context, index) {
                    return _buildFollowerCard(_followers[index]);
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
              'Aucun abonné pour le moment',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quand des utilisateurs te suivront, ils apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowerCard(FollowerData follower) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: InkWell(
        // Le clic sur toute la carte déclenche la navigation
        onTap: () => _handleViewProfile(follower.followerId),
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
                  image: follower.avatarUrl != null
                      ? DecorationImage(image: NetworkImage(follower.avatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: follower.avatarUrl == null 
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
                            follower.fullName ?? follower.username,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (follower.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${follower.username}',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Bouton Voir
              OutlinedButton(
                onPressed: () => _handleViewProfile(follower.followerId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Voir',
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