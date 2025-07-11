// lib/providers/user_profile_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileProvider with ChangeNotifier {
  // Datos del Perfil
  String _displayName = 'Usuario Vito';
  String _email = '';
  DateTime? _createdAt;
  bool _isPremium = false; // Asumimos que esto vendrá de tu documento de usuario

  // Estadísticas
  int _totalHabits = 0;
  int _currentStreak = 0;

  // Estado de la carga
  bool _isLoading = true;

  // Getters públicos para que la UI los consuma
  String get displayName => _displayName;
  String get email => _email;
  DateTime? get createdAt => _createdAt;
  bool get isPremium => _isPremium;
  int get totalHabits => _totalHabits;
  int get currentStreak => _currentStreak;
  bool get isLoading => _isLoading;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserProfileProvider() {
    _auth.userChanges().listen((user) {
      if (user != null) {
        loadData(user);
      }
    });
  }

  // Carga todos los datos del usuario desde Firebase
  Future<void> loadData(User? user) async {
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Obtener datos del documento de usuario en Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _displayName = data['displayName'] ?? user.displayName ?? 'Usuario Vito';
        _email = data['email'] ?? user.email ?? '';
        _createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? user.metadata.creationTime;
        _isPremium = data['isPremium'] ?? false;
      } else {
        // Si no existe el documento, usamos los datos de Auth
        _displayName = user.displayName ?? 'Usuario Vito';
        _email = user.email ?? '';
        _createdAt = user.metadata.creationTime;
        _isPremium = false;
      }

      // 2. Cargar estadísticas de los hábitos
      final habitsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .get();
      
      _totalHabits = habitsSnapshot.docs.length;
      
      int maxStreak = 0;
      for (var doc in habitsSnapshot.docs) {
        final habitData = doc.data();
        final streak = habitData['streak'] as int? ?? 0;
        if (streak > maxStreak) {
          maxStreak = streak;
        }
      }
      _currentStreak = maxStreak;

    } catch (e) {
      print("Error al cargar datos del perfil: $e");
      // Opcional: manejar el estado de error
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- Acciones ---

  Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null || newName.trim().isEmpty) return;

    _displayName = newName.trim();
    notifyListeners(); // Actualiza la UI inmediatamente para una respuesta rápida

    await user.updateDisplayName(newName.trim());
    await _firestore.collection('users').doc(user.uid).set(
      {'displayName': newName.trim()},
      SetOptions(merge: true),
    );
  }

  // Puedes añadir más acciones aquí, como togglePremium, etc.
}