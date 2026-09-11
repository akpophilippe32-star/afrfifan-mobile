import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'create_product_screen.dart';

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
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
                  // ✅ Fond neutre au lieu de violet
                  color: accentColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.store, color: accentColor, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Votre boutique est vide',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Commencez à vendre vos créations numériques dès maintenant.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, fontSize: 14),
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
                icon: Icon(Icons.add, size: 20, color: accentTextColor),
                label: Text(
                  'Ajouter mon premier produit',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accentTextColor),
                ),
                style: ElevatedButton.styleFrom(
                  // ✅ Bouton : noir en clair / blanc en sombre
                  backgroundColor: accentColor,
                  foregroundColor: accentTextColor,
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
            return _buildProductCard(product, isDark);
          },
        ),
        // Bouton flottant
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
            // ✅ FAB : noir en clair / blanc en sombre
            backgroundColor: accentColor,
            icon: Icon(Icons.add, color: accentTextColor),
            label: Text(
              'Nouveau',
              style: TextStyle(color: accentTextColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    final title = product['title'] as String? ?? 'Sans titre';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final mediaType = product['media_type'] as String? ?? 'file';
    final status = product['status'] as String? ?? 'draft';

    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black45;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final mediaBg = isDark ? Colors.grey.shade900 : Colors.grey.shade200;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'published'
              ? borderColor
              : Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color: mediaBg,
                child: Center(
                  child: Icon(
                    mediaType == 'video'
                        ? Icons.video_library
                        : mediaType == 'image'
                            ? Icons.image
                            : Icons.insert_drive_file,
                    color: subTextColor,
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
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (status == 'draft')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Brouillon',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _formatPrice(price),
                    style: TextStyle(
                      // ✅ Prix : noir en clair / blanc en sombre
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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