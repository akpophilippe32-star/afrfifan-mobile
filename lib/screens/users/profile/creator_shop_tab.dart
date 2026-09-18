import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart';
import 'create_product_screen.dart';
import 'edit_product_screen.dart';

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

  // ═══════════════════════════════════════════
  // SUPPRESSION RÉELLE DU PRODUIT
  // ═══════════════════════════════════════════
  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = product['id'] as String;
    final previewUrl = product['preview_url'] as String?;
    final fileUrl = product['file_url'] as String?;

    setState(() => _isLoading = true);

    try {
      // 1. Supprimer les fichiers du storage
      final storageUrls = [previewUrl, fileUrl].whereType<String>().toList();
      for (final url in storageUrls) {
        try {
          final filePath = _extractFilePathFromUrl(url);
          if (filePath != null) {
            await Supabase.instance.client.storage.from('post-media').remove([filePath]);
            debugPrint('🗑️ Fichier supprimé du storage: $filePath');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur suppression fichier: $e');
        }
      }

      // 2. Supprimer les achats associés
      await Supabase.instance.client
          .from('product_purchases')
          .delete()
          .eq('product_id', productId);

      // 3. Supprimer le produit
      await Supabase.instance.client
          .from('digital_products')
          .delete()
          .eq('id', productId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Produit supprimé avec succès'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        await _loadProducts();
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression produit: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  String? _extractFilePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('post-media');
      if (bucketIndex == -1) return null;
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      return filePath.isNotEmpty ? filePath : null;
    } catch (e) {
      return null;
    }
  }

  void _confirmDelete(Map<String, dynamic> product, bool isDark) {
    final title = product['title'] as String? ?? 'ce produit';
    final dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Supprimer le produit',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer :',
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '"$title"',
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette action est irréversible. Les achats déjà effectués ne seront pas remboursés.',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProduct(product);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // MENU DES ACTIONS (3 POINTS)
  // ═══════════════════════════════════════════
  void _showProductMenu(Map<String, dynamic> product, bool isDark) {
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final handleColor = isDark ? const Color(0xFF3F3F3F) : const Color(0xFFD1D5DB);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit, color: accentTextColor, size: 20),
                ),
                title: Text(
                  'Modifier le produit',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Modifier le titre, prix, description...',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProductScreen(product: product),
                    ),
                  );
                  if (result == true) _loadProducts();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
                ),
                title: Text(
                  'Supprimer le produit',
                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Supprimer définitivement',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(product, isDark);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
            childAspectRatio: 0.72,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            final product = _products[index];
            return _buildProductCard(product, isDark);
          },
        ),
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
    final previewUrl = product['preview_url'] as String?;

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
          color: status == 'published' ? borderColor : Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone miniature avec bouton menu
          Expanded(
            flex: 3,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    width: double.infinity,
                    color: mediaBg,
                    child: previewUrl != null && previewUrl.isNotEmpty
                        ? Image.network(
                            previewUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Center(
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
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(color: accentColor, strokeWidth: 2),
                              );
                            },
                          )
                        : Center(
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
                // Badge de statut en haut à gauche
                if (status == 'draft')
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Brouillon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // ✅ Bouton menu (3 points) en haut à droite
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showProductMenu(product, isDark),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Zone informations
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatPrice(price),
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          mediaType == 'video'
                              ? Icons.play_circle_fill
                              : mediaType == 'image'
                                  ? Icons.image
                                  : Icons.description,
                          color: accentColor,
                          size: 14,
                        ),
                      ),
                    ],
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