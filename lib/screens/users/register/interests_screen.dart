import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
// Importe ton écran principal contenant les 5 menus du bas
import '../main/main_screen.dart'; // Ajuste le chemin d'accès selon l'emplacement réel de ton fichier main_screen.dart

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  // Liste des catégories disponibles
  final List<String> _categories = [
    'Musique',
    'Humour',
    'Art & Design',
    'Danse',
    'Sport',
    'Mode',
    'Littérature',
    'Education',
    'Cuisine',
    'Tech',
    'Voyage',
    'Autre',
  ];

  // Liste pour stocker les sélections de l'utilisateur
  final Set<String> _selectedCategories = {};

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int selectedCount = _selectedCategories.length;
    final bool canContinue = selectedCount >= 3;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Choisissez vos centres d\'intérêt',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sélectionnez au moins 3 catégories qui vous intéressent.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategories.contains(category);

                    return GestureDetector(
                      onTap: () => _toggleCategory(category),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.08)
                              : AppColors.inputFill,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.interests_outlined,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textDark,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: selectedCount > 0
                    ? 'Continuer ($selectedCount)'
                    : 'Continuer',
                onPressed: canContinue
                    ? () {
                        // Navigation vers le MainScreen pour afficher les 5 menus du bas avec l'accueil par défaut
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(),
                          ),
                        );
                      }
                    : () {}, // Inactif si moins de 3 sélectionnés
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}