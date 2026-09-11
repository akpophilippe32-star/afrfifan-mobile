import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_subscription.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import '../explore/trending_creators_screen.dart';

class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  final supabase = Supabase.instance.client;
  List<UserSubscription> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final subsResponse = await supabase
          .from('subscriptions')
          .select('*')
          .eq('fan_id', user.id)
          .order('created_at', ascending: false);

      if (subsResponse.isEmpty) {
        setState(() {
          _subscriptions = [];
          _isLoading = false;
        });
        return;
      }

      final creatorIds = (subsResponse as List).map((s) => s['creator_id'] as String).toSet().toList();
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, is_verified')
          .inFilter('id', creatorIds);

      final profilesMap = {
        for (var p in profilesResponse) p['id'] as String: p
      };

      final groupedSubs = <String, List<Map<String, dynamic>>>{};
      for (var sub in subsResponse) {
        final creatorId = sub['creator_id'] as String;
        groupedSubs.putIfAbsent(creatorId, () => []).add(sub);
      }

      final now = DateTime.now();
      final List<UserSubscription> finalSubs = [];

      groupedSubs.forEach((creatorId, subs) {
        final profile = profilesMap[creatorId] ?? {};

        final activeSub = subs.firstWhere(
          (s) => s['status'] == 'active',
          orElse: () => subs.first,
        );

        final endDate = DateTime.parse(activeSub['end_date']);
        final isExpired = endDate.isBefore(now);
        final daysRemaining = endDate.difference(now).inDays;

        String displayStatus = 'active';
        if (isExpired) {
          displayStatus = 'expired';
        } else if (daysRemaining <= 7) {
          displayStatus = 'expiring_soon';
        }

        final tiers = subs.map((s) => s['tier_type'] as String).toList();
        String highestTier = 'basic';
        if (tiers.contains('pro')) highestTier = 'pro';
        else if (tiers.contains('premium')) highestTier = 'premium';

        finalSubs.add(UserSubscription(
          creatorId: creatorId,
          username: profile['username'] ?? 'Utilisateur',
          fullName: profile['full_name'],
          avatarUrl: profile['avatar_url'],
          isVerified: profile['is_verified'] ?? false,
          highestTier: highestTier,
          endDate: endDate,
          isExpired: isExpired,
          daysRemaining: daysRemaining,
          displayStatus: displayStatus,
        ));
      });

      finalSubs.sort((a, b) {
        if (a.displayStatus == 'active' && b.displayStatus != 'active') return -1;
        if (a.displayStatus != 'active' && b.displayStatus == 'active') return 1;
        return b.endDate.compareTo(a.endDate);
      });

      final filteredSubs = finalSubs.where((sub) => sub.creatorId != user.id).toList();

      setState(() {
        _subscriptions = filteredSubs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement abonnements: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ Tier colors : neutres pour ne pas dépendre du thème
  Color _getTierColor(String tier, bool isDark) {
    final accent = isDark ? Colors.white : Colors.black;
    switch (tier) {
      case 'pro': return accent;
      case 'premium': return accent;
      case 'basic': return accent.withOpacity(0.6);
      default: return accent.withOpacity(0.4);
    }
  }

  String _getTierLabel(String tier) {
    switch (tier) {
      case 'pro': return 'Pro';
      case 'premium': return 'Premium';
      case 'basic': return 'Basic';
      default: return tier;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
          'Mes Abonnements',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _subscriptions.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    return _buildSubscriptionCard(sub, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Aucun abonnement actif',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Abonnez-vous à des créateurs pour accéder à leur contenu exclusif.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // ✅ Bouton neutre
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
                style: TextStyle(color: accentTextColor, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(UserSubscription sub, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    final tierColor = _getTierColor(sub.highestTier, isDark);

    // ⚠️ Couleurs de statut (vert/orange/rouge) conservées car sémantiques
    final green = const Color(0xFF10B981);
    final orange = const Color(0xFFF97316);
    final red = const Color(0xFFEF4444);

    String statusLabel;
    Color statusColor;
    Color statusBgColor;

    if (sub.displayStatus == 'expired') {
      statusLabel = 'Expiré';
      statusColor = red;
      statusBgColor = red.withOpacity(0.1);
    } else if (sub.displayStatus == 'expiring_soon') {
      statusLabel = 'Expire dans ${sub.daysRemaining}j';
      statusColor = orange;
      statusBgColor = orange.withOpacity(0.1);
    } else {
      statusLabel = 'Actif';
      statusColor = green;
      statusBgColor = green.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── PARTIE CLIQUABLE ───
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrendingCreatorsScreen()),
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ─── AVATAR ───
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // ✅ Bordure accent (noire en clair / blanche en sombre)
                      border: Border.all(color: accentColor, width: 3),
                      image: sub.avatarUrl != null
                          ? DecorationImage(image: NetworkImage(sub.avatarUrl!), fit: BoxFit.cover)
                          : null,
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
                    ),
                    child: sub.avatarUrl == null
                        ? Icon(Icons.person, size: 32, color: textColor)
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
                                sub.fullName ?? sub.username,
                                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (sub.isVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                              ),
                          ],
                        ),
                        Text('@${sub.username}', style: TextStyle(color: subTextColor, fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── BADGE TIER ───
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      border: Border.all(color: accentColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTierLabel(sub.highestTier),
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── FOOTER (date + bouton) ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // ✅ Fond légèrement différent du card
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.03),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sub.isExpired ? 'Expiré le ${_formatDate(sub.endDate)}' : 'Expire le ${_formatDate(sub.endDate)}',
                  style: TextStyle(color: sub.isExpired ? red : subTextColor, fontSize: 13),
                ),
                if (sub.isExpired || sub.displayStatus == 'expiring_soon')
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TrendingCreatorsScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      // ✅ Bouton : noir en clair / blanc en sombre (si expiré)
                      // ✅ Sinon : transparent avec bordure orange (Prolonger)
                      backgroundColor: sub.isExpired ? accentColor : Colors.transparent,
                      foregroundColor: sub.isExpired ? accentTextColor : orange,
                      side: sub.isExpired ? null : const BorderSide(color: Color(0xFFF97316)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: Text(
                      sub.isExpired ? '🔄 Renouveler' : 'Prolonger',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}