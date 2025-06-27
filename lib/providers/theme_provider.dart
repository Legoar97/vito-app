import 'package:flutter/material.dart';

// Este enum define los temas disponibles.
enum ThemeOption { light, dark, system }

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // Método para cambiar el tema y notificar a los oyentes (la UI).
  void setTheme(ThemeOption themeOption) {
    switch (themeOption) {
      case ThemeOption.light:
        _themeMode = ThemeMode.light;
        break;
      case ThemeOption.dark:
        _themeMode = ThemeMode.dark;
        break;
      case ThemeOption.system:
        _themeMode = ThemeMode.system;
        break;
    }
    // Notifica a todos los widgets que escuchan para que se reconstruyan con el nuevo tema.
    notifyListeners();
  }

  // Convierte el ThemeMode actual a nuestro enum para la UI.
  ThemeOption get currentThemeOption {
    if (_themeMode == ThemeMode.light) return ThemeOption.light;
    if (_themeMode == ThemeMode.dark) return ThemeOption.dark;
    return ThemeOption.system;
  }
}
