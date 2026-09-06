import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_product_screen.dart'; // Assure-toi que ce fichier existe (créé précédemment)

class CreatorShopTab extends StatefulWidget {
  const CreatorShopTab({super.key});

  @override
  State<CreatorShopTab> createState() => _CreatorShopTabState();
}

class _CreatorShopTabState extends State<CreatorShopTab> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('digital_products')
          .select('*')
          .eq('creator_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement boutique: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store, color: Color(0xFF8B5CF6), size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'Votre boutique est vide',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Commencez à vendre vos créations numériques dès maintenant.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateProductScreen()),
                  );
                  if (result == true) _loadProducts();
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Ajouter mon premier produit', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            final product = _products[index];
            return _buildProductCard(product);
          },
        ),
        // Bouton flottant pour ajouter rapidement
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateProductScreen()),
              );
              if (result == true) _loadProducts();
            },
            backgroundColor: const Color(0xFF8B5CF6),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Nouveau', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final title = product['title'] as String? ?? 'Sans titre';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final mediaType = product['media_type'] as String? ?? 'file';
    final status = product['status'] as String? ?? 'draft';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'published' ? const Color(0xFF2A2A2A) : Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color: Colors.grey.shade900,
                child: Center(
                  child: Icon(
                    mediaType == 'video' ? Icons.video_library : 
                    mediaType == 'image' ? Icons.image : Icons.insert_drive_file,
                    color: Colors.grey,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (status == 'draft')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Brouillon', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _formatPrice(price),
                    style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}