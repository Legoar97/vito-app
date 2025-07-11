// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Por defecto, usamos el tema del sistema

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme(); // Cargamos la preferencia guardada cuando la app inicia
  }

  // Carga el tema guardado desde el almacenamiento local
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Leemos el índice del ThemeMode. Si no hay nada, usamos el del sistema (valor 2).
    // 0 = light, 1 = dark, 2 = system
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  // Cambia el tema y guarda la nueva preferencia
  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return; // No hacer nada si ya es el mismo tema

    _themeMode = themeMode;
    notifyListeners(); // Notifica a la UI para que se reconstruya con el nuevo tema

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', themeMode.index); // Guarda el índice del enum
  }
}