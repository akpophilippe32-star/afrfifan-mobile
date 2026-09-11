import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/theme_notifier.dart'; // ✅ AJOUT (ajuste le chemin)

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _emailController.text = user.email ?? '';

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && data['username'] != null) {
        _usernameController.text = data['username'].toString();
      }
    } catch (e) {
      debugPrint("🚨 Erreur lors de la récupération des infos : $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    try {
      await Supabase.instance.client.from('profiles').update({
        'username': _usernameController.text.trim(),
      }).eq('id', userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Informations mises à jour avec succès !"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'enregistrement : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey : Colors.black54;
    final fieldBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6);
    final readonlyBg = isDark ? const Color(0xFF151515) : const Color(0xFFE5E7EB);
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final accentColor = isDark ? Colors.white : Colors.black;
    final accentTextColor = isDark ? Colors.black : Colors.white;
    final disabledBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final disabledText = isDark ? Colors.grey.shade500 : Colors.black38;

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
          'Informations personnelles',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modifiez vos informations publiques visibles par les autres utilisateurs.',
                      style: TextStyle(color: subTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // ─── NOM D'UTILISATEUR ───
                    _buildInputLabel("Nom d'utilisateur", textColor),
                    TextFormField(
                      controller: _usernameController,
                      style: TextStyle(color: textColor),
                      cursorColor: accentColor,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Le nom d'utilisateur ne peut pas être vide";
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hintText: "Ton pseudo",
                        prefixIcon: Icons.person_outline,
                        fieldBg: fieldBg,
                        subTextColor: subTextColor,
                        accentColor: accentColor,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── EMAIL (lecture seule) ───
                    _buildInputLabel("Adresse Email (Non modifiable)", textColor),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      style: TextStyle(color: subTextColor),
                      decoration: _buildInputDecoration(
                        hintText: "email@exemple.com",
                        prefixIcon: Icons.email_outlined,
                        fieldBg: fieldBg,
                        subTextColor: subTextColor,
                        accentColor: accentColor,
                        borderColor: borderColor,
                      ).copyWith(
                        fillColor: readonlyBg,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── BOUTON ENREGISTRER ───
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          // ✅ Bouton : noir en clair / blanc en sombre
                          backgroundColor: accentColor,
                          foregroundColor: accentTextColor,
                          disabledBackgroundColor: disabledBg,
                          disabledForegroundColor: disabledText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: accentTextColor,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Enregistrer les modifications',
                                style: TextStyle(
                                  color: accentTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInputLabel(String label, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required Color fieldBg,
    required Color subTextColor,
    required Color accentColor,
    required Color borderColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: subTextColor),
      prefixIcon: Icon(prefixIcon, color: subTextColor, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      fillColor: fieldBg,
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          // ✅ Accent (noir en clair / blanc en sombre)
          color: accentColor,
          width: 1.5,
        ),
      ),
    );
  }
}