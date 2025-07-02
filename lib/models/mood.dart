import 'package:flutter/material.dart';

enum MoodExpression {
  excellent,
  good,
  okay,
  bad,
  terrible,
}

class Mood {
  final String name;
  final MoodExpression expression;
  final Color baseColor;
  final List<Color> gradient;

  Mood({
    required this.name,
    required this.expression,
    required this.baseColor,
    required this.gradient,
  });
}

// Definir los moods disponibles
class MoodData {
  static final List<Mood> moods = [
    Mood(
      name: 'Excelente',
      expression: MoodExpression.excellent,
      baseColor: const Color(0xFFFFD93D),
      gradient: [const Color(0xFFFFD93D), const Color(0xFFFFC107)],
    ),
    Mood(
      name: 'Feliz',
      expression: MoodExpression.good,
      baseColor: const Color(0xFF6FD86F),
      gradient: [const Color(0xFF4ADE80), const Color(0xFF22C55E)],
    ),
    Mood(
      name: 'Normal',
      expression: MoodExpression.okay,
      baseColor: const Color(0xFF71C5E8),
      gradient: [const Color(0xFF60A5FA), const Color(0xFF3B82F6)],
    ),
    Mood(
      name: 'Triste',
      expression: MoodExpression.bad,
      baseColor: const Color(0xFFFFB6C1),
      gradient: [const Color(0xFFFDA4AF), const Color(0xFFFB7185)],
    ),
    Mood(
      name: 'Terrible',
      expression: MoodExpression.terrible,
      baseColor: const Color(0xFFB0B0B0),
      gradient: [const Color(0xFF94A3B8), const Color(0xFF64748B)],
    ),
  ];
}