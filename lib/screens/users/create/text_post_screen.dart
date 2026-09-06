import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TextPostScreen extends StatefulWidget {
  const TextPostScreen({super.key});

  @override
  State<TextPostScreen> createState() => _TextPostScreenState();
}

class _TextPostScreenState extends State<TextPostScreen> {
  final TextEditingController _textController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isPosting = false;
  int _charCount = 0;
  final int _maxChars = 500;

  Color _selectedBgColor = Colors.grey.shade800;
  
  final List<Color> _bgColors = [
    Colors.grey.shade800,
    const Color(0xFF8B5CF6),
    Colors.blue.shade700,
    Colors.purple.shade700,
    Colors.red.shade700,
    Colors.orange.shade700,
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _publishPost() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écrivez quelque chose d\'abord !'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      // Convertir la couleur en hex string
      String colorHex = '#${_selectedBgColor.value.toRadixString(16).padLeft(8, '0')}';

      await _supabase.from('posts').insert({
        'user_id': userId,
        'content': _textController.text.trim(),
        'media_type': 'text',
        'background_color': colorHex,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Publication réussie !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur publication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _publishPost,
            child: _isPosting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Publier', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ZONE DE TEXTE
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _selectedBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.all(16),
              child: TextField(
                controller: _textController,
                maxLength: _maxChars,
                onChanged: (value) => setState(() => _charCount = value.length),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: 'Quoi de neuf ?',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 24),
                  border: InputBorder.none,
                  counterText: '',
                ),
                maxLines: null,
                expands: true,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // COMPTEUR DE CARACTÈRES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$_charCount / $_maxChars',
                  style: TextStyle(
                    color: _charCount > _maxChars ? Colors.red : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // SÉLECTION DE COULEUR DE FOND
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Couleur de fond', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _bgColors.length,
              itemBuilder: (context, index) {
                final color = _bgColors[index];
                final isSelected = color.value == _selectedBgColor.value;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedBgColor = color),
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8)] : [],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}