import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onSubscribeClick;
  final VoidCallback onTipClick;
  final VoidCallback onCommentClick;

  const PostCard({
    super.key,
    required this.post,
    required this.onSubscribeClick,
    required this.onTipClick,
    required this.onCommentClick,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6C5CE7);
    final bool isLocked = post['isLocked'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la publication (Créateur + Bouton Suivre)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['creatorName'] ?? 'Créateur',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        post['timeAgo'] ?? 'Il y a 2h',
                        style: const TextStyle(color: Colors.black45, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(60, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Suivre', style: TextStyle(color: primaryColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Texte de la publication
          Text(
            post['content'] ?? '',
            style: const TextStyle(color: Colors.black87, fontSize: 12),
          ),
          const SizedBox(height: 10),

          // Média ou Zone Verrouillée
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Image ou Média de fond
                Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image, size: 50, color: Colors.white),
                ),
                
                // Si le contenu est verrouillé pour les non-abonnés
                if (isLocked) ...[
                  Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.white, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        'Réservé aux abonnés ${post['requiredPlan'] ?? 'Premium'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: onSubscribeClick,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Text("S'abonner", style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Barre d'interactions (Commentaires, Pourboires/Tips, Likes)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onCommentClick,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.black54),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  Text('${post['commentsCount'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border, size: 18, color: Colors.black54),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  Text('${post['likesCount'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
              // Bouton Pourboire (Tip Mobile Money)
              TextButton.icon(
                onPressed: onTipClick,
                icon: const Icon(Icons.card_giftcard, size: 16, color: primaryColor),
                label: const Text('Pourboire', style: TextStyle(color: primaryColor, fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}