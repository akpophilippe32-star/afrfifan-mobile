import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kkiapay_flutter_sdk/kkiapay_flutter_sdk.dart'; // ✅ SDK Officiel Kkiapay
import '../../../theme/theme_notifier.dart';

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
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  double _selectedAmount = 0;
  bool _isLoading = false;

  String _selectedPaymentMethod = 'Orange Money';
  final List<String> _paymentMethods = ['Orange Money', 'MTN Mobile Money', 'Moov Money'];

  final List<double> _quickAmounts = [500, 1000, 2000, 5000];

  // ✅ REMPLACE CECI PAR TA VRAIE CLÉ PUBLIQUE KKIA PAY
  final String kkiapayPublicKey = "72fc173fbe56f0f477e6bfcaa7349471c844e893"; 
  final bool isSandbox = false; // Mets 'true' pour tester, 'false' pour le vrai argent (Live)

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

  // ==========================================
  // ✅ LOGIQUE DE PAIEMENT AVEC LE SDK OFFICIEL
  // ==========================================

  void _launchKkiapayPayment() {
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

    // 1. Configuration du widget KkiaPay pour le Pourboire
    final kkiapay = KKiaPay(
      amount: _selectedAmount.toInt(),
      apikey: kkiapayPublicKey,
      sandbox: isSandbox,
      phone: _phoneController.text.trim(),
      name: widget.creatorName,
      reason: 'Pourboire',
      data: widget.creatorId, // On passe le creatorId pour le retrouver après
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
    final customData = response['requestData']?['data']; // C'est notre creatorId

    if (status == 'SUCCESS') {
      // ✅ PAIEMENT RÉUSSI : On prévient notre backend pour enregistrer le tip en base de données
      _verifyAndConfirmTip(transactionId, customData);
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

  // 4. Appel à notre Edge Function pour valider et enregistrer le pourboire
  Future<void> _verifyAndConfirmTip(String transactionId, String creatorId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // On appelle notre Webhook/Fonction pour qu'il enregistre le tip
      final response = await Supabase.instance.client.functions.invoke('kkiapay-webhook', body: {
        'transaction_id': transactionId,
        'user_id': currentUser.id,
        'type': 'tip',
        'reference_id': creatorId,
        'amount': _selectedAmount,
      });

      if (response.data['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Pourboire de ${_selectedAmount.toInt()} FCFA envoyé avec succès !'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception("Erreur de validation serveur");
      }
    } catch (e) {
      debugPrint('❌ Erreur validation tip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paiement effectué mais erreur de validation. Contactez le support."), backgroundColor: Colors.red),
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
        return _buildDialog(isDark);
      },
    );
  }

  Widget _buildDialog(bool isDark) {
    final bool canSend = _selectedAmount > 0 && _phoneController.text.trim().length >= 8 && !_isLoading;

    final dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final hintColor = isDark ? Colors.grey : Colors.black38;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final disabledBtnBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final disabledBtnText = isDark ? Colors.grey.shade500 : Colors.black38;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_cafe, color: accentColor, size: 40),
              const SizedBox(height: 16),
              Text(
                'Soutenir ce créateur',
                style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'à ${widget.creatorName}',
                style: TextStyle(color: subTextColor, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // ─── 1. MONTANT ───
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onAmountChanged,
                style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: hintColor, fontSize: 28),
                  suffixText: 'FCFA',
                  suffixStyle: TextStyle(color: subTextColor, fontSize: 16),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── 2. SUGGESTIONS ───
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
                        color: isSelected ? accentColor : fieldBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? accentColor : Colors.transparent),
                      ),
                      child: Text(
                        '${amount.toInt()}',
                        style: TextStyle(
                          color: isSelected ? accentTextColor : subTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ─── 3. MOYEN DE PAIEMENT ───
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: InputDecoration(
                  labelText: 'Moyen de paiement',
                  labelStyle: TextStyle(color: subTextColor),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method, style: TextStyle(color: textColor)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPaymentMethod = value!);
                },
              ),
              const SizedBox(height: 16),

              // ─── 4. NUMÉRO ───
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: textColor),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Ton numéro Mobile Money',
                  labelStyle: TextStyle(color: subTextColor),
                  hintText: 'Ex: 07 07 07 07',
                  hintStyle: TextStyle(color: hintColor),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.phone, color: accentColor),
                ),
              ),
              const SizedBox(height: 16),

              // ─── 5. MESSAGE ───
              TextField(
                controller: _messageController,
                maxLines: 2,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Message d\'encouragement (optionnel)',
                  labelStyle: TextStyle(color: subTextColor),
                  filled: true,
                  fillColor: fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ─── 6. BOUTON ENVOYER ───
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSend ? _launchKkiapayPayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSend ? accentColor : disabledBtnBg,
                    foregroundColor: canSend ? accentTextColor : disabledBtnText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: accentTextColor, strokeWidth: 2),
                        )
                      : Text(
                          'Payer ${_selectedAmount.toInt()} FCFA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: canSend ? accentTextColor : disabledBtnText,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // ─── 7. ANNULER ───
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: TextStyle(color: subTextColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}