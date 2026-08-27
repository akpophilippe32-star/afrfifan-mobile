import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
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
  Uint8List? _imageBytes; // ✅ On stocke les bytes de l'image
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

      // ✅ TÉLÉCHARGER L'IMAGE EN BYTES (contourne les problèmes CORS)
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
          SnackBar(content: Text(' Erreur: ${e.toString()}'), backgroundColor: Colors.red),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('✨ Création IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transforme tes idées avec l\'IA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Décris ton idée et choisis un style', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            
            TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex: cool lion with sunglasses',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('Choisis un style', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
              ),
              itemCount: _styles.length,
              itemBuilder: (context, index) {
                final style = _styles[index];
                return GestureDetector(
                  onTap: _isGenerating ? null : () => _generateImage(style['prompt']!),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF4A148C)]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isGenerating ? Icons.hourglass_empty : Icons.auto_awesome, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        Text(style['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    SizedBox(height: 16),
                    Text('L\'IA travaille sa magie... ️ 10-20s', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ],
            
            if (_imageBytes != null) ...[
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✅ Image générée ! Vérifie avant de publier', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    
                    // ✅ AFFICHER L'IMAGE DEPUIS LES BYTES (pas de CORS)
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
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ajoute une description...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _imageBytes = null;
                                _generatedImageUrl = null;
                                _descriptionController.clear();
                              });
                            },
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('Régénérer', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _publishImage,
                            icon: const Icon(Icons.send, color: Colors.black),
                            label: const Text('Publier', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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