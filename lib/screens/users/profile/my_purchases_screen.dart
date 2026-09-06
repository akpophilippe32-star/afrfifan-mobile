import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../creator/product_viewer_screen.dart';
import '../creator/product_detail_screen.dart';

class MyPurchasesScreen extends StatefulWidget {
  const MyPurchasesScreen({super.key});

  @override
  State<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends State<MyPurchasesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('product_purchases')
          .select('''
            id,
            product_id,
            amount_paid,
            payment_status,
            digital_products (
              id,
              title,
              media_type,
              file_url
            )
          ''')
          .eq('buyer_id', userId)
          .eq('payment_status', 'completed')
          .order('purchase_date', ascending: false);

      if (mounted) {
        // Vérifier pour chaque achat si le fichier est déjà téléchargé localement
        final dir = await getApplicationDocumentsDirectory();
        final saveDir = Directory('${dir.path}/afrifan_purchases');
        
        final List<Map<String, dynamic>> enrichedPurchases = [];
        for (var purchase in response) {
          final product = purchase['digital_products'] as Map<String, dynamic>?;
          final title = product?['title'] ?? 'Produit inconnu';
          final fileUrl = product?['file_url'] as String?;
          
          // Vérifier si le fichier existe localement
          bool isDownloaded = false;
          if (fileUrl != null) {
            final fileName = fileUrl.split('/').last;
            final localPath = '${saveDir.path}/$fileName';
            isDownloaded = File(localPath).existsSync();
          }
          
          enrichedPurchases.add({
            ...purchase,
            'product_title': title,
            'media_type': product?['media_type'] ?? 'file',
            'file_url': fileUrl,
            'is_downloaded': isDownloaded,
          });
        }

        setState(() {
          _purchases = enrichedPurchases;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement achats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openProduct(Map<String, dynamic> purchase) async {
    final productId = purchase['product_id'] as String;
    final title = purchase['product_title'] as String;
    final mediaType = purchase['media_type'] as String;
    final fileUrl = purchase['file_url'] as String?;
    final isDownloaded = purchase['is_downloaded'] as bool;

    if (isDownloaded && fileUrl != null) {
      // ✅ Fichier déjà téléchargé, l'ouvrir directement
      final dir = await getApplicationDocumentsDirectory();
      final fileName = fileUrl.split('/').last;
      final localPath = '${dir.path}/afrifan_purchases/$fileName';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductViewerScreen(
            localFilePath: localPath,
            mediaType: mediaType,
            title: title,
          ),
        ),
      );
    } else {
      //  Fichier non téléchargé, rediriger vers la page de détail
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fichier non téléchargé. Redirection...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      // Récupérer les infos complètes du produit pour la page de détail
      final productResponse = await supabase
          .from('digital_products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();

      if (mounted && productResponse != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: productResponse,
              creatorId: productResponse['creator_id'] ?? '',
              creatorName: 'Créateur',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mes achats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
            : _purchases.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun achat pour le moment',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explorez les boutiques des créateurs pour acheter du contenu exclusif.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _purchases.length,
                    itemBuilder: (context, index) {
                      final purchase = _purchases[index];
                      final title = purchase['product_title'] as String;
                      final mediaType = purchase['media_type'] as String;
                      final amountPaid = (purchase['amount_paid'] as num?)?.toDouble() ?? 0;
                      final isDownloaded = purchase['is_downloaded'] as bool;

                      return GestureDetector(
                        onTap: () => _openProduct(purchase),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  mediaType == 'video' ? Icons.video_library :
                                  mediaType == 'image' ? Icons.image :
                                  Icons.insert_drive_file,
                                  color: const Color(0xFF8B5CF6),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${amountPaid.toStringAsFixed(0)} FCFA',
                                      style: const TextStyle(
                                        color: Color(0xFF8B5CF6),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          isDownloaded ? Icons.check_circle : Icons.cloud_download,
                                          color: isDownloaded ? Colors.green : Colors.grey,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isDownloaded ? 'Disponible' : 'À télécharger',
                                          style: TextStyle(
                                            color: isDownloaded ? Colors.green : Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isDownloaded ? Icons.play_circle_fill : Icons.download,
                                color: isDownloaded ? const Color(0xFF8B5CF6) : Colors.grey,
                                size: 32,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}