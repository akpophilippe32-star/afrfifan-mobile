import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT

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

  String? _selectedPaymentMethod;
  String? _phoneNumber;
  bool _isLoading = false;

  // ✅ Couleurs des opérateurs conservées (identité visuelle de marque)
  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'mtn_momo', 'name': 'MTN Mobile Money', 'color': Color(0xFFFFCC00), 'icon': Icons.phone_android},
    {'id': 'orange_money', 'name': 'Orange Money', 'color': Color(0xFFFF6600), 'icon': Icons.phone_android},
    {'id': 'moov_money', 'name': 'Moov Money', 'color': Color(0xFF0066CC), 'icon': Icons.phone_android},
    {'id': 'wave', 'name': 'Wave', 'color': Color(0xFF00BFFF), 'icon': Icons.waves},
  ];

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isProductMode ? 'Finaliser l\'achat' : 'Finaliser l\'abonnement',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
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
                // ✅ Plus de gradient violet → noir en clair / gris foncé en sombre
                gradient: isPro
                    ? LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                            : [const Color(0xFFE5E7EB), const Color(0xFFF3F4F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(colors: [cardColor, cardColor]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPro ? accentColor : borderColor,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isProductMode ? 'PRODUIT' : widget.tierType.toUpperCase(),
                    style: TextStyle(
                      color: isPro ? textColor : subTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isProductMode
                        ? 'Achat auprès de ${widget.creatorName}'
                        : 'Abonnement à ${widget.creatorName}',
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${widget.price.toStringAsFixed(0)}',
                        style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        ' FCFA',
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                      if (!_isProductMode)
                        Text(
                          ' /mois',
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 💳 MÉTHODE DE PAIEMENT
            Text(
              'Méthode de paiement',
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._paymentMethods.map((method) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = method['id']),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // ✅ Sélection : fond accent très léger
                    color: _selectedPaymentMethod == method['id']
                        ? accentColor.withOpacity(0.12)
                        : cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedPaymentMethod == method['id']
                          ? accentColor
                          : borderColor,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          // ✅ Couleur de marque de l'opérateur (identité visuelle)
                          color: method['color'],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(method['icon'], color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          method['name'],
                          style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_selectedPaymentMethod == method['id'])
                        Icon(Icons.check_circle, color: accentColor, size: 24),
                    ],
                  ),
                ),
              ),
            )),
            const SizedBox(height: 30),

            // 📱 NUMÉRO DE TÉLÉPHONE
            Text(
              'Numéro Mobile Money',
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                onChanged: (value) => _phoneNumber = value,
                style: TextStyle(color: textColor),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ex: 97 XX XX XX',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF555555) : Colors.black38),
                  prefixIcon: Icon(Icons.phone, color: subTextColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  // ✅ Bouton actif : noir en clair / blanc en sombre
                  backgroundColor: accentColor,
                  foregroundColor: accentTextColor,
                  disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: accentTextColor)
                    : Text(
                        'Confirmer le paiement',
                        style: TextStyle(
                          color: accentTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

      await Future.delayed(const Duration(seconds: 2));

      if (_isProductMode) {
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

      if (mounted) {
        final isDark = themeNotifier.value == ThemeMode.dark;
        final dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final accentColor = isDark ? Colors.white : Colors.black;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Text('Paiement réussi !', style: TextStyle(color: textColor)),
              ],
            ),
            content: Text(
              _isProductMode
                  ? 'Vous avez acheté ce produit. Vous pouvez maintenant y accéder !'
                  : 'Vous êtes maintenant abonné. Profitez du contenu exclusif !',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  'Super !',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
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