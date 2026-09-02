import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_subscription.dart';

// ✅ IMPORT DE L'ÉCRAN D'EXPLORATION (qui n'attend pas de paramètre creatorId)
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

  // Couleurs identiques à Next.js
  final Color bg = const Color(0xFF0A0A0A);
  final Color card = const Color(0xFF1A1A1A);
  final Color border = const Color(0xFF2A2A2A);
  final Color primary = const Color(0xFF8B5CF6);
  final Color text = const Color(0xFFFFFFFF);
  final Color textMuted = const Color(0xFF9CA3AF);
  final Color green = const Color(0xFF10B981);
  final Color orange = const Color(0xFFF97316);
  final Color red = const Color(0xFFEF4444);
  final Color gold = const Color(0xFFF59E0B);

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

      // 1. Récupérer les abonnements où L'UTILISATEUR EST LE FAN (celui qui paie)
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

      // 2. Récupérer les profils des créateurs
      final creatorIds = (subsResponse as List).map((s) => s['creator_id'] as String).toSet().toList();
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, is_verified')
          .inFilter('id', creatorIds);

      final profilesMap = {
        for (var p in profilesResponse) p['id'] as String: p
      };

      // 3. Regrouper par créateur
      final groupedSubs = <String, List<Map<String, dynamic>>>{};
      for (var sub in subsResponse) {
        final creatorId = sub['creator_id'] as String;
        groupedSubs.putIfAbsent(creatorId, () => []).add(sub);
      }

      // 4. Traiter les données pour l'affichage
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

      // Trier : actifs d'abord, puis par date de fin
      finalSubs.sort((a, b) {
        if (a.displayStatus == 'active' && b.displayStatus != 'active') return -1;
        if (a.displayStatus != 'active' && b.displayStatus == 'active') return 1;
        return b.endDate.compareTo(a.endDate);
      });

      // ✅ FILTRE DE SÉCURITÉ : On retire l'utilisateur actuel de la liste
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

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'pro': return gold;
      case 'premium': return primary;
      case 'basic': return green;
      default: return textMuted;
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
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mes Abonnements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _subscriptions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    return _buildSubscriptionCard(sub);
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
            const Text('⭐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Aucun abonnement actif', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Abonnez-vous à des créateurs pour accéder à leur contenu exclusif.', 
                textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 14)),
            const SizedBox(height: 24),
            
            // ✅ BOUTON MODIFIÉ : Redirige vers l'écran d'exploration SANS paramètre
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrendingCreatorsScreen(), // <-- Pas de creatorId ici
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Découvrir des créateurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(UserSubscription sub) {
    final tierColor = _getTierColor(sub.highestTier);
    
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
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Partie cliquable
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // ✅ CORRECTION : On retire creatorId car TrendingCreatorsScreen ne l'attend pas
                  builder: (context) => const TrendingCreatorsScreen(), 
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tierColor, width: 3),
                      image: sub.avatarUrl != null
                          ? DecorationImage(image: NetworkImage(sub.avatarUrl!), fit: BoxFit.cover)
                          : null,
                      color: border,
                    ),
                    child: sub.avatarUrl == null ? const Icon(Icons.person, size: 32, color: Colors.white) : null,
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
                                sub.fullName ?? sub.username,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (sub.isVerified) const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                            ),
                          ],
                        ),
                        Text('@${sub.username}', style: TextStyle(color: textMuted, fontSize: 13)),
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
                  // Badge Tier
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.2),
                      border: Border.all(color: tierColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getTierLabel(sub.highestTier),
                      style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer avec date et bouton
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              border: Border(top: BorderSide(color: border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sub.isExpired ? 'Expiré le ${_formatDate(sub.endDate)}' : 'Expire le ${_formatDate(sub.endDate)}',
                  style: TextStyle(color: sub.isExpired ? red : textMuted, fontSize: 13),
                ),
                if (sub.isExpired || sub.displayStatus == 'expiring_soon')
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // ✅ CORRECTION : On retire creatorId ici aussi
                          builder: (context) => const TrendingCreatorsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sub.isExpired ? primary : Colors.transparent,
                      foregroundColor: sub.isExpired ? Colors.white : orange,
                      side: sub.isExpired ? null : BorderSide(color: orange),
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