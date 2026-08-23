import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/dashboard_service.dart';
// ✅ 1. IMPORT DE L'ÉCRAN DE PROFIL (Vérifie que le chemin correspond à ton dossier)
import '../creator/creator_profile_screen.dart'; 

/// Onglet 6 : Pourboires (Tips)
/// Affiche la liste des pourboires reçus en temps réel
class TipsTab extends StatefulWidget {
  const TipsTab({super.key});

  @override
  State<TipsTab> createState() => _TipsTabState();
}

class _TipsTabState extends State<TipsTab> {
  final DashboardService _dashboardService = DashboardService();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      _tips = await _dashboardService.getReceivedTips(userId, limit: 100);
    } catch (e) {
      debugPrint('❌ Erreur chargement tips: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(double amount) {
    return "${amount.toStringAsFixed(0)} FCFA";
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return "Date inconnue";
    try {
      final date = DateTime.parse(dateString);
      const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
      return "${date.day} ${months[date.month - 1]} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "Date invalide";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    if (_tips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_cafe_outlined, color: Colors.grey.shade600, size: 80),
            const SizedBox(height: 16),
            const Text('Aucun pourboire reçu pour le moment', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Partagez votre profil pour en recevoir !', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTips,
      color: const Color(0xFF8B5CF6),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _tips.length,
        itemBuilder: (context, index) {
          final tip = _tips[index];
          final amount = (tip['amount'] is num) ? (tip['amount'] as num).toDouble() : double.tryParse(tip['amount']?.toString() ?? '0') ?? 0.0;
          
          // ✅ 2. RÉCUPÉRATION DE L'ID DU FAN
          final fanId = tip['fan_id']?.toString();
          
          // Récupérer les infos du fan (avec sécurité null)
          final profileData = tip['profiles'];
          final fanName = profileData != null 
              ? (profileData['full_name'] ?? profileData['username'] ?? 'Un fan anonyme')
              : 'Un fan anonyme';
          final fanAvatar = profileData?['avatar_url']?.toString();

          final message = tip['message']?.toString();
          final paymentMethod = tip['payment_method']?.toString() ?? 'Mobile Money';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 3. GESTURE DETECTOR POUR RENDRE L'AVATAR ET LE NOM CLIQUABLES
                GestureDetector(
                  onTap: () {
                    if (fanId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorProfileScreen(creatorId: fanId),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      // Avatar du fan (avec un petit effet visuel au survol/clic implicite)
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                            backgroundImage: fanAvatar != null ? NetworkImage(fanAvatar) : null,
                            child: fanAvatar == null ? const Icon(Icons.person, color: Color(0xFF8B5CF6)) : null,
                          ),
                          // Petite icône pour indiquer que c'est cliquable
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward, color: Color(0xFF8B5CF6), size: 14),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fanName,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline, // Souligné pour indiquer le lien
                                decorationColor: Color(0xFF8B5CF6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.payment, color: Colors.orangeAccent, size: 12),
                                const SizedBox(width: 4),
                                Text(paymentMethod, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Montant (séparé du clic pour rester propre)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '+ ${_formatMoney(amount)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                
                const SizedBox(height: 12),

                // Message du fan (si présent)
                if (message != null && message.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.format_quote, color: Color(0xFF8B5CF6), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.access_time, color: Colors.grey.shade600, size: 12),
                    const SizedBox(width: 4),
                    Text(_formatDate(tip['created_at']?.toString()), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}