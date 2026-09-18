import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'post_selection_screen.dart';
import 'ai_creation_screen.dart';
import 'text_post_screen.dart';
import '../../../theme/theme_notifier.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String _hoveredTab = '';

  Future<void> _selectMedia() async {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final handleColor = isDark ? const Color(0xFF3F3F3F) : const Color(0xFFD1D5DB);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: Icon(Icons.photo, color: textColor, size: 28),
                title: Text(
                  'Photo de la galerie',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'JPG, PNG, WEBP',
                  style: TextStyle(color: subColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (file != null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostSelectionScreen(
                          mediaPath: file.path,
                          mediaType: 'photo',
                          xFile: file,
                        ),
                      ),
                    );
                  }
                },
              ),

              ListTile(
                leading: Icon(Icons.video_library, color: textColor, size: 28),
                title: Text(
                  'Vidéo de la galerie',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'MP4, MOV, WEBM',
                  style: TextStyle(color: subColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await _imagePicker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (file != null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostSelectionScreen(
                          mediaPath: file.path,
                          mediaType: 'video',
                          xFile: file,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
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

        // Couleurs noir et blanc uniquement
        final bgColor = isDark ? Colors.black : Colors.white;
        final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB);
        final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
        final textColor = isDark ? Colors.white : Colors.black;
        final textMutedColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
        final hoverColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

        return Scaffold(
          backgroundColor: bgColor,

          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close, color: textColor, size: 24),
                      ),
                      Expanded(
                        child: Text(
                          'Nouvelle publication',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Onglets Image IA et Texte
                Row(
                  children: [
                    Expanded(
                      child: _buildTab(
                        icon: Icons.auto_awesome,
                        label: 'Image IA',
                        isHovered: _hoveredTab == 'ai',
                        onEnter: () => setState(() => _hoveredTab = 'ai'),
                        onExit: () => setState(() => _hoveredTab = ''),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AICreationScreen(),
                          ),
                        ),
                        cardColor: cardColor,
                        borderColor: borderColor,
                        hoverColor: hoverColor,
                        textColor: textColor,
                        textMutedColor: textMutedColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTab(
                        icon: Icons.text_fields,
                        label: 'Texte',
                        isHovered: _hoveredTab == 'text',
                        onEnter: () => setState(() => _hoveredTab = 'text'),
                        onExit: () => setState(() => _hoveredTab = ''),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TextPostScreen(),
                          ),
                        ),
                        cardColor: cardColor,
                        borderColor: borderColor,
                        hoverColor: hoverColor,
                        textColor: textColor,
                        textMutedColor: textMutedColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Zone Importer un média
                GestureDetector(
                  onTap: _selectMedia,
                  child: Container(
                    width: double.infinity,
                    height: 400,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 56,
                          color: textMutedColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Importer un média',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cliquez pour choisir une photo ou une vidéo',
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: textColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Sélectionner un fichier',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isHovered,
    required VoidCallback onEnter,
    required VoidCallback onExit,
    required VoidCallback onTap,
    required Color cardColor,
    required Color borderColor,
    required Color hoverColor,
    required Color textColor,
    required Color textMutedColor,
  }) {
    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isHovered ? hoverColor : cardColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: textMutedColor,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}