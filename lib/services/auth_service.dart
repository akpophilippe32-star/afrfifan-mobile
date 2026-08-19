import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Inscription (Créer un compte)
  Future<AuthResponse?> signUp(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      print('Erreur lors de l\'inscription : $e');
      return null;
    }
  }

  // Connexion
  Future<AuthResponse?> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      print('Erreur lors de la connexion : $e');
      return null;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Récupérer l'utilisateur actuellement connecté
  User? get currentUser => _supabase.auth.currentUser;
}