import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final String creatorId;
  final String creatorName;
  final String tierType; // 'premium', 'pro', ou 'product'
  final double price;
  final String? productId; // ✅ NOUVEAU : ID du produit (si mode produit)

  const SubscriptionPaymentScreen({
    Key? key,
    required this.creatorId,
    required this.creatorName,
    required this.tierType,
    required this.price,
    this.productId, // ✅ Optionnel
  }) : super(key: key);

  @override
  State<SubscriptionPaymentScreen> createState() => _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  final supabase = Supabase.instance.client;
  
  String? _selectedPaymentMethod;
  String? _phoneNumber;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'mtn_momo', 'name': 'MTN Mobile Money', 'color': Color(0xFFFFCC00), 'icon': Icons.phone_android},
    {'id': 'orange_money', 'name': 'Orange Money', 'color': Color(0xFFFF6600), 'icon': Icons.phone_android},
    {'id': 'moov_money', 'name': 'Moov Money', 'color': Color(0xFF0066CC), 'icon': Icons.phone_android},
    {'id': 'wave', 'name': 'Wave', 'color': Color(0xFF00BFFF), 'icon': Icons.waves},
  ];

  bool get _isProductMode => widget.tierType == 'product';

  @override
  Widget build(BuildContext context) {
    final bool isPro = widget.tierType == 'pro';
    final Color brandViolet = const Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isProductMode ? 'Finaliser l\'achat' : 'Finaliser l\'abonnement',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 RÉCAPITULATIF
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isPro
                    ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF1A1A1A)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPro ? const Color(0xFF8B5CF6) : Colors.grey.shade800, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isProductMode ? 'PRODUIT' : widget.tierType.toUpperCase(),
                    style: TextStyle(
                      color: isPro ? Colors.white : brandViolet,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isProductMode 
                        ? 'Achat auprès de ${widget.creatorName}'
                        : 'Abonnement à ${widget.creatorName}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${widget.price.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        ' FCFA',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (!_isProductMode)
                        const Text(
                          ' /mois',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 💳 MÉTHODE DE PAIEMENT
            const Text(
              'Méthode de paiement',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._paymentMethods.map((method) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = method['id']),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedPaymentMethod == method['id'] 
                        ? const Color(0xFF8B5CF6).withOpacity(0.2) 
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedPaymentMethod == method['id'] 
                          ? const Color(0xFF8B5CF6) 
                          : const Color(0xFF2A2A2A),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: method['color'],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(method['icon'], color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          method['name'],
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_selectedPaymentMethod == method['id'])
                        const Icon(Icons.check_circle, color: Color(0xFF8B5CF6), size: 24),
                    ],
                  ),
                ),
              ),
            )),
            const SizedBox(height: 30),

            // 📱 NUMÉRO DE TÉLÉPHONE
            const Text(
              'Numéro Mobile Money',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                onChanged: (value) => _phoneNumber = value,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Ex: 97 XX XX XX',
                  hintStyle: TextStyle(color: Color(0xFF555555)),
                  prefixIcon: Icon(Icons.phone, color: Color(0xFF8B5CF6)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // ✅ BOUTON CONFIRMER
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_selectedPaymentMethod != null && _phoneNumber != null && !_isLoading) 
                    ? _processPayment 
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirmer le paiement',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Utilisateur non connecté.");

      // 1. Simuler un délai de traitement
      await Future.delayed(const Duration(seconds: 2));

      if (_isProductMode) {
        // ✅ MODE PRODUIT : Insérer dans product_purchases
        await supabase.from('product_purchases').insert({
          'product_id': widget.productId,
          'buyer_id': currentUser.id,
          'creator_id': widget.creatorId,
          'amount_paid': widget.price,
          'currency': 'XOF',
          'payment_status': 'completed',
          'payment_method': _selectedPaymentMethod,
          'purchase_date': DateTime.now().toIso8601String(),
        });
      } else {
        // ✅ MODE ABONNEMENT : Insérer dans subscriptions
        await supabase.from('subscriptions').insert({
          'fan_id': currentUser.id,
          'creator_id': widget.creatorId,
          'tier_type': widget.tierType,
          'amount_paid': widget.price,
          'start_date': DateTime.now().toIso8601String(),
          'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'status': 'active',
        });
      }

      // 2. Afficher le succès
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Paiement réussi !', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              _isProductMode 
                  ? 'Vous avez acheté ce produit. Vous pouvez maintenant y accéder !'
                  : 'Vous êtes maintenant abonné. Profitez du contenu exclusif !',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true); // ✅ Retourne true pour rafraîchir
                },
                child: const Text(
                  'Super !',
                  style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur paiement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}