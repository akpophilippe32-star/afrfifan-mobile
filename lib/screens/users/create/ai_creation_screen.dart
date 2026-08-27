import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_selection_screen.dart';

class AICreationScreen extends StatefulWidget {
  const AICreationScreen({super.key});

  @override
  State<AICreationScreen> createState() => _AICreationScreenState();
}

class _AICreationScreenState extends State<AICreationScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedImageUrl;
  
  // Ta clé API Replicate (à remplacer par ta vraie clé)
  final String _replicateToken = 'r8_cznxX29pCvZgvRc9oQEZo12aeZiV4Ps1iDG20'; // ⚠️ Mets ta vraie clé ici

  // Modèles IA disponibles
  final List<Map<String, String>> _styles = [
    {'name': 'Anime', 'prompt': 'anime style, vibrant colors, japanese animation'},
    {'name': 'Pro', 'prompt': 'professional headshot, studio lighting, high quality'},
    {'name': 'Cyberpunk', 'prompt': 'cyberpunk style, neon lights, futuristic'},
    {'name': 'Vintage', 'prompt': 'vintage film photo, 1990s aesthetic'},
    {'name': 'Artistic', 'prompt': 'oil painting style, artistic, masterpiece'},
  ];

  Future<void> _generateImage(String stylePrompt) async {
    setState(() {
      _isGenerating = true;
      _generatedImageUrl = null;
    });

    try {
      final prompt = _promptController.text.isEmpty 
          ? 'Portrait africain de haute qualité, style moderne'
          : _promptController.text;

      final fullPrompt = '$prompt, ${stylePrompt}, 4k, highly detailed, professional';

      // Appel à Replicate API (Modèle Flux Schnell - rapide et pas cher)
      final response = await http.post(
        Uri.parse('https://api.replicate.com/v1/predictions'),
        headers: {
          'Authorization': 'Token $_replicateToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': '4f2111f21e2a73e11c0df1116c9eb9b3e35b61d4e1e9c6f6f8f5f5f5f5f5f5f5',
          'input': {
            'prompt': fullPrompt,
            'width': 1024,
            'height': 1024,
            'num_outputs': 1,
          }
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Erreur API: ${response.body}');
      }

      final prediction = jsonDecode(response.body);
      
      // Attendre que l'IA finisse
      String? imageUrl;
      int attempts = 0;
      
      while (attempts < 30) {
        await Future.delayed(const Duration(seconds: 2));
        
        final statusResponse = await http.get(
          Uri.parse(prediction['urls']['get']),
          headers: {'Authorization': 'Token $_replicateToken'},
        );

        final statusData = jsonDecode(statusResponse.body);
        
        if (statusData['status'] == 'succeeded') {
          imageUrl = statusData['output'][0];
          break;
        } else if (statusData['status'] == 'failed') {
          throw Exception('Échec de la génération');
        }
        
        attempts++;
      }

      if (imageUrl != null && mounted) {
        setState(() {
          _generatedImageUrl = imageUrl;
        });
        
        _showSuccessDialog();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(' Image générée !', style: TextStyle(color: Colors.white)),
        content: const Text('Que veux-tu faire avec cette image ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Garder', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _publishImage();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  void _publishImage() {
    // TODO: Sauvegarder l'image et rediriger vers PostSelectionScreen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publication en cours...'), backgroundColor: Color(0xFF8B5CF6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('✨ Création IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transforme tes photos avec l\'IA',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choisis un style et laisse la magie opérer',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Champ de description
            TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Décris ton image idéale (optionnel)...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Choisis un style',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Grille des styles
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
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(0.3),
                          Colors.purple.shade900,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isGenerating ? Icons.hourglass_empty : Icons.auto_awesome,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          style['name']!,
                          style: const TextStyle(
                            color: Colors.white,
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
            
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    SizedBox(height: 16),
                    Text(
                      'L\'IA travaille sa magie... ⏱️ 15-30s',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_generatedImageUrl != null) ...[
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('✅ Image générée avec succès !', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _generatedImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}