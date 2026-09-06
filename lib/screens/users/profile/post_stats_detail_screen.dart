import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
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

  // Contrôleur vidéo pour l’aperçu
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadPostStats();
    _initVideoPlayer();
  }

  void _initVideoPlayer() {
    final mediaType = widget.post['media_type']?.toString() ?? '';
    final mediaUrl = widget.post['media_url']?.toString();
    if (mediaType == 'video' && mediaUrl != null) {
      _videoController = VideoPlayerController.network(mediaUrl);
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() => _videoInitialized = true);
          _videoController!.play();
          _videoController!.setLooping(true);
        }
      }).catchError((e) {
        debugPrint('❌ Erreur init vidéo stats: $e');
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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
    final mediaType = widget.post['media_type']?.toString() ?? 'image';
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
                  // ─── APERÇU DU POST (avec support vidéo) ──────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildMediaPreview(mediaUrl, mediaType),
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

                  // ─── MÉTRIQUES ──────────────────────────────
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

                  // ─── SOURCES DE TRAFIC ──────────────────────
                  const Text('D\'où viennent vos vues ?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildTrafficBar('Pour toi (Découverte)', 0.65, const Color(0xFF8B5CF6)),
                        const SizedBox(height: 16),
                        _buildTrafficBar('Abonnés', 0.25, Colors.blue),
                        const SizedBox(height: 16),
                        _buildTrafficBar('Profil & Partages', 0.10, Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── BOUTON D'ACTION ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
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

  // ─── MÉTHODES D’AFFICHAGE ──────────────────────────────────

  Widget _buildMediaPreview(String? mediaUrl, String mediaType) {
    if (mediaUrl == null) return _buildPlaceholder();

    if (mediaType == 'video' && _videoController != null && _videoInitialized) {
      return Stack(
        children: [
          // La vidéo en miniature
          Container(
            width: 80,
            height: 80,
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          // Overlay avec les contrôles minimaux (play/pause, temps)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 18,
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(_videoController!.value.position),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  const Text(
                    ' / ',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  Text(
                    _formatDuration(_videoController!.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          // Zone cliquable pour play/pause
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    } else {
      // Image (ou fallback)
      return Image.network(
        mediaUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade800,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  // ─── UTILITAIRES ────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$mins:$secs";
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