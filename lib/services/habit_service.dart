// lib/services/habit_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HabitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  // Obtiene el stream de hábitos del usuario actual
  Stream<QuerySnapshot> getHabitsStream() {
    if (_user == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('habits')
        .snapshots();
  }

  // Obtiene el nombre del usuario
  Future<String> getUserName() async {
    if (_user == null) return 'amigo';
    final displayName = _user!.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }
    try {
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      return (userDoc.data()?['displayName'] as String?)?.split(' ').first ?? 'amigo';
    } catch (e) {
      print("Error fetching user name from Firestore: $e");
      return 'amigo';
    }
  }

  // Verifica si el onboarding fue completado
  Future<bool> isOnboardingCompleted() async {
    if (_user == null) return true; // Asumir completado si no hay usuario
    try {
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      return userDoc.data()?['onboardingCompleted'] as bool? ?? false;
    } catch (e) {
      print("Error checking onboarding status: $e");
      return true;
    }
  }

  // Marca el tutorial como completado
  Future<void> completeOnboarding() async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user!.uid).set({
        'onboardingCompleted': true,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error completing tutorial: $e");
    }
  }

  // Carga los registros de ánimo de hoy
  Future<List<Map<String, dynamic>>> loadTodaysMoods() async {
    if (_user == null) return [];
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('moods')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .orderBy('timestamp', descending: true)
        .get();
        
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // Guarda un nuevo registro de ánimo
  Future<bool> saveMood(String mood, List<Map<String, dynamic>> todaysMoods) async {
    if (_user == null) return false;

    if (todaysMoods.isNotEmpty) {
      final lastMoodTime = (todaysMoods.first['timestamp'] as Timestamp).toDate();
      if (DateTime.now().difference(lastMoodTime).inHours < 3) {
        return false; // Indica que no se pudo guardar
      }
    }
    
    await _firestore
      .collection('users')
      .doc(_user!.uid)
      .collection('moods')
      .add({'mood': mood, 'timestamp': Timestamp.now()});
      
    return true; // Indica que se guardó con éxito
  }
  
  // Marca un hábito simple
  Future<void> toggleSimpleHabit(String habitId, bool isCurrentlyCompleted) async {
      if (_user == null) return;
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final habitRef = _firestore.collection('users').doc(_user!.uid).collection('habits').doc(habitId);
          
      await habitRef.update({
        'completions.$todayKey': {
          'progress': isCurrentlyCompleted ? 0 : 1,
          'completed': !isCurrentlyCompleted,
        }
      });
  }

  // Actualiza un hábito cuantificable
  Future<void> updateQuantifiableProgress(String habitId, int currentProgress, int target, int change) async {
    if (_user == null) return;
    final newProgress = (currentProgress + change).clamp(0, target);
    if (newProgress == currentProgress) return;
    
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _firestore.collection('users').doc(_user!.uid).collection('habits').doc(habitId).update({
      'completions.$todayKey': {
        'progress': newProgress,
        'completed': newProgress >= target,
      }
    });
  }

  // Completa un hábito con temporizador
  Future<void> completeTimedHabit(String habitId) async {
    if (_user == null) return;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final habitRef = _firestore.collection('users').doc(_user!.uid).collection('habits').doc(habitId);
    
    await habitRef.update({
      'completions.$todayKey': {
        'progress': 1,
        'completed': true,
      }
    });
  }
}