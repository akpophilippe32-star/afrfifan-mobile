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

  final List<String> _categories = [
    'Musique', 'Humour', 'Éducation', 'Sport', 'Mode', 'Cuisine', 'Art & Design', 'Technologie', 'Autre'
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
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
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
          const SnackBar(content: Text('Veuillez sélectionner une catégorie'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception("Utilisateur non connecté.");

        // Petit délai pour l'UX
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IdentityVerificationStep(
                fullName: _fullNameController.text.trim(),
                birthDate: _birthDateController.text.trim(), // ✅ Correction ici (suppression du ? superflu)
                city: _cityController.text.trim(),
                category: category,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
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
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                _buildTextField(_fullNameController, 'Nom complet', 'Ex: Jean Dupont', Icons.person_outline),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: _buildTextField(_birthDateController, 'Date de naissance', 'JJ/MM/AAAA', Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(_cityController, 'Ville / Pays', 'Ex: Cotonou, Bénin', Icons.location_on_outlined),
                const SizedBox(height: 16),
                _buildDropdownField(),
               const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _goToNextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        validator: (value) => value!.isEmpty ? 'Requis' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: Icon(icon, color: const Color(0xFF8B5CF6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          hint: const Text('Catégorie de contenu', style: TextStyle(color: Colors.white70)),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8B5CF6)),
          items: _categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (String? newValue) => setState(() => _selectedCategory = newValue),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Étape 1/3', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: 0.33, backgroundColor: const Color(0xFF1A1A1A), valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6))),
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