import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Envoyer un signalement (post ou profil)
  Future<void> submitReport({
    required String targetId,
    required String targetType, // 'post' ou 'profile'
    required String reason,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      await _supabase.from('reports').insert({
        'reporter_id': userId, // ✅ AJOUTÉ : L'ID de celui qui signale
        'target_id': targetId,
        'target_type': targetType,
        'reason': reason,
      });
    } catch (e) {
      // Si erreur = déjà signalé (contrainte unique)
      if (e.toString().contains('unique_report_idx')) {
        throw Exception('Vous avez déjà signalé ce contenu.');
      }
      throw Exception('Erreur lors du signalement : $e');
    }
  }
}