import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/analytics_service.dart';

class PostStatsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostStatsDetailScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostStatsDetailScreen> createState() => _PostStatsDetailScreenState();
}

class _PostStatsDetailScreenState extends State<PostStatsDetailScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPostStats();
  }

  Future<void> _loadPostStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _analyticsService.getPostStats(widget.post['id']);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement stats post: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = widget.post['media_url']?.toString();
    final caption = widget.post['content'] ?? widget.post['caption'] ?? '';
    final createdAt = widget.post['created_at']?.toString();

    final views = _stats['views'] ?? widget.post['views_count'] ?? 0;
    final likes = _stats['likes'] ?? widget.post['likes_count'] ?? 0;
    final comments = _stats['comments'] ?? widget.post['comments_count'] ?? 0;
    final engagementRate = _stats['engagementRate'] ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('Statistiques du post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. APERÇU DU POST
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: mediaUrl != null
                            ? Image.network(mediaUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                            : _buildPlaceholder(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caption.isEmpty ? '(Pas de légende)' : caption,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Publié le ${_formatDate(createdAt)}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 2. GRANDES CARTES DE MÉTRIQUES
                  const Text('Performance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Vues', views, Icons.visibility, Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('Likes', likes, Icons.favorite, Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Commentaires', comments, Icons.chat_bubble, Colors.orange)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('Engagement', '${engagementRate.toStringAsFixed(1)}%', Icons.trending_up, Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 3. SOURCES DE TRAFIC (Estimation visuelle)
                  const Text('D\'où viennent vos vues ?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildTrafficBar('Pour toi (Découverte)', 0.65, const Color(0xFF8B5CF6)), // 65%
                        const SizedBox(height: 16),
                        _buildTrafficBar('Abonnés', 0.25, Colors.blue), // 25%
                        const SizedBox(height: 16),
                        _buildTrafficBar('Profil & Partages', 0.10, Colors.grey), // 10%
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 4. BOUTON D'ACTION
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Ici, tu pourras naviguer vers l'écran PostDetailScreen si tu le souhaites
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fonctionnalité de lien vers le post à ajouter')),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Voir le post', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS UTILITAIRES ---

  Widget _buildPlaceholder() {
    return Container(
      width: 80, height: 80,
      color: Colors.grey.shade800,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildMetricCard(String title, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTrafficBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text('${(percentage * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Inconnue';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Inconnue';
    }
  }
}