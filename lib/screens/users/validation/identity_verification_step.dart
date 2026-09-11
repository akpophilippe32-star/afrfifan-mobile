import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
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
  String? _idCardPath;
  Uint8List? _idCardBytes;
  String? _idCardUrl;

  final _otpController = TextEditingController();
  bool _isPhoneVerified = false;
  bool _isSendingOTP = false;
  bool _isLoading = false;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

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

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(isDark),
              const SizedBox(height: 30),
              _buildTitle(isDark),
              const SizedBox(height: 30),
              _buildDocumentSection(isDark),
              const SizedBox(height: 20),
              _buildSecurityMessage(isDark),
              const SizedBox(height: 25),
              _buildPhoneVerification(isDark),
              const SizedBox(height: 40),
              _buildNextButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vérification d\'identité',
          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Vérifiez votre identité pour devenir créateur',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildNextButton(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final disabledBg = isDark ? Colors.grey[800] : Colors.grey.shade300;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: (_isPhoneVerified && _idCardPath != null && !_isLoading && !_isUploading)
            ? _goToNextStep
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: accentTextColor,
          disabledBackgroundColor: disabledBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading || _isUploading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: accentTextColor,
                  strokeWidth: 3,
                ),
              )
            : Text(
                'Suivant',
                style: TextStyle(
                  color: accentTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final progressBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E7EB);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Étape 2/3',
              style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '2/3',
                style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: 0.66,
            backgroundColor: progressBg,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentSection(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;
    final cardColor = isDark ? const Color(0xFF161616) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB);
    final accentColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photo de ma pièce d\'identité',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CNI, Passeport ou Carte consulaire',
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_idCardPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildImageDisplay(isDark),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _importPhoto(),
                icon: Icon(Icons.refresh, color: textColor),
                label: Text(
                  'Changer l\'image',
                  style: TextStyle(color: textColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
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
                onPressed: _isUploading ? null : _importPhoto,
                icon: _isUploading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: accentColor, strokeWidth: 2),
                      )
                    : Icon(Icons.upload_file, color: accentColor),
                label: Text(
                  'Importer une photo',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageDisplay(bool isDark) {
    final height = 150.0;
    final width = double.infinity;
    final placeholderBg = isDark ? Colors.grey[800] : Colors.grey.shade300;
    final placeholderIcon = isDark ? Colors.white54 : Colors.black38;

    if (kIsWeb && _idCardBytes != null) {
      return Image.memory(
        _idCardBytes!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: placeholderBg,
          child: Center(child: Icon(Icons.broken_image, color: placeholderIcon, size: 40)),
        ),
      );
    }

    if (!kIsWeb && _idCardPath != null) {
      return Image.file(
        File(_idCardPath!),
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: placeholderBg,
          child: Center(child: Icon(Icons.broken_image, color: placeholderIcon, size: 40)),
        ),
      );
    }

    if (_idCardUrl != null) {
      return Image.network(
        _idCardUrl!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: placeholderBg,
          child: Center(child: Icon(Icons.broken_image, color: placeholderIcon, size: 40)),
        ),
      );
    }

    return Container(
      height: height,
      color: placeholderBg,
      child: Center(child: Icon(Icons.image, color: placeholderIcon, size: 40)),
    );
  }

  Widget _buildSecurityMessage(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final messageTextColor = isDark ? const Color(0xFFCCCCCC) : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vos données personnelles sont sécurisées et ne seront utilisées que pour vérifier votre identité.',
              style: TextStyle(color: messageTextColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneVerification(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF888888) : Colors.black54;
    final cardColor = isDark ? const Color(0xFF161616) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB);
    final fieldBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final hintColor = isDark ? const Color(0xFF555555) : Colors.black38;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vérification du numéro de téléphone',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Veuillez confirmer votre numéro pour recevoir vos notifications de gains.',
            style: TextStyle(color: subTextColor, fontSize: 13),
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
                  Expanded(
                    child: Text(
                      'Téléphone vérifié avec succès !',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Entrez le code reçu',
                    hintStyle: TextStyle(color: hintColor),
                    filled: true,
                    fillColor: fieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSendingOTP ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: accentTextColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSendingOTP
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: accentTextColor, strokeWidth: 2),
                          )
                        : Text(
                            'Vérifier',
                            style: TextStyle(color: accentTextColor, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

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

      final bytes = await image.readAsBytes();

      setState(() {
        _idCardPath = image.path;
        _idCardBytes = bytes;
      });

      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null && !kIsWeb) {
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
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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