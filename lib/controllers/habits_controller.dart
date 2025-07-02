// lib/screens/habits/controllers/habits_controller.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HabitsController extends ChangeNotifier {
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Estado
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingSuggestions = false;
  List<SuggestedHabit> _suggestedHabits = [];
  bool _showCoachWelcome = false;
  String _userName = '';
  List<Map<String, dynamic>> _todaysMoods = [];
  
  // Streams
  Stream<QuerySnapshot>? _allHabitsStream;
  
  // Getters
  DateTime get selectedDate => _selectedDate;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  List<SuggestedHabit> get suggestedHabits => _suggestedHabits;
  bool get showCoachWelcome => _showCoachWelcome;
  String get userName => _userName;
  Stream<QuerySnapshot>? get allHabitsStream => _allHabitsStream;
  List<Map<String, dynamic>> get todaysMoods => _todaysMoods;
  
  HabitsController() {
    _initialize();
  }
  
  void _initialize() {
    if (user != null) {
      _initializeStream();
      _loadUserNameAndOnboarding();
    }
  }
  
  void _initializeStream() {
    _allHabitsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('habits')
        .snapshots();
    notifyListeners();
  }
  
  Future<void> _loadUserNameAndOnboarding() async {
    if (user == null) return;
    
    final displayName = user!.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      _userName = displayName.split(' ').first;
    } else {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (userDoc.exists) {
          _userName = (userDoc.data()?['displayName'] as String?)
                  ?.split(' ')
                  .first ??
              'amigo';
        }
      } catch (e) {
        _userName = '';
      }
    }
    
    notifyListeners();
    await _checkIfFirstTime();
  }
  
  Future<void> _checkIfFirstTime() async {
    if (user == null) return;
    await Future.delayed(const Duration(seconds: 1));
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('habits')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      _showCoachWelcome = true;
      notifyListeners();
    }
  }
  
  void updateSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }
  
  void navigatePreviousDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    notifyListeners();
  }
  
  void navigateNextDay() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    notifyListeners();
  }
  
  Future<void> getAiHabitSuggestions(String category) async {
    _isLoadingSuggestions = true;
    _suggestedHabits = [];
    notifyListeners();
    
    // Simulación de llamada a IA
    await Future.delayed(const Duration(seconds: 2));
    
    final Map<String, List<String>> mockSuggestions = {
      'Salud': [
        'Beber un vaso de agua',
        'Estirar por 10 minutos',
        'Caminar 15 minutos'
      ],
      'Mente': [
        'Meditar 5 minutos',
        'Escribir un diario',
        'Leer 10 minutos'
      ],
      'Trabajo': [
        'Organizar tu escritorio',
        'Planificar tus 3 tareas más importantes',
        'Tomar un descanso de 5 min'
      ],
      'Creativo': [
        'Dibujar algo simple',
        'Escuchar música nueva',
        'Escribir una idea'
      ],
      'Finanzas': [
        'Anotar gastos del día',
        'Revisar tu presupuesto',
        'Aprender un término financiero'
      ],
    };
    
    final suggestions = mockSuggestions[category] ?? [];
    _suggestedHabits = suggestions
        .map((name) => SuggestedHabit(name: name, category: category))
        .toList();
    _isLoadingSuggestions = false;
    _showCoachWelcome = false;
    notifyListeners();
  }
  
  void removeSuggestion(SuggestedHabit habit) {
    _suggestedHabits.remove(habit);
    notifyListeners();
  }
  
  void clearSuggestions() {
    _suggestedHabits = [];
    notifyListeners();
  }
  
  void dismissCoachWelcome() {
    _showCoachWelcome = false;
    notifyListeners();
  }
  
  Future<void> toggleSimpleHabit(String habitId, bool isCurrentlyCompleted) async {
    if (user == null) return;
    
    final todayKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final habitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('habits')
        .doc(habitId);
    
    await habitRef.update({
      'completions.$todayKey': {
        'progress': isCurrentlyCompleted ? 0 : 1,
        'completed': !isCurrentlyCompleted,
      }
    });
  }
  
  Future<void> updateQuantifiableProgress(
      String habitId, int currentProgress, int target, int change) async {
    if (!isSameDay(_selectedDate, DateTime.now()) || user == null) return;
    
    final newProgress = (currentProgress + change).clamp(0, target);
    if (newProgress == currentProgress) return;
    
    final todayKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('habits')
        .doc(habitId)
        .update({
      'completions.$todayKey': {
        'progress': newProgress,
        'completed': newProgress >= target,
      }
    });
  }
  
  int getStreakFromHabitsData(List<QueryDocumentSnapshot> habits) {
    if (habits.isEmpty) return 0;
    
    final Set<DateTime> allCompletionDates = {};
    final Set<int> allScheduledWeekdays = {};
    
    for (var habitDoc in habits) {
      final data = habitDoc.data() as Map<String, dynamic>;
      final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
      
      for (var entry in completionsMap.entries) {
        final completionData = entry.value as Map<String, dynamic>;
        if (completionData['completed'] == true) {
          try {
            final date = DateFormat('yyyy-MM-dd').parse(entry.key);
            allCompletionDates.add(date);
          } catch (e) {
            // Ignorar fechas con formato incorrecto
          }
        }
      }
      
      final days = List<int>.from(data['days'] ?? []);
      allScheduledWeekdays.addAll(days);
    }
    
    if (allCompletionDates.isEmpty || allScheduledWeekdays.isEmpty) return 0;
    
    int streak = 0;
    var now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    
    if (allScheduledWeekdays.contains(checkDate.weekday) &&
        !allCompletionDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    for (int i = 0; i < 366; i++) {
      if (allScheduledWeekdays.contains(checkDate.weekday)) {
        if (allCompletionDates.contains(checkDate)) {
          streak++;
        } else {
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }
  
  Map<String, dynamic> getProgressForSelectedDay(
      List<QueryDocumentSnapshot> allHabits) {
    int totalHabitsForSelectedDay = 0;
    int completedOnSelectedDay = 0;
    
    for (var habit in allHabits) {
      final data = habit.data() as Map<String, dynamic>;
      final days = List<int>.from(data['days'] ?? []);
      
      if (days.contains(_selectedDate.weekday)) {
        totalHabitsForSelectedDay++;
        
        final completionsMap = data['completions'] as Map<String, dynamic>? ?? {};
        final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
        
        if (completionsMap[dateKey]?['completed'] == true) {
          completedOnSelectedDay++;
        }
      }
    }
    
    return {
      'total': totalHabitsForSelectedDay,
      'completed': completedOnSelectedDay,
      'progress': totalHabitsForSelectedDay > 0
          ? completedOnSelectedDay / totalHabitsForSelectedDay
          : 0.0,
    };
  }
  
  List<QueryDocumentSnapshot> getHabitsForSelectedDay(
      List<QueryDocumentSnapshot> allHabits) {
    return allHabits.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final days = List<int>.from(data?['days'] ?? []);
      return days.contains(_selectedDate.weekday);
    }).toList();
  }
  
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  String getGreeting() {
    final hour = DateTime.now().hour;
    final name = _userName.isNotEmpty ? ", $_userName" : "";
    if (hour < 12) return 'Buenos días$name';
    if (hour < 18) return 'Buenas tardes$name';
    return 'Buenas noches$name';
  }
  
  String getMotivationalQuote() {
    final quotes = [
      'Un pequeño paso hoy es un gran salto mañana.',
      'La constancia es la clave del éxito.',
      'Tu mejor versión te está esperando.',
      'Cree en el poder de tus hábitos.',
      'Cada día es una nueva oportunidad para mejorar.',
      'La disciplina es el puente entre metas y logros.',
      'El progreso, no la perfección, es lo que importa.',
      'Eres más fuerte de lo que piensas.',
      'Siembra un hábito, cosecha un futuro.',
      'La acción más pequeña es mejor que la intención más grande.',
      'Enfócate en el progreso, no en los resultados.',
      'Tu futuro se crea por lo que haces hoy.',
      'Confía en el proceso de tu crecimiento.',
      'La paciencia y la perseverancia tienen un efecto mágico.',
      'Transforma tus rutinas para transformar tu vida.'
    ];
    
    final dayOfYear = int.parse(DateFormat("D").format(DateTime.now()));
    final quoteIndex = dayOfYear % quotes.length;
    
    return quotes[quoteIndex];
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}

// Modelo para las sugerencias
class SuggestedHabit {
  final String name;
  final String category;
  
  SuggestedHabit({required this.name, required this.category});
}