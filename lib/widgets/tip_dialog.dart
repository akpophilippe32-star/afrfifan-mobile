import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/dashboard_service.dart'; // Ajuste le chemin si besoin

class TipDialog extends StatefulWidget {
  final String creatorId;
  final String creatorName;

  const TipDialog({
    required this.creatorId,
    required this.creatorName,
    super.key,
  });

  @override
  State<TipDialog> createState() => _TipDialogState();
}

class _TipDialogState extends State<TipDialog> {
  final DashboardService _dashboardService = DashboardService();
  
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  
  double _selectedAmount = 0;
  bool _isLoading = false;
  
  // Moyens de paiement Mobile Money
  String _selectedPaymentMethod = 'Orange Money';
  final List<String> _paymentMethods = ['Orange Money', 'MTN Mobile Money', 'Moov Money'];
  
  // Suggestions de montants
  final List<double> _quickAmounts = [500, 1000, 2000, 5000];

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toInt().toString();
    });
  }

  void _onAmountChanged(String value) {
    final parsed = double.tryParse(value);
    setState(() {
      _selectedAmount = parsed ?? 0;
    });
  }

  Future<void> _sendTip() async {
    // 1. Validations
    if (_selectedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_phoneController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numéro de téléphone valide'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final fanId = Supabase.instance.client.auth.currentUser?.id;
    if (fanId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // 2. Appel au service backend
    final success = await _dashboardService.sendTip(
      fanId: fanId,
      fanPhoneNumber: _phoneController.text.trim(),
      paymentMethod: _selectedPaymentMethod,
      creatorId: widget.creatorId,
      amount: _selectedAmount,
      message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
    );

    // 3. Gestion du résultat
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Pourboire de ${_selectedAmount.toInt()} FCFA envoyé via $_selectedPaymentMethod !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Échec de l\'envoi. Vérifiez votre connexion.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le bouton est actif si le montant > 0 et le téléphone n'est pas vide
    final bool canSend = _selectedAmount > 0 && _phoneController.text.trim().length >= 8 && !_isLoading;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView( // Ajouté au cas où le clavier masque le bas
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_cafe, color: Color(0xFF8B5CF6), size: 40),
              const SizedBox(height: 16),
              const Text(
                'Soutenir ce créateur',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'à ${widget.creatorName}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              // 1. CHAMP DE SAISIE DU MONTANT
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onAmountChanged,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 28),
                  suffixText: 'FCFA',
                  suffixStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide.none
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 2. SUGGESTIONS RAPIDES
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _quickAmounts.map((amount) {
                  final isSelected = _selectedAmount == amount;
                  return InkWell(
                    onTap: () => _setAmount(amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent),
                      ),
                      child: Text(
                        '${amount.toInt()}',
                        style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              // 3. MOYEN DE PAIEMENT (Mobile Money)
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: InputDecoration(
                  labelText: 'Moyen de paiement',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                dropdownColor: const Color(0xFF2A2A2A),
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPaymentMethod = value!);
                },
              ),
              const SizedBox(height: 16),
              
              // 4. NUMÉRO DE TÉLÉPHONE
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ton numéro Mobile Money',
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintText: 'Ex: 07 07 07 07',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(height: 16),
              
              // 5. MESSAGE OPTIONNEL
              TextField(
                controller: _messageController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Message d\'encouragement (optionnel)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              
              // 6. BOUTON D'ENVOI
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSend ? _sendTip : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSend ? const Color(0xFF8B5CF6) : Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Payer ${_selectedAmount.toInt()} FCFA', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}