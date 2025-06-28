import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Habit {
  final String id;
  final String name;
  final String category;
  final List<int> days;
  final TimeOfDay specificTime;
  final bool notifications;
  final Timestamp createdAt;
  final int currentStreak;
  final int longestStreak;

  // --- CAMPOS ACTUALIZADOS Y NUEVOS ---
  final String type; // 'simple', 'quantifiable', 'timed'
  final int? targetValue; // Para cantidad o minutos
  final String? unit; // ej. 'vasos', 'páginas', 'min'
  final Map<String, dynamic> completions; // Ya no es una lista de Timestamps

  Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.days,
    required this.specificTime,
    required this.notifications,
    required this.createdAt,
    required this.currentStreak,
    required this.longestStreak,
    // --- NUEVOS PARÁMETROS EN EL CONSTRUCTOR ---
    required this.type,
    this.targetValue,
    this.unit,
    required this.completions,
  });

  /// Convierte un objeto Habit a un mapa para guardarlo en Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'days': days,
      'specificTime': {
        'hour': specificTime.hour,
        'minute': specificTime.minute,
      },
      'notifications': notifications,
      'createdAt': createdAt,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      // --- NUEVOS CAMPOS EN EL MAPA ---
      'type': type,
      'targetValue': targetValue,
      'unit': unit,
      'completions': completions,
    };
  }

  /// Crea un objeto Habit a partir de un DocumentSnapshot de Firestore.
  factory Habit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Maneja el tiempo, que se guarda como un mapa.
    final timeData = data['specificTime'] as Map<String, dynamic>? ?? {'hour': 12, 'minute': 0};
    final time = TimeOfDay(hour: timeData['hour'], minute: timeData['minute']);
    
    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Otros',
      days: List<int>.from(data['days'] ?? []),
      specificTime: time,
      notifications: data['notifications'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
      // --- LECTURA DE LOS NUEVOS CAMPOS ---
      type: data['type'] as String? ?? 'simple',
      targetValue: data['targetValue'] as int?,
      unit: data['unit'] as String?,
      completions: Map<String, dynamic>.from(data['completions'] ?? {}),
    );
  }
}