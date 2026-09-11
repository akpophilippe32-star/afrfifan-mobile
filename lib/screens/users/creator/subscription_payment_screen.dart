import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart'; // ✅ SDK Officiel
import '../../../theme/theme_notifier.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final String creatorId;
  final String creatorName;
  final String tierType; // 'premium', 'pro', ou 'product'
  final double price;
  final String? productId;

  const SubscriptionPaymentScreen({
    Key? key,
    required this.creatorId,
    required this.creatorName,
    required this.tierType,
    required this.price,
    this.productId,
  }) : super(key: key);

  @override
  State<SubscriptionPaymentScreen> createState() => _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // ✅ REMPLACE CECI PAR TA VRAIE CLÉ PUBLIQUE KKIA PAY
  final String kkiapayPublicKey = "72fc173fbe56f0f477e6bfcaa7349471c844e893"; 
  final bool isSandbox = false; // Mets 'true' pour tester, 'false' pour le vrai argent (Live)

  bool get _isProductMode => widget.tierType == 'product';

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
    final bool isPro = widget.tierType == 'pro';
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text(_isProductMode ? 'Finaliser l\'achat' : 'Finaliser l\'abonnement', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 RÉCAPITULATIF (Ton design original)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isPro ? LinearGradient(colors: isDark ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)] : [const Color(0xFFE5E7EB), const Color(0xFFF3F4F6)], begin: Alignment.topLeft, end: Alignment.bottomRight) : LinearGradient(colors: [cardColor, cardColor]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPro ? accentColor : borderColor, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isProductMode ? 'PRODUIT' : widget.tierType.toUpperCase(), style: TextStyle(color: isPro ? textColor : subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_isProductMode ? 'Achat auprès de ${widget.creatorName}' : 'Abonnement à ${widget.creatorName}', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${widget.price.toStringAsFixed(0)}', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                      Text(' FCFA', style: TextStyle(color: subTextColor, fontSize: 14)),
                      if (!_isProductMode) Text(' /mois', style: TextStyle(color: subTextColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ✅ BOUTON DE PAIEMENT OFFICIEL
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _launchKkiapayPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: accentTextColor,
                  disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Payer maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ✅ LOGIQUE DE PAIEMENT AVEC LE SDK OFFICIEL
  // ==========================================

  void _launchKkiapayPayment() {
    setState(() => _isLoading = true);

    // 1. Configuration du widget KkiaPay
    final kkiapay = KKiaPay(
      amount: widget.price.toInt(),
      apikey: kkiapayPublicKey,
      sandbox: isSandbox,
      phone: "", // L'utilisateur le rentrera dans le widget
      name: widget.creatorName,
      reason: _isProductMode ? 'Achat produit' : 'Abonnement ${widget.tierType}',
      data: _isProductMode ? widget.productId : widget.creatorId, // On passe l'ID pour le retrouver après
      theme: "#8B5CF6", // Couleur violette d'Afrifan
      countries: ["BJ", "CI", "SN", "TG"], // Ajoute les pays que tu cibles
      paymentMethods: ["momo", "card"],
      callback: _handleKkiapayCallback,
    );

    // 2. Ouvrir le widget de paiement
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => kkiapay),
    ).then((_) {
      setState(() => _isLoading = false);
    });
  }

  // 3. Gestion du résultat du paiement
  void _handleKkiapayCallback(Map<String, dynamic> response, BuildContext context) {
    setState(() => _isLoading = false);
    
    final status = response['status'];
    final transactionId = response['transactionId'];
    final customData = response['requestData']?['data']; // C'est notre creatorId ou productId

    if (status == 'SUCCESS') {
      // ✅ PAIEMENT RÉUSSI : On prévient notre backend pour mettre à jour la base de données
      _verifyAndConfirmPayment(transactionId, customData);
    } else if (status == 'CANCELLED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paiement annulé."), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec du paiement. Vérifiez votre solde."), backgroundColor: Colors.red),
      );
    }
  }

  // 4. Appel à notre Edge Function pour valider et enregistrer en base de données
  Future<void> _verifyAndConfirmPayment(String transactionId, String referenceId) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // On appelle notre Webhook/Fonction pour qu'il vérifie chez KkiaPay et mette à jour la BDD
      final response = await supabase.functions.invoke('kkiapay-webhook', body: {
        'transaction_id': transactionId,
        'user_id': currentUser.id,
        'type': _isProductMode ? 'product' : 'subscription',
        'reference_id': referenceId,
        'amount': widget.price,
      });

      if (response.data['success'] == true) {
        _showSuccessDialog();
      } else {
        throw Exception("Erreur de validation serveur");
      }
    } catch (e) {
      debugPrint('❌ Erreur validation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paiement effectué mais erreur de validation. Contactez le support."), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog() {
    final isDark = themeNotifier.value == ThemeMode.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text('Paiement réussi !', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          _isProductMode ? 'Vous avez acheté ce produit. Vous pouvez maintenant y accéder !' : 'Vous êtes maintenant abonné. Profitez du contenu exclusif !',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: Text('Super !', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}