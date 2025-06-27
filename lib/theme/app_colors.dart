import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const primary = Color(0xFF6B5B95);
  static const secondary = Color(0xFFF7CAC9);
  static const accent = Color(0xFF88B0D3);
  
  // Status colors
  static const success = Color(0xFF82B366);
  static const warning = Color(0xFFFEB236);
  static const error = Color(0xFFD32F2F);
  static const info = Color(0xFF2196F3);
  
  // Gradient colors
  static const gradientStart = Color(0xFF667eea);
  static const gradientEnd = Color(0xFF764ba2);
  
  // Category colors
  static const categoryHealth = Color(0xFF4ECDC4);
  static const categoryMind = Color(0xFFF7B731);
  static const categoryProductivity = Color(0xFF5F27CD);
  static const categoryRelationships = Color(0xFFEE5A6F);
  static const categoryCreativity = Color(0xFFA55EEA);
  static const categoryFinance = Color(0xFF26DE81);
  
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
  
  // Get category color by name
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'health':
        return categoryHealth;
      case 'mind':
        return categoryMind;
      case 'productivity':
        return categoryProductivity;
      case 'relationships':
        return categoryRelationships;
      case 'creativity':
        return categoryCreativity;
      case 'finance':
        return categoryFinance;
      default:
        return primary;
    }
  }
  
  // Get category icon
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'health':
        return Icons.favorite;
      case 'mind':
        return Icons.self_improvement;
      case 'productivity':
        return Icons.work;
      case 'relationships':
        return Icons.people;
      case 'creativity':
        return Icons.palette;
      case 'finance':
        return Icons.attach_money;
      default:
        return Icons.star;
    }
  }
}