// app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Manteniendo el morado original
  static const primary = Color(0xFF6B5B95); // Morado original
  static const secondary = Color(0xFFF7CAC9);
  static const accent = Color(0xFF88B0D3);
  
  // Status colors
  static const success = Color(0xFF82B366);
  static const warning = Color(0xFFFEB236);
  static const error = Color(0xFFD32F2F);
  static const info = Color(0xFF2196F3);
  
  // Gradient colors - Manteniendo los originales morados
  static const gradientStart = Color(0xFF667eea);
  static const gradientEnd = Color(0xFF764ba2);
  
  // Category colors - Usando la paleta proporcionada
  static const categoryHealth = Color(0xFFE68A17); // Naranja cálido
  static const categoryExercise = Color(0xFF007380); // Teal vibrante
  static const categoryMind = Color(0xFF003D66); // Azul profundo
  static const categoryEducation = Color(0xFF36A1B3); // Turquesa claro
  static const categoryProductivity = Color(0xFFE6B817); // Amarillo energético
  static const categoryRelationships = Color(0xFFE68A17); // Naranja social
  static const categoryCreativity = Color(0xFFE6B817); // Amarillo creativo
  static const categoryFinance = Color(0xFF007380); // Teal confiable
  static const categoryNutrition = Color(0xFF36A1B3); // Turquesa fresco
  
  // Background colors
  static const backgroundLight = Color(0xFFF8F9FE);
  static const backgroundDark = Color(0xFF1A1A2E);
  
  // Surface colors
  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF16213E);
  
  // Text colors
  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);
  static const textLight = Colors.white;
  
  // Get category color by name - Soporta español e inglés
  static Color getCategoryColor(String? category) {
    if (category == null) return primary;
    
    switch (category.toLowerCase()) {
      // Salud
      case 'salud':
      case 'health':
        return categoryHealth;
      
      // Ejercicio
      case 'ejercicio':
      case 'exercise':
        return categoryExercise;
      
      // Mente/Mindfulness
      case 'mindfulness':
      case 'mente':
      case 'mind':
      case 'meditation':
      case 'meditación':
        return categoryMind;
      
      // Educación
      case 'educacion':
      case 'educación':
      case 'education':
      case 'lectura':
      case 'estudio':
        return categoryEducation;
      
      // Productividad
      case 'productividad':
      case 'productivity':
      case 'trabajo':
      case 'work':
        return categoryProductivity;
      
      // Relaciones/Social
      case 'relaciones':
      case 'relationships':
      case 'social':
        return categoryRelationships;
      
      // Creatividad
      case 'creatividad':
      case 'creativity':
      case 'creativo':
      case 'creative':
        return categoryCreativity;
      
      // Finanzas
      case 'finanzas':
      case 'finance':
      case 'dinero':
        return categoryFinance;
      
      // Nutrición
      case 'nutricion':
      case 'nutrición':
      case 'nutrition':
      case 'alimentacion':
      case 'alimentación':
        return categoryNutrition;
      
      // Otros
      case 'otros':
      case 'other':
      default:
        return primary;
    }
  }
  
  // Get category icon - Actualizado para soportar más categorías
  static IconData getCategoryIcon(String? category) {
    if (category == null) return Icons.star;
    
    switch (category.toLowerCase()) {
      case 'salud':
      case 'health':
        return Icons.favorite;
      
      case 'ejercicio':
      case 'exercise':
        return Icons.fitness_center;
      
      case 'mindfulness':
      case 'mente':
      case 'mind':
      case 'meditation':
      case 'meditación':
        return Icons.self_improvement;
      
      case 'educacion':
      case 'educación':
      case 'education':
      case 'lectura':
      case 'estudio':
        return Icons.school;
      
      case 'productividad':
      case 'productivity':
      case 'trabajo':
      case 'work':
        return Icons.trending_up;
      
      case 'relaciones':
      case 'relationships':
      case 'social':
        return Icons.people;
      
      case 'creatividad':
      case 'creativity':
      case 'creativo':
      case 'creative':
        return Icons.palette;
      
      case 'finanzas':
      case 'finance':
      case 'dinero':
        return Icons.attach_money;
      
      case 'nutricion':
      case 'nutrición':
      case 'nutrition':
      case 'alimentacion':
      case 'alimentación':
        return Icons.restaurant;
      
      case 'otros':
      case 'other':
      default:
        return Icons.star;
    }
  }
  
  // Helper methods para obtener variaciones de color
  static Color getCategoryLightColor(String? category) {
    return getCategoryColor(category).withOpacity(0.1);
  }
  
  static Color getCategoryMediumColor(String? category) {
    return getCategoryColor(category).withOpacity(0.3);
  }
  
  // Colores de la paleta completa para uso adicional
  static const paletteYellow = Color(0xFFE6B817);
  static const paletteOrange = Color(0xFFE68A17); 
  static const paletteTurquoise = Color(0xFF36A1B3);
  static const paletteTeal = Color(0xFF007380);
  static const paletteNavy = Color(0xFF003D66);
}