import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'subscription_payment_screen.dart';
import 'product_viewer_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String creatorId;
  final String creatorName;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.creatorId,
    required this.creatorName,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _hasPurchased = false;
  bool _isDownloaded = false;
  String? _fileUrl;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _checkPurchaseAndDownloadStatus();
  }

  Future<void> _checkPurchaseAndDownloadStatus() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() { _isLoading = false; _hasPurchased = false; });
      return;
    }

    try {
      final purchaseResponse = await supabase
          .from('product_purchases')
          .select('id')
          .eq('product_id', widget.product['id'])
          .eq('buyer_id', userId)
          .eq('payment_status', 'completed')
          .maybeSingle();

      if (purchaseResponse != null) {
        _hasPurchased = true;

        final productResponse = await supabase
            .from('digital_products')
            .select('file_url')
            .eq('id', widget.product['id'])
            .maybeSingle();

        _fileUrl = productResponse?['file_url'];

        final dir = await getApplicationDocumentsDirectory();
        final saveDir = Directory('${dir.path}/afrifan_purchases');
        if (!await saveDir.exists()) await saveDir.create();

        final fileName = _fileUrl!.split('/').last;
        _localFilePath = '${saveDir.path}/$fileName';

        final file = File(_localFilePath!);
        _isDownloaded = await file.exists();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Erreur vérification: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccessContent(bool isDark) async {
    if (_isDownloaded && _localFilePath != null) {
      _openInternalViewer();
      return;
    }

    if (!_hasPurchased || _fileUrl == null) return;

    final dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: dialogBg,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accentColor),
                const SizedBox(height: 16),
                Text('Téléchargement sécurisé...', style: TextStyle(color: textColor)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final uri = Uri.parse(_fileUrl!);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('digital_products');
      String filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      final signedUrl = await supabase.storage
          .from('digital_products')
          .createSignedUrl(filePath, 300);

      final dio = Dio();
      await dio.download(signedUrl, _localFilePath!);

      if (mounted) Navigator.pop(context);

      setState(() => _isDownloaded = true);

      _openInternalViewer();

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('❌ Erreur téléchargement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec du téléchargement: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openInternalViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductViewerScreen(
          localFilePath: _localFilePath!,
          mediaType: widget.product['media_type'] ?? 'file',
          title: widget.product['title'] ?? 'Produit',
        ),
      ),
    );
  }

  String _formatPrice(double price) => '${price.toStringAsFixed(0)} FCFA';

  IconData _getMediaTypeIcon() {
    final type = widget.product['media_type'] as String? ?? 'file';
    switch (type) {
      case 'video': return Icons.video_library;
      case 'image': return Icons.image;
      case 'audio': return Icons.audio_file;
      default: return Icons.insert_drive_file;
    }
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
    final title = widget.product['title'] as String? ?? 'Sans titre';
    final description = widget.product['description'] as String? ?? 'Aucune description.';
    final price = (widget.product['price'] as num?)?.toDouble() ?? 0;
    final mediaType = widget.product['media_type'] as String? ?? 'file';

    // ✅ Couleurs adaptatives
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final previewBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final detailsBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final iconGrey = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Détail du produit',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : Column(
              children: [
                // ─── APERÇU (top) ───
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    color: previewBg,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getMediaTypeIcon(), size: 64, color: iconGrey),
                          const SizedBox(height: 16),
                          Text(
                            'Aperçu ${mediaType.toUpperCase()}',
                            style: TextStyle(color: subTextColor, fontSize: 14),
                          ),
                          if (!_hasPurchased) ...[
                            const SizedBox(height: 8),
                            // ✅ Cadenas neutre adaptatif
                            Icon(Icons.lock, color: accentColor, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              'Contenu protégé',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── DÉTAILS (bottom) ───
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: detailsBg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                // ✅ Badge prix : fond neutre adaptatif
                                color: accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatPrice(price),
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Par @${widget.creatorName}',
                          style: TextStyle(color: subTextColor, fontSize: 14),
                        ),
                        Divider(color: dividerColor, height: 32),
                        Text(
                          'Description',
                          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              description,
                              style: TextStyle(color: subTextColor, fontSize: 14, height: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _hasPurchased
                                ? () => _handleAccessContent(isDark)
                                : _goToPayment,
                            style: ElevatedButton.styleFrom(
                              // ✅ Bouton achat : noir en clair / blanc en sombre
                              // ✅ Bouton déjà acheté : vert conservé (convention "action positive")
                              backgroundColor: _hasPurchased ? Colors.green : accentColor,
                              foregroundColor: _hasPurchased ? Colors.white : accentTextColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _hasPurchased
                                      ? (_isDownloaded ? Icons.play_circle : Icons.download)
                                      : Icons.shopping_cart,
                                  size: 24,
                                  color: _hasPurchased ? Colors.white : accentTextColor,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _hasPurchased
                                      ? (_isDownloaded ? 'Ouvrir dans l\'application' : 'Télécharger dans l\'application')
                                      : 'Acheter maintenant',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _hasPurchased ? Colors.white : accentTextColor,
                                  ),
                                ),
                              ],
                            ),
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

  void _goToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPaymentScreen(
          creatorId: widget.creatorId,
          creatorName: widget.creatorName,
          tierType: 'product',
          price: (widget.product['price'] as num?)?.toDouble() ?? 0,
          productId: widget.product['id'] as String,
        ),
      ),
    ).then((success) {
      if (success == true) _checkPurchaseAndDownloadStatus();
    });
  }
}