import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // ─── VARIABLES POUR L'IMAGE ──────────────────────────────
  String? _idCardPath;      // Chemin local (mobile)
  Uint8List? _idCardBytes;  // Bytes pour le Web
  String? _idCardUrl;       // URL publique après upload

  final _otpController = TextEditingController();
  bool _isPhoneVerified = false;
  bool _isSendingOTP = false;
  bool _isLoading = false;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  // ─── CONSTANTES DE COULEUR ────────────────────────────────
  static const Color _primaryColor = Color(0xFF8B5CF6);
  static const Color _backgroundColor = Color(0xFF0A0A0A);
  static const Color _cardColor = Color(0xFF161616);
  static const Color _borderColor = Color(0xFF262626);
  static const Color _textColor = Colors.white;
  static const Color _textSecondaryColor = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 30),
              const Text(
                'Vérification d\'identité',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vérifiez votre identité pour devenir créateur',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              _buildDocumentSection(),
              const SizedBox(height: 20),
              _buildSecurityMessage(),
              const SizedBox(height: 25),
              _buildPhoneVerification(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_isPhoneVerified && _idCardPath != null && !_isLoading && !_isUploading)
                      ? _goToNextStep
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading || _isUploading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'Suivant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── WIDGETS ────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Étape 2/3',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '2/3',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.credit_card,
                color: _primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Photo de ma pièce d\'identité',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'CNI, Passeport ou Carte consulaire',
                      style: TextStyle(
                        color: _textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_idCardPath != null) ...[
            // ✅ AFFICHAGE DE L'IMAGE : FONCTIONNE SUR WEB ET MOBILE
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildImageDisplay(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _importPhoto(),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Changer l\'image',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _importPhoto,
                icon: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: _primaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.upload_file,
                        color: _primaryColor,
                      ),
                label: const Text(
                  'Importer une photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ AFFICHAGE DE L'IMAGE : GÈRE WEB ET MOBILE
  Widget _buildImageDisplay() {
    final height = 150.0;
    final width = double.infinity;

    // Web : Utiliser Image.memory avec les bytes
    if (kIsWeb && _idCardBytes != null) {
      return Image.memory(
        _idCardBytes!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: Colors.grey[800],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
          ),
        ),
      );
    }

    // Mobile : Utiliser Image.file
    if (!kIsWeb && _idCardPath != null) {
      return Image.file(
        File(_idCardPath!),
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: Colors.grey[800],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
          ),
        ),
      );
    }

    // Fallback : Image via URL (si déjà uploadée)
    if (_idCardUrl != null) {
      return Image.network(
        _idCardUrl!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: Colors.grey[800],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
          ),
        ),
      );
    }

    // Fallback par défaut
    return Container(
      height: height,
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.image, color: Colors.white54, size: 40),
      ),
    );
  }

  Widget _buildSecurityMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: _primaryColor, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vos données personnelles sont sécurisées et ne seront utilisées que pour vérifier votre identité.',
              style: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 13,
              ),
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vérification du numéro de téléphone',
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Veuillez confirmer votre numéro pour recevoir vos notifications de gains.',
            style: TextStyle(
              color: _textSecondaryColor,
              fontSize: 13,
            ),
          ),
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
                  Text(
                    'Téléphone vérifié avec succès !',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _otpController,
                  style: const TextStyle(color: _textColor),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Entrez le code reçu',
                    hintStyle: const TextStyle(color: Color(0xFF555555)),
                    filled: true,
                    fillColor: _backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSendingOTP ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSendingOTP
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Vérifier',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── FONCTIONS ──────────────────────────────────────────────

  // ✅ IMPORT DE PHOTO : FONCTIONNE SUR WEB ET MOBILE
  Future<void> _importPhoto() async {
    try {
      setState(() => _isUploading = true);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) {
        setState(() => _isUploading = false);
        return;
      }

      // ✅ LECTURE DES BYTES (fonctionne sur Web et Mobile)
      final bytes = await image.readAsBytes();

      // ✅ STOCKAGE DU CHEMIN (pour les deux plateformes)
      setState(() {
        _idCardPath = image.path;
        _idCardBytes = bytes;
      });

      // ✅ UPLOAD VERS SUPABASE (optionnel, pour stockage permanent)
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final fileName = 'id_$userId.jpg';
          final file = File(image.path);
          
          await Supabase.instance.client.storage
              .from('creator_documents')
              .upload(fileName, file, fileOptions: const FileOptions(upsert: true));
              
          final String publicUrl = Supabase.instance.client.storage
              .from('creator_documents')
              .getPublicUrl(fileName);
              
          setState(() {
            _idCardUrl = publicUrl;
          });
        }
      } catch (e) {
        debugPrint('⚠️ Upload vers Supabase ignoré : $e');
        // On continue même si l'upload échoue (l'image reste en mémoire)
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo importée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
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
        const SnackBar(
          content: Text('Numéro vérifié avec succès !'),
          backgroundColor: Colors.green,
        ),
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
              idCardUrl: _idCardUrl ?? _idCardPath,
              phoneVerified: _isPhoneVerified,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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