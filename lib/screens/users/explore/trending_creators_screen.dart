import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT
import '../creator/creator_profile_screen.dart';

class TrendingCreatorsScreen extends StatefulWidget {
  const TrendingCreatorsScreen({super.key});

  @override
  State<TrendingCreatorsScreen> createState() => _TrendingCreatorsScreenState();
}

class _TrendingCreatorsScreenState extends State<TrendingCreatorsScreen> with AutomaticKeepAliveClientMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _creators = [];
  Set<String> _followedIds = {};
  String? _currentUserId;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadData();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadData() async {
    if (_hasLoadedOnce) {
      debugPrint('⏭️ TrendingCreators déjà en mémoire, pas de rechargement');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_currentUserId != null) {
        final followsResponse = await supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', _currentUserId!);

        _followedIds = followsResponse.map<String>((row) => row['following_id'] as String).toSet();
      }

      var query = supabase.from('profiles').select('id, username, full_name, avatar_url');
      if (_currentUserId != null) {
        query = query.neq('id', _currentUserId!);
      }
      final response = await query.limit(50);

      _creators = List<Map<String, dynamic>>.from(response);
      _hasLoadedOnce = true;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur chargement TrendingCreators: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String creatorId) async {
    if (_currentUserId == null) return;

    final isFollowing = _followedIds.contains(creatorId);

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
    super.build(context);

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
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final cardBorder = isDark ? Colors.white10 : Colors.black12;
    final avatarBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final avatarIcon = isDark ? Colors.white : Colors.black87;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    // Bouton "Suivi" (état inactif)
    final followedBtnBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final followedBtnText = isDark ? Colors.white70 : Colors.black54;
    final followedBtnBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade400;

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
          'Créateurs Populaires',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _creators.isEmpty
              ? Center(
                  child: Text(
                    'Aucun créateur trouvé.',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _hasLoadedOnce = false;
                    await _loadData();
                  },
                  color: accentColor,
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            // Avatar cliquable
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
                                backgroundColor: avatarBg,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Icon(Icons.person, color: avatarIcon, size: 28)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Nom et Username
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
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@$username',
                                      style: TextStyle(color: subTextColor, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Bouton Suivre / Suivi
                            SizedBox(
                              height: 34,
                              width: 85,
                              child: ElevatedButton(
                                onPressed: () => _toggleFollow(creatorId),
                                style: ElevatedButton.styleFrom(
                                  // ✅ Bouton actif : noir en clair / blanc en sombre
                                  backgroundColor: isFollowing ? followedBtnBg : accentColor,
                                  foregroundColor: isFollowing ? followedBtnText : accentTextColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: isFollowing
                                        ? BorderSide(color: followedBtnBorder)
                                        : BorderSide.none,
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