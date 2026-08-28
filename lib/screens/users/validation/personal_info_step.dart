import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // ─── CONSTANTES DE COULEUR ────────────────────────────────
  static const Color _primaryColor = Color(0xFF8B5CF6);
  static const Color _backgroundColor = Color(0xFF0A0A0A);
  static const Color _cardColor = Color(0xFF1A1A1A);
  static const Color _borderColor = Color(0xFF333333);
  static const Color _textColor = Colors.white;
  static const Color _textSecondaryColor = Color(0xFF9CA3AF);
  static const Color _hintColor = Color(0xFF6B7280);

  final List<String> _categories = [
    'Musique', 'Humour', 'Éducation', 'Sport', 'Mode', 
    'Cuisine', 'Art & Design', 'Technologie', 'Autre'
  ];

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: _cardColor,
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressBar(),
                const SizedBox(height: 30),
                const Text(
                  'Informations personnelles',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Remplissez ces informations pour compléter votre profil',
                  style: TextStyle(
                    color: _textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 30),
                
                // ─── NOM COMPLET ──────────────────────────────
                _buildTextField(
                  _fullNameController,
                  'Nom complet',
                  'Ex: Jean Dupont',
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),
                
                // ─── DATE DE NAISSANCE ────────────────────────
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      _birthDateController,
                      'Date de naissance',
                      'JJ/MM/AAAA',
                      Icons.calendar_today_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ─── VILLE / PAYS ─────────────────────────────
                _buildTextField(
                  _cityController,
                  'Ville / Pays',
                  'Ex: Cotonou, Bénin',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                
                // ─── CATÉGORIE ────────────────────────────────
                _buildDropdownField(),
                
                const SizedBox(height: 30),
                
                // ─── BOUTON SUIVANT ───────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _goToNextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
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
      ),
    );
  }

  // ─── WIDGETS ────────────────────────────────────────────────

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(
          color: _textColor,
          fontSize: 16,
        ),
        cursorColor: _primaryColor,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Ce champ est requis';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: _textSecondaryColor,
            fontSize: 14,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: _hintColor,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: _primaryColor,
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          errorStyle: const TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
          ),
          filled: true,
          fillColor: _cardColor,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: _cardColor,
          hint: const Text(
            'Catégorie de contenu',
            style: TextStyle(
              color: _textSecondaryColor,
              fontSize: 14,
            ),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: _primaryColor,
            size: 28,
          ),
          items: _categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(
                category,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 15,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) => setState(() => _selectedCategory = newValue),
          selectedItemBuilder: (context) {
            return _categories.map((String category) {
              return Text(
                category,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 15,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Étape 1/3',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '33%',
              style: TextStyle(
                color: _textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: 0.33,
          backgroundColor: _borderColor,
          valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
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