import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import '../creator/creator_profile_screen.dart';

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
          'Mes Abonnés',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _followers.isEmpty
              ? _buildEmptyState(textColor, subTextColor)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _followers.length,
                  itemBuilder: (context, index) {
                    return _buildFollowerCard(_followers[index], isDark, textColor, subTextColor, accentColor);
                  },
                ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Aucun abonné pour le moment',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quand des utilisateurs te suivront, ils apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowerCard(
    FollowerData follower,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color accentColor,
  ) {
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
        onTap: () => _handleViewProfile(follower.followerId),
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
                  image: follower.avatarUrl != null
                      ? DecorationImage(image: NetworkImage(follower.avatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: follower.avatarUrl == null
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
                            follower.fullName ?? follower.username,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ─── BOUTON "VOIR" ───
              OutlinedButton(
                onPressed: () => _handleViewProfile(follower.followerId),
                style: OutlinedButton.styleFrom(
                  // ✅ Bouton neutre adaptatif
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor, width: 1.5),
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