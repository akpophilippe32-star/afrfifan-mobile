import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'subscription_payment_screen.dart';
import 'product_viewer_screen.dart'; // ✅ L'écran qui lit le fichier en interne

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
  bool _isDownloaded = false; // ✅ Nouveau : vérifie si c'est déjà dans l'appli
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
      // 1. Vérifier l'achat
      final purchaseResponse = await supabase
          .from('product_purchases')
          .select('id')
          .eq('product_id', widget.product['id'])
          .eq('buyer_id', userId)
          .eq('payment_status', 'completed')
          .maybeSingle();

      if (purchaseResponse != null) {
        _hasPurchased = true;
        
        // 2. Récupérer l'URL pour pouvoir le télécharger si besoin
        final productResponse = await supabase
            .from('digital_products')
            .select('file_url')
            .eq('id', widget.product['id'])
            .maybeSingle();
        
        _fileUrl = productResponse?['file_url'];

        // 3. Vérifier si le fichier existe déjà localement
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

  Future<void> _handleAccessContent() async {
    // Si déjà téléchargé, on ouvre directement
    if (_isDownloaded && _localFilePath != null) {
      _openInternalViewer();
      return;
    }

    // Sinon, on lance le téléchargement
    if (!_hasPurchased || _fileUrl == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xFF1A1A1A),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                SizedBox(height: 16),
                Text('Téléchargement sécurisé...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Générer un lien temporaire (5 min suffit pour télécharger)
      final uri = Uri.parse(_fileUrl!);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('digital_products');
      String filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      final signedUrl = await supabase.storage
          .from('digital_products')
          .createSignedUrl(filePath, 300);

      // 2. Télécharger avec Dio dans le dossier privé de l'appli
      final dio = Dio();
      await dio.download(signedUrl, _localFilePath!);

      if (mounted) Navigator.pop(context); // Fermer le chargement

      setState(() => _isDownloaded = true);

      // 3. Ouvrir directement dans l'appli
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
    final title = widget.product['title'] as String? ?? 'Sans titre';
    final description = widget.product['description'] as String? ?? 'Aucune description.';
    final price = (widget.product['price'] as num?)?.toDouble() ?? 0;
    final mediaType = widget.product['media_type'] as String? ?? 'file';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Détail du produit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF1A1A1A),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getMediaTypeIcon(), size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text('Aperçu ${mediaType.toUpperCase()}', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                          if (!_hasPurchased) ...[
                            const SizedBox(height: 8),
                            const Icon(Icons.lock, color: Color(0xFF8B5CF6), size: 24),
                            const SizedBox(height: 4),
                            const Text('Contenu protégé', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                              child: Text(_formatPrice(price), style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Par @${widget.creatorName}', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        const Divider(color: Colors.grey, height: 32),
                        const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(description, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _hasPurchased ? _handleAccessContent : _goToPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasPurchased ? Colors.green : const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_hasPurchased ? (_isDownloaded ? Icons.play_circle : Icons.download) : Icons.shopping_cart, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  _hasPurchased 
                                      ? (_isDownloaded ? 'Ouvrir dans l\'application' : 'Télécharger dans l\'application')
                                      : 'Acheter maintenant',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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