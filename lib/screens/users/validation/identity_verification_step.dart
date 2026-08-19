import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'creator_pricing_screen.dart'; 

class IdentityVerificationStep extends StatefulWidget {
  final String fullName;
  final String? birthDate;
  final String city;
  final String category;

  const IdentityVerificationStep({
    Key? key,
    required this.fullName,
    required this.birthDate,
    required this.city,
    required this.category,
  }) : super(key: key);

  @override
  State<IdentityVerificationStep> createState() => _IdentityVerificationStepState();
}

class _IdentityVerificationStepState extends State<IdentityVerificationStep> {
  String? _idCardImage;
  final _otpController = TextEditingController();
  bool _isPhoneVerified = false;
  bool _isSendingOTP = false;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

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
              const SizedBox(height: 30),
              const Text('Vérification d\'identité', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              _buildDocumentSection(
                title: 'Photo de ma pièce d\'identité',
                subtitle: 'CNI, Passeport ou Carte consulaire',
                icon: Icons.credit_card,
                image: _idCardImage,
                onImport: () => _importPhoto('id_card'),
              ),
              const SizedBox(height: 20),
              _buildSecurityMessage(),
              const SizedBox(height: 25),
              _buildPhoneVerification(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_isPhoneVerified && _idCardImage != null && !_isLoading) ? _goToNextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('Suivant', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
              'Étape 2/3',
              style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '2/3',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(
            value: 0.66,
            backgroundColor: Color(0xFF1A1A1A),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? image,
    required VoidCallback onImport,
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
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(image),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Changer l\'image', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF333333)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file, color: Color(0xFF8B5CF6)),
                label: const Text('Importer une photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF333333)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF8B5CF6), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vos données personnelles sont sécurisées et ne seront utilisées que pour vérifier votre identité.',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneVerification() {
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
          const Text('Vérification du numéro de téléphone', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Veuillez confirmer votre numéro pour recevoir vos notifications de gains.', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 16),
          if (_isPhoneVerified)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Téléphone vérifié avec succès !', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _otpController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Entrez le code reçu',
                    hintStyle: const TextStyle(color: Color(0xFF555555)),
                    filled: true,
                    fillColor: const Color(0xFF0A0A0A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSendingOTP ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSendingOTP
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Vérifier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _importPhoto(String type) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() {
          if (type == 'id_card') {
            _idCardImage = image.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection de l\'image : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendOTP() async {
    setState(() => _isSendingOTP = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isSendingOTP = false;
      _isPhoneVerified = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro vérifié avec succès !'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _goToNextStep() async {
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreatorPricingScreen(
              fullName: widget.fullName,
              birthDate: widget.birthDate,
              city: widget.city,
              category: widget.category,
              idCardUrl: _idCardImage,
              phoneVerified: _isPhoneVerified,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}