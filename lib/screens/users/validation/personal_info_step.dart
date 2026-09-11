import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)
import 'identity_verification_step.dart';

class PersonalInfoStep extends StatefulWidget {
  const PersonalInfoStep({Key? key}) : super(key: key);

  @override
  State<PersonalInfoStep> createState() => _PersonalInfoStepState();
}

class _PersonalInfoStepState extends State<PersonalInfoStep> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedCategory;

  DateTime? _selectedDate;
  bool _isLoading = false;

  final List<String> _categories = [
    'Musique', 'Humour', 'Éducation', 'Sport', 'Mode',
    'Cuisine', 'Art & Design', 'Technologie', 'Autre'
  ];

  Future<void> _selectDate(bool isDark) async {
    final accentColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: accentColor,
                    onPrimary: isDark ? Colors.black : Colors.white,
                    surface: cardColor,
                    onSurface: textColor,
                  ),
                  dialogBackgroundColor: cardColor,
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: accentColor,
                    onPrimary: Colors.white,
                    surface: cardColor,
                    onSurface: textColor,
                  ),
                  dialogBackgroundColor: cardColor,
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _goToNextStep() async {
    if (_formKey.currentState!.validate()) {
      final category = _selectedCategory;
      if (category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner une catégorie'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception("Utilisateur non connecté.");

        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IdentityVerificationStep(
                fullName: _fullNameController.text.trim(),
                birthDate: _birthDateController.text.trim(),
                city: _cityController.text.trim(),
                category: category,
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
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressBar(isDark),
                const SizedBox(height: 30),
                _buildTitle(isDark),
                const SizedBox(height: 30),

                _buildTextField(
                  _fullNameController,
                  'Nom complet',
                  'Ex: Jean Dupont',
                  Icons.person_outline,
                  isDark,
                ),
                const SizedBox(height: 16),

                // ─── DATE DE NAISSANCE ───
                GestureDetector(
                  onTap: () => _selectDate(isDark),
                  child: AbsorbPointer(
                    child: _buildTextField(
                      _birthDateController,
                      'Date de naissance',
                      'JJ/MM/AAAA',
                      Icons.calendar_today_outlined,
                      isDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  _cityController,
                  'Ville / Pays',
                  'Ex: Cotonou, Bénin',
                  Icons.location_on_outlined,
                  isDark,
                ),
                const SizedBox(height: 16),

                _buildDropdownField(isDark),

                const SizedBox(height: 30),
                _buildNextButton(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations personnelles',
          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Remplissez ces informations pour compléter votre profil',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildNextButton(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _goToNextStep,
        style: ElevatedButton.styleFrom(
          // ✅ Bouton : noir en clair / blanc en sombre
          backgroundColor: accentColor,
          foregroundColor: accentTextColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: accentTextColor, strokeWidth: 2),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    bool isDark,
  ) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.black54;
    final hintColor = isDark ? const Color(0xFF6B7280) : Colors.black38;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: textColor, fontSize: 16),
        cursorColor: accentColor,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Ce champ est requis';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          hintText: hint,
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          // ✅ Icône accent au lieu de violette
          prefixIcon: Icon(icon, color: accentColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
          filled: true,
          fillColor: cardColor,
        ),
      ),
    );
  }

  Widget _buildDropdownField(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.black54;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: cardColor,
          hint: Text(
            'Catégorie de contenu',
            style: TextStyle(color: subTextColor, fontSize: 14),
          ),
          // ✅ Icône accent au lieu de violette
          icon: Icon(Icons.arrow_drop_down, color: accentColor, size: 28),
          items: _categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(
                category,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) => setState(() => _selectedCategory = newValue),
          selectedItemBuilder: (context) {
            return _categories.map((String category) {
              return Text(
                category,
                style: TextStyle(color: textColor, fontSize: 15),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : Colors.black54;
    final progressBg = isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Étape 1/3',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '33%',
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: 0.33,
          backgroundColor: progressBg,
          // ✅ Accent au lieu de violet
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _birthDateController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}