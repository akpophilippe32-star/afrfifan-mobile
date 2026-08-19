import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  final String creatorId;

  const PostDetailScreen({super.key, required this.post, required this.creatorId});

  @override
  Widget build(BuildContext context) {
    final mediaUrl = post['media_url']?.toString();
    final title = post['title'] ?? post['caption'] ?? '';
    final viewsCount = post['views_count'] ?? 0;
    final likesCount = post['likes_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;
    final createdAt = post['created_at'] != null 
        ? DateTime.parse(post['created_at']) 
        : DateTime.now();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image/Video en fond
          Positioned.fill(
            child: mediaUrl != null
                ? Image.network(mediaUrl, fit: BoxFit.cover)
                : Container(color: Colors.grey.shade900),
          ),
          // Overlay sombre
          Container(color: Colors.black.withOpacity(0.7)),
          // Contenu
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Infos du post
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.visibility, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text('$viewsCount vues', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 16),
                          Icon(Icons.favorite, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text('$likesCount', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 16),
                          Icon(Icons.comment, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text('$commentsCount', style: TextStyle(color: Colors.grey.shade400)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
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