import 'package:flutter/material.dart';

/// Contrôleur global du thème de l'application.
/// Par défaut : mode sombre (adapte à ton design Afrifan).
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);