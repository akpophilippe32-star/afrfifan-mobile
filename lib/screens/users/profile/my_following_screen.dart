import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import '../creator/creator_profile_screen.dart';
import '../explore/trending_creators_screen.dart';

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

  final Set<String> _unfollowingIds = {};

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

      final followingIds = (followsRes as List).map((f) => f['following_id'] as String).toList();

      final profilesRes = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, is_verified')
          .inFilter('id', followingIds);

      final profilesMap = {
        for (var p in profilesRes) p['id'] as String: p
      };

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

      final filteredFollowings = mergedFollowings.where((f) => f.followingId != user.id).toList();

      setState(() {
        _followings = filteredFollowings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement des suivis: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUnfollow(String targetUserId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _unfollowingIds.add(targetUserId));

    try {
      await supabase
          .from('follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', targetUserId);

      setState(() {
        _followings.removeWhere((f) => f.followingId == targetUserId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Désabonnement réussi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur unfollow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de se désabonner pour le moment.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _unfollowingIds.remove(targetUserId));
      }
    }
  }

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes Suivis',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _followings.isEmpty
              ? _buildEmptyState(isDark, textColor, subTextColor, accentColor)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _followings.length,
                  itemBuilder: (context, index) {
                    return _buildFollowingCard(_followings[index], isDark, textColor, subTextColor);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor, Color subTextColor, Color accentColor) {
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Tu ne suis personne pour le moment',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore la page Découvrir pour trouver des créateurs à suivre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // ✅ Bouton "Découvrir des créateurs" : noir en clair / blanc en sombre
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrendingCreatorsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: accentTextColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Découvrir des créateurs',
                style: TextStyle(
                  color: accentTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingCard(
    FollowingData following,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final isUnfollowing = _unfollowingIds.contains(following.followingId);

    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final avatarBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final avatarIcon = isDark ? Colors.white : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: () => _handleViewProfile(following.followingId),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ─── AVATAR ───
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarBg,
                  image: following.avatarUrl != null
                      ? DecorationImage(image: NetworkImage(following.avatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: following.avatarUrl == null
                    ? Icon(Icons.person, size: 28, color: avatarIcon)
                    : null,
              ),
              const SizedBox(width: 16),

              // ─── INFOS ───
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            following.fullName ?? following.username,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ─── BOUTON "RETIRER" (rouge conservé = action danger) ───
              OutlinedButton(
                onPressed: isUnfollowing ? null : () => _handleUnfollow(following.followingId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: isUnfollowing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEF4444),
                        ),
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