import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin si besoin)
import 'post_selection_screen.dart';

class AICreationScreen extends StatefulWidget {
  const AICreationScreen({super.key});

  @override
  State<AICreationScreen> createState() => _AICreationScreenState();
}

class _AICreationScreenState extends State<AICreationScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isGenerating = false;
  Uint8List? _imageBytes;
  String? _generatedImageUrl;

  final List<Map<String, String>> _styles = [
    {'name': 'Anime', 'prompt': 'anime style, vibrant colors'},
    {'name': 'Pro', 'prompt': 'professional headshot, studio lighting'},
    {'name': 'Cyberpunk', 'prompt': 'cyberpunk style, neon lights'},
    {'name': 'Vintage', 'prompt': 'vintage film photo, 1990s'},
    {'name': 'Artistic', 'prompt': 'oil painting style, artistic'},
  ];

  Future<void> _generateImage(String stylePrompt) async {
    setState(() {
      _isGenerating = true;
      _imageBytes = null;
      _generatedImageUrl = null;
      _descriptionController.clear();
    });

    try {
      final userPrompt = _promptController.text.isEmpty
          ? 'African portrait'
          : _promptController.text;

      final simplePrompt = '$userPrompt $stylePrompt';
      final seed = DateTime.now().millisecondsSinceEpoch.remainder(1000000);

      final encodedPrompt = simplePrompt
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final imageUrl = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(encodedPrompt)}?width=512&height=512&seed=$seed&nologo=true&noCache=true';

      debugPrint('🔍 URL: $imageUrl');

      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 30),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        debugPrint('✅ Image téléchargée: ${response.bodyBytes.length} bytes');

        if (mounted) {
          setState(() {
            _imageBytes = response.bodyBytes;
            _generatedImageUrl = imageUrl;
            _isGenerating = false;
          });
        }
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _publishImage() {
    if (_generatedImageUrl == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostSelectionScreen(
          mediaPath: _generatedImageUrl!,
          mediaType: 'photo',
        ),
      ),
    );
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
    // ✅ Couleurs adaptatives
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final inputBg = isDark ? Colors.grey.shade900 : const Color(0xFFF3F4F6);
    final cardBg = isDark ? Colors.grey.shade900 : const Color(0xFFF3F4F6);
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
          '✨ Création IA',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transforme tes idées avec l\'IA',
              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Décris ton idée et choisis un style',
              style: TextStyle(color: subTextColor),
            ),
            const SizedBox(height: 24),

            // ─── PROMPT ───
            TextField(
              controller: _promptController,
              style: TextStyle(color: textColor),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex: cool lion with sunglasses',
                hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.black38),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Choisis un style',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ─── STYLES ───
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: _styles.length,
              itemBuilder: (context, index) {
                final style = _styles[index];
                return GestureDetector(
                  onTap: _isGenerating ? null : () => _generateImage(style['prompt']!),
                  child: Container(
                    decoration: BoxDecoration(
                      // ✅ Carte style : fond sombre en clair / gris foncé en sombre
                      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isGenerating ? Icons.hourglass_empty : Icons.auto_awesome,
                          color: accentColor,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          style['name']!,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ─── LOADER ───
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: accentColor),
                    const SizedBox(height: 16),
                    Text(
                      'L\'IA travaille sa magie... ⏳ 10-20s',
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],

            // ─── RÉSULTAT ───
            if (_imageBytes != null) ...[
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor, width: 1),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ Image générée ! Vérifie avant de publier',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _imageBytes!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _descriptionController,
                      style: TextStyle(color: textColor),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ajoute une description...',
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.black38),
                        filled: true,
                        fillColor: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.white.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // ✅ Bouton "Régénérer" (outlined)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _imageBytes = null;
                                _generatedImageUrl = null;
                                _descriptionController.clear();
                              });
                            },
                            icon: Icon(Icons.refresh, color: textColor),
                            label: Text('Régénérer', style: TextStyle(color: textColor)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ✅ Bouton "Publier" : noir en clair / blanc en sombre
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _publishImage,
                            icon: Icon(Icons.send, color: accentTextColor),
                            label: Text(
                              'Publier',
                              style: TextStyle(
                                color: accentTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}