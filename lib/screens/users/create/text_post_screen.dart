import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin si besoin)

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

  // ✅ Violet retiré, reste des couleurs "safe" pour la lisibilité du texte blanc
  Color _selectedBgColor = Colors.grey.shade800;

  final List<Color> _bgColors = [
    Colors.grey.shade800,      // Gris (par défaut)
    const Color(0xFF1A1A1A),    // Noir doux
    Colors.blue.shade700,       // Bleu
    Colors.indigo.shade700,     // Indigo
    Colors.red.shade700,        // Rouge
    Colors.orange.shade800,     // Orange foncé
    Colors.teal.shade700,       // Sarcelle
    Colors.pink.shade700,       // Rose foncé
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        return _buildScreen(isDark);
      },
    );
  }

  Widget _buildScreen(bool isDark) {
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _publishPost,
            child: _isPosting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      // ✅ Loader noir/blanc
                      color: accentColor,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Publier',
                    style: TextStyle(
                      // ✅ Bouton publier noir/blanc
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── ZONE DE TEXTE (la couleur est choisie par l'utilisateur) ───
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
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

          // ─── COMPTEUR ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$_charCount / $_maxChars',
                  style: TextStyle(
                    color: _charCount > _maxChars ? Colors.red : subTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── TITRE COULEUR DE FOND ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Couleur de fond',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ─── PALETTE DE COULEURS ───
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
                        // ✅ Bordure blanche en sombre / noire en clair (selon le fond choisi)
                        color: isSelected ? borderColor : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: borderColor.withOpacity(0.5), blurRadius: 8)]
                          : [],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
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