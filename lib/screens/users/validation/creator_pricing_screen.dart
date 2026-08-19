import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment_info_step.dart'; // ✅ On va vers l'étape de paiement maintenant

class CreatorPricingScreen extends StatefulWidget {
  // ✅ On reçoit les données des étapes 1 et 2
  final String fullName;
  final String? birthDate;
  final String city;
  final String category;
  final String? idCardUrl;
  final bool phoneVerified;

  const CreatorPricingScreen({
    Key? key,
    required this.fullName,
    required this.birthDate,
    required this.city,
    required this.category,
    required this.idCardUrl,
    required this.phoneVerified,
  }) : super(key: key);

  @override
  State<CreatorPricingScreen> createState() => _CreatorPricingScreenState();
}

class _CreatorPricingScreenState extends State<CreatorPricingScreen> {
  final supabase = Supabase.instance.client;
  
  final List<Map<String, dynamic>> _currencies = [
    {'code': 'XOF', 'symbol': 'FCFA', 'name': 'Franc CFA', 'rate': 1.0},
    {'code': 'XAF', 'symbol': 'FCFA', 'name': 'Franc CFA (CEMAC)', 'rate': 1.0},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'rate': 0.00152}, 
    {'code': 'USD', 'symbol': '\$', 'name': 'Dollar US', 'rate': 0.00165}, 
    {'code': 'GBP', 'symbol': '£', 'name': 'Livre Sterling', 'rate': 0.00129},
  ];

  String _selectedCurrencyCode = 'XOF';
  Map<String, dynamic> get _currentCurrency => _currencies.firstWhere((c) => c['code'] == _selectedCurrencyCode);

  final TextEditingController _premiumPriceController = TextEditingController();
  final TextEditingController _proPriceController = TextEditingController();
  
  bool _isLoading = false;

  static const int _premiumMinFCFA = 90;
  static const int _premiumMaxFCFA = 2000;
  static const int _proMinFCFA = 2001;
  static const int _proMaxFCFA = 10000;

double _convertToCurrency(int fcfaAmount) => (fcfaAmount * _currentCurrency['rate']).toDouble();
  int _convertToFCFA(double amount) => (amount / _currentCurrency['rate']).round();

  String _getPremiumMin() => _convertToCurrency(_premiumMinFCFA).toStringAsFixed(2);
  String _getPremiumMax() => _convertToCurrency(_premiumMaxFCFA).toStringAsFixed(2);
  String _getProMin() => _convertToCurrency(_proMinFCFA).toStringAsFixed(2);
  String _getProMax() => _convertToCurrency(_proMaxFCFA).toStringAsFixed(2);

  bool _validatePrices() {
    final premiumPrice = double.tryParse(_premiumPriceController.text);
    final proPrice = double.tryParse(_proPriceController.text);
    if (premiumPrice == null || proPrice == null) return false;

    if (premiumPrice < double.parse(_getPremiumMin()) || premiumPrice > double.parse(_getPremiumMax())) return false;
    if (proPrice < double.parse(_getProMin()) || proPrice > double.parse(_getProMax())) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 24),
              const Text(
                'Définissez vos tarifs',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choisissez combien vos abonnés paieront pour accéder à vos contenus exclusifs.',
                style: TextStyle(color: Color(0xFF888888), fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildCurrencySelector(),
              const SizedBox(height: 24),
              _buildTierCard(
                title: 'Niveau Premium',
                description: 'Accès aux publications standards et aux lives réservés.',
                controller: _premiumPriceController,
                minText: _getPremiumMin(),
                maxText: _getPremiumMax(),
              ),
              const SizedBox(height: 20),
              _buildTierCard(
                title: 'Niveau Pro / VIP',
                description: 'Accès total à tout le contenu, messagerie privée et avantages exclusifs.',
                controller: _proPriceController,
                minText: _getProMin(),
                maxText: _getProMax(),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePricing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Text(
                          'Continuer vers le paiement',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tarification des abonnements',
              style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Étape 3/3',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(
            value: 0.85,
            backgroundColor: Color(0xFF1A1A1A),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Devise :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          DropdownButton<String>(
            value: _selectedCurrencyCode,
            dropdownColor: const Color(0xFF161616),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8B5CF6)),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: _currencies.map((curr) {
              return DropdownMenuItem<String>(
                value: curr['code'],
                child: Text('${curr['name']} (${curr['symbol']})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedCurrencyCode = val;
                  _premiumPriceController.clear();
                  _proPriceController.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String title,
    required String description,
    required TextEditingController controller,
    required String minText,
    required String maxText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Recommandé : $minText - $maxText',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              labelText: 'Prix par mois (${_currentCurrency['symbol']})',
              labelStyle: const TextStyle(color: Color(0xFF8B5CF6)),
              helperText: 'Plage autorisée : $minText à $maxText ${_currentCurrency['symbol']}',
              helperStyle: const TextStyle(color: Color(0xFF666666), fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF0A0A0A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MODIFIÉ : Plus d'update Supabase, on passe les données calculées à l'étape de paiement
  Future<void> _savePricing() async {
    if (!_validatePrices()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Les prix doivent être entre ${_getPremiumMin()} et ${_getPremiumMax()} ${_currentCurrency['symbol']} pour Premium, et entre ${_getProMin()} et ${_getProMax()} ${_currentCurrency['symbol']} pour Pro'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // On convertit en FCFA pour la base de données
      final premiumPriceFCFA = _convertToFCFA(double.parse(_premiumPriceController.text));
      final proPriceFCFA = _convertToFCFA(double.parse(_proPriceController.text));

      await Future.delayed(const Duration(milliseconds: 500)); // Simulation UX

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentInfoStep(
              // ✅ On transmet TOUT le paquet de données à l'écran de paiement
              fullName: widget.fullName,
              birthDate: widget.birthDate,
              city: widget.city,
              category: widget.category,
              idCardUrl: widget.idCardUrl,
              phoneVerified: widget.phoneVerified,
              premiumPrice: premiumPriceFCFA.toDouble(),
              proPrice: proPriceFCFA.toDouble(),
              currency: _selectedCurrencyCode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _premiumPriceController.dispose();
    _proPriceController.dispose();
    super.dispose();
  }
}