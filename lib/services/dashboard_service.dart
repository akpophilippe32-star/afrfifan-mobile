import 'package:supabase_flutter/supabase_flutter.dart';

/// Service qui gère toutes les données du Dashboard Créateur
class DashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ========================================
  // 🏠 ONGLET 1 : VUE D'ENSEMBLE
  // ========================================

  Future<double> getWalletBalance(String creatorId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select('balance')
          .eq('creator_id', creatorId) // ou 'user_id' selon ce que tu vois dans Supabase
          .maybeSingle();

      if (response == null) return 0.0;
      return (response['balance'] ?? 0).toDouble();
    } catch (e) {
      print('❌ Erreur getWalletBalance: $e');
      return 0.0;
    }
  }

  Future<double> getTotalEarnings(String creatorId) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('amount')
          .eq('creator_id', creatorId)
          .inFilter('status', ['active', 'upgraded', 'expired']);

      double total = 0.0;
      for (var sub in response) {
        total += (sub['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      print('❌ Erreur getTotalEarnings: $e');
      return 0.0;
    }
  }

  Future<Map<String, int>> getSubscriberCounts(String creatorId) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('tier_type')
          .eq('creator_id', creatorId)
          .eq('status', 'active');

      int premiumCount = 0;
      int proCount = 0;

      for (var sub in response) {
        final tier = sub['tier_type']?.toString() ?? '';
        if (tier == 'premium') premiumCount++;
        if (tier == 'pro') proCount++;
      }

      return {
        'premium': premiumCount,
        'pro': proCount,
        'total': premiumCount + proCount,
      };
    } catch (e) {
      print('❌ Erreur getSubscriberCounts: $e');
      return {'premium': 0, 'pro': 0, 'total': 0};
    }
  }

  Future<Map<String, dynamic>> getDashboardOverview(String creatorId) async {
    try {
      final results = await Future.wait([
        getWalletBalance(creatorId),
        getTotalEarnings(creatorId),
        getSubscriberCounts(creatorId),
      ]);

      return {
        'balance': results[0] as double,
        'totalEarnings': results[1] as double,
        'subscribers': results[2] as Map<String, int>,
      };
    } catch (e) {
      print('❌ Erreur getDashboardOverview: $e');
      return {
        'balance': 0.0,
        'totalEarnings': 0.0,
        'subscribers': {'premium': 0, 'pro': 0, 'total': 0},
      };
    }
  }

  // ========================================
  // 💰 ONGLET 2 : PORTEFEUILLE
  // ========================================

  Future<List<Map<String, dynamic>>> getRecentTransactions(String creatorId, {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('id, tier_type, amount, created_at, fan_id, profiles:fan_id (username, full_name, avatar_url)')
          .eq('creator_id', creatorId)
          .inFilter('status', ['active', 'upgraded', 'expired'])
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getRecentTransactions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getWithdrawalHistory(String creatorId, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('withdrawals')
          .select('*')
          .eq('creator_id', creatorId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getWithdrawalHistory: $e');
      return [];
    }
  }

    Future<bool> createWithdrawal({
    required String creatorId,
    required double amount,
    required String paymentMethod,
    required String accountNumber,
  }) async {
    try {
      // 1. Vérifier le solde actuel
      final balance = await getWalletBalance(creatorId);
      if (balance < amount) throw Exception('Solde insuffisant');
      if (amount < 5000) throw Exception('Le montant minimum de retrait est de 5000 FCFA');

      // ✅ AJOUT : Calculer le nouveau solde après déduction
      final newBalance = balance - amount;

      // ✅ AJOUT : Mettre à jour immédiatement le portefeuille de l'utilisateur
      await _supabase
          .from('wallets')
          .update({'balance': newBalance})
          .eq('creator_id', creatorId);

      // 2. Créer la demande de retrait (l'argent est déjà déduit)
      await _supabase.from('withdrawals').insert({
        'creator_id': creatorId,
        'amount': amount,
        'payment_method': paymentMethod,
        'account_number': accountNumber,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('❌ Erreur createWithdrawal: $e');
      rethrow;
    }
  }

  // ========================================
  // 👥 ONGLET 3 : ABONNÉS
  // ========================================

  Future<List<Map<String, dynamic>>> getActiveSubscribers(String creatorId, {String? tierFilter}) async {
    try {
      // ✅ CORRECTION : Utilisation de PostgrestFilterBuilder pour éviter l'erreur de type Dart
      PostgrestFilterBuilder request = _supabase
          .from('subscriptions')
          .select('id, tier_type, start_date, end_date, fan_id, profiles:fan_id (id, username, full_name, avatar_url)')
          .eq('creator_id', creatorId)
          .eq('status', 'active');

      if (tierFilter != null && tierFilter.isNotEmpty) {
        request = request.eq('tier_type', tierFilter);
      }

      final response = await request.order('start_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur getActiveSubscribers: $e');
      return [];
    }
  }

  // ========================================
  // 📊 ONGLET 4 : STATISTIQUES
  // ========================================

  Future<Map<DateTime, double>> getRevenueByDay(String creatorId, {int days = 30}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final response = await _supabase
          .from('subscriptions')
          .select('amount, created_at')
          .eq('creator_id', creatorId)
          .inFilter('status', ['active', 'upgraded', 'expired'])
          .gte('created_at', startDate.toIso8601String());

      Map<DateTime, double> dailyRevenue = {};
      for (var sub in response) {
        final date = DateTime.parse(sub['created_at']);
        final dayKey = DateTime(date.year, date.month, date.day);
        dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + (sub['amount'] ?? 0).toDouble();
      }

      return dailyRevenue;
    } catch (e) {
      print('❌ Erreur getRevenueByDay: $e');
      return {};
    }
  }

  /// ✅ NOUVELLE FONCTION AJOUTÉE : Métriques simples pour les stats
  Future<Map<String, dynamic>> getSimpleStats(String creatorId) async {
    try {
      final followers = await _supabase.from('follows').select('follower_id').eq('following_id', creatorId);
      final totalFollowers = followers.length;

      final subscribers = await _supabase
          .from('subscriptions')
          .select('fan_id, created_at')
          .eq('creator_id', creatorId)
          .inFilter('status', ['active', 'upgraded', 'expired']);
      final uniqueFans = subscribers.map((s) => s['fan_id']).toSet().length;
      final conversionRate = totalFollowers > 0 ? (uniqueFans / totalFollowers) * 100 : 0.0;

      final totalEarnings = await getTotalEarnings(creatorId);
      final arpu = uniqueFans > 0 ? totalEarnings / uniqueFans : 0.0;

      final activeSubs = await _supabase.from('subscriptions').select('fan_id').eq('creator_id', creatorId).eq('status', 'active');
      final activeFans = activeSubs.map((s) => s['fan_id']).toSet().length;
      final retentionRate = uniqueFans > 0 ? (activeFans / uniqueFans) * 100 : 0.0;

      String peakHours = 'N/A';
      if (subscribers.isNotEmpty) {
        Map<int, int> hourCounts = {};
        for (var sub in subscribers) {
          final hour = DateTime.parse(sub['created_at']).hour;
          hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
        }
        if (hourCounts.isNotEmpty) {
          final peakHour = hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
          peakHours = '${peakHour}h-${(peakHour + 2) % 24}h';
        }
      }

      return {
        'conversionRate': conversionRate,
        'arpu': arpu,
        'retentionRate': retentionRate,
        'peakHours': peakHours,
      };
    } catch (e) {
      print('❌ Erreur getSimpleStats: $e');
      return {'conversionRate': 0.0, 'arpu': 0.0, 'retentionRate': 0.0, 'peakHours': 'N/A'};
    }
  }

  // ========================================
  // ⚙️ ONGLET 5 : PARAMÈTRES
  // ========================================

  Future<bool> updatePrices({required String creatorId, double? premiumPrice, double? proPrice}) async {
    try {
      final updates = <String, dynamic>{};
      if (premiumPrice != null) updates['premium_price'] = premiumPrice;
      if (proPrice != null) updates['pro_price'] = proPrice;

      if (updates.isEmpty) return false;

      await _supabase.from('profiles').update(updates).eq('id', creatorId);
      return true;
    } catch (e) {
      print('❌ Erreur updatePrices: $e');
      return false;
    }
  }
}