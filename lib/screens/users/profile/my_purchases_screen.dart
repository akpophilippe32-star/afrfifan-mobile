import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
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
        final dir = await getApplicationDocumentsDirectory();
        final saveDir = Directory('${dir.path}/afrifan_purchases');

        final List<Map<String, dynamic>> enrichedPurchases = [];
        for (var purchase in response) {
          final product = purchase['digital_products'] as Map<String, dynamic>?;
          final title = product?['title'] ?? 'Produit inconnu';
          final fileUrl = product?['file_url'] as String?;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fichier non téléchargé. Redirection...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;

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
          'Mes achats',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: accentColor))
            : _purchases.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              color: isDark ? Colors.grey : Colors.grey.shade400,
                              size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun achat pour le moment',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Explorez les boutiques des créateurs pour acheter du contenu exclusif.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subTextColor, fontSize: 14),
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
                      return _buildPurchaseCard(
                        purchase,
                        isDark: isDark,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        accentColor: accentColor,
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildPurchaseCard(
    Map<String, dynamic> purchase, {
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardColor,
    required Color borderColor,
    required Color accentColor,
  }) {
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
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // ─── ICÔNE MÉDIA ───
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                // ✅ Fond accent très léger
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                mediaType == 'video'
                    ? Icons.video_library
                    : mediaType == 'image'
                        ? Icons.image
                        : Icons.insert_drive_file,
                // ✅ Icône accent (noire en clair / blanche en sombre)
                color: accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // ─── INFOS ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${amountPaid.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      // ✅ Prix accent
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isDownloaded ? Icons.check_circle : Icons.cloud_download,
                        // 🟢 Vert si dispo (état de succès), gris sinon
                        color: isDownloaded ? Colors.green : subTextColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDownloaded ? 'Disponible' : 'À télécharger',
                        style: TextStyle(
                          color: isDownloaded ? Colors.green : subTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── BOUTON ACTION ───
            Icon(
              isDownloaded ? Icons.play_circle_fill : Icons.download,
              // ✅ Icône accent (noire en clair / blanche en sombre)
              color: isDownloaded ? accentColor : subTextColor,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}