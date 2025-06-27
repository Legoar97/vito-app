import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../widgets/add_habit_bottom_sheet.dart';
import '../widgets/edit_habit_bottom_sheet.dart';

// --- Modelo para la Sugerencia de la IA ---
class SuggestedHabit {
  final String name;
  final String category;
  SuggestedHabit({required this.name, required this.category});
}

class ModernHabitsScreen extends StatefulWidget {
  const ModernHabitsScreen({super.key});

  @override
  State<ModernHabitsScreen> createState() => _ModernHabitsScreenState();
}

class _ModernHabitsScreenState extends State<ModernHabitsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  DateTime _selectedDate = DateTime.now();

  // --- Estados para la lógica del Coach AI ---
  bool _isLoadingSuggestions = false;
  List<SuggestedHabit> _suggestedHabits = [];
  bool _showCoachWelcome = false;

  Stream<QuerySnapshot>? _allHabitsStream;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _initializeStream();
    _checkIfFirstTime();
  }

  void _initializeStream() {
    if (user != null) {
      setState(() {
        _allHabitsStream = FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('habits')
            .snapshots();
      });
    }
  }

  // --- LÓGICA DEL COACH ---
  Future<void> _checkIfFirstTime() async {
    if (user == null) return;
    // Agregamos un pequeño retraso para asegurar que la UI de login/splash se haya ido.
    await Future.delayed(const Duration(seconds: 1)); 
    final snapshot = await FirebaseFirestore.instance
        .collection('users').doc(user!.uid).collection('habits').limit(1).get();
    if (snapshot.docs.isEmpty && mounted) {
      setState(() => _showCoachWelcome = true);
    }
  }

  Future<void> _getAiHabitSuggestions(String category) async {
    setState(() {
      _isLoadingSuggestions = true;
      _suggestedHabits = [];
    });

    // Simulación de llamada a Vertex AI
    await Future.delayed(const Duration(seconds: 2));
    final Map<String, List<String>> mockSuggestions = {
      'Salud': ['Beber un vaso de agua', 'Estirar por 10 minutos', 'Caminar 15 minutos'],
      'Mente': ['Meditar 5 minutos', 'Escribir un diario', 'Leer 10 páginas'],
      'Trabajo': ['Organizar tu escritorio', 'Planificar tus 3 tareas más importantes', 'Tomar un descanso de 5 min'],
      'Creativo': ['Dibujar algo simple', 'Escuchar música nueva', 'Escribir una idea'],
      'Finanzas': ['Anotar gastos del día', 'Revisar tu presupuesto', 'Aprender un término financiero'],
    };
    final suggestions = mockSuggestions[category] ?? [];

    if (mounted) {
      setState(() {
        _suggestedHabits = suggestions.map((name) => SuggestedHabit(name: name, category: category)).toList();
        _isLoadingSuggestions = false;
        _showCoachWelcome = false;
      });
    }
  }

  // CAMBIO: Ahora abre el formulario de agregar hábito con los datos precargados
  void _addSuggestedHabitWithForm(SuggestedHabit habit) {
    // Primero guardamos el hábito para removerlo después
    final habitToRemove = habit;
    
    // Convertir la categoría a formato correcto
    final categoryMap = {
      'Salud': 'health',
      'Mente': 'mind',
      'Trabajo': 'productivity',
      'Creativo': 'creativity',
      'Finanzas': 'finance',
    };
    
    // Pasamos los datos del hábito sugerido al formulario
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => AddHabitBottomSheet(
        prefilledName: habit.name,
        prefilledCategory: categoryMap[habit.category] ?? 'health',
      ),
    ).then((_) {
      // Cuando se cierre el modal, removemos la sugerencia de la lista
      if (mounted) {
        setState(() => _suggestedHabits.remove(habitToRemove));
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCoachWelcome) {
      return _buildCoachWelcomeView();
    }
    
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: StreamBuilder<QuerySnapshot>(
        stream: _allHabitsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final allHabits = snapshot.data?.docs ?? [];
          
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildProgressCard(allHabits),
                ),
              ),

              if (_isLoadingSuggestions)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16.0), child: LinearProgressIndicator())),
              if (_suggestedHabits.isNotEmpty)
                _buildSuggestionsSection(),

              _buildHabitsListHeader(),
              _buildHabitsList(allHabits),
              _buildCategoriesHeader(),
              _buildCategoriesSection(),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoachWelcomeView() {
    final categories = [
      {'name': 'Salud', 'icon': Icons.favorite, 'color': AppColors.categoryHealth},
      {'name': 'Mente', 'icon': Icons.self_improvement, 'color': AppColors.categoryMind},
      {'name': 'Trabajo', 'icon': Icons.work, 'color': AppColors.categoryProductivity},
      {'name': 'Creativo', 'icon': Icons.palette, 'color': AppColors.categoryCreativity},
      {'name': 'Finanzas', 'icon': Icons.attach_money, 'color': AppColors.categoryFinance},
    ];
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.spa, size: 60, color: AppColors.primary),
              const SizedBox(height: 20),
              Text(
                "¡Hola! Soy Vito",
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Tu coach personal de bienestar. Para empezar, dime, ¿en qué área te gustaría enfocarte hoy?",
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: categories.map((category) => ElevatedButton.icon(
                  icon: Icon(category['icon'] as IconData, color: Colors.white),
                  label: Text(category['name'] as String),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: category['color'] as Color,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _getAiHabitSuggestions(category['name'] as String),
                )).toList(),
              )
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSuggestionsSection() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Sugerencias para ti:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(onPressed: () => setState(() => _suggestedHabits = []), icon: const Icon(Icons.close, size: 20)),
              ],
            ),
            const SizedBox(height: 8),
            ..._suggestedHabits.map((habit) => ListTile(
              title: Text(habit.name),
              leading: const Icon(Icons.lightbulb_outline, color: AppColors.primary),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.success, size: 30),
                onPressed: () => _addSuggestedHabitWithForm(habit), // CAMBIO AQUÍ
              ),
            )),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -30, right: -30, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)))),
              Positioned(bottom: -20, left: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)))),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Text(_getGreeting(), style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis, maxLines: 1),
                      Text(_getMotivationalQuote(), style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.9)), overflow: TextOverflow.ellipsis, maxLines: 1),
                      const SizedBox(height: 12),
                      Expanded(child: Center(child: _buildWeekSelectorWithNavigation())),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? '';
    if (hour < 12) return 'Buenos días${name.isNotEmpty ? ", $name" : ""}';
    if (hour < 18) return 'Buenas tardes${name.isNotEmpty ? ", $name" : ""}';
    return 'Buenas noches${name.isNotEmpty ? ", $name" : ""}';
  }

  String _getMotivationalQuote() {
    final quotes = ['Pequeños pasos llevan a grandes cambios', 'Progreso, no perfección', 'Lo estás haciendo increíble', 'Sigue adelante, ¡puedes lograrlo!', 'Cada día es un nuevo comienzo'];
    return quotes[DateTime.now().day % quotes.length];
  }

  Widget _buildWeekSelectorWithNavigation() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 36, child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24))),
        Expanded(child: _buildWeekSelector()),
        SizedBox(width: 36, child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right, color: Colors.white, size: 24))),
      ],
    );
  }

  Widget _buildWeekSelector() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, DateTime.now());
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 45,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? Colors.white : (isToday ? Colors.white.withOpacity(0.5) : Colors.transparent), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat.E('es_ES').format(date).substring(0, 2).toUpperCase(), style: TextStyle(color: isSelected ? AppColors.primary : Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
                  Text(DateFormat.d().format(date), style: TextStyle(color: isSelected ? AppColors.primary : Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  if (isToday) Container(margin: const EdgeInsets.only(top: 1), width: 3, height: 3, decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.white, shape: BoxShape.circle)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  int _getStreakFromHabitsData(List<QueryDocumentSnapshot> habits) {
    if (habits.isEmpty) return 0;
    final Set<DateTime> allCompletionDates = {};
    final Set<int> allScheduledWeekdays = {};
    for (var habitDoc in habits) {
      final data = habitDoc.data() as Map<String, dynamic>;
      final completions = List<Timestamp>.from(data['completions'] ?? []);
      final days = List<int>.from(data['days'] ?? []);
      for (var ts in completions) {
        final date = ts.toDate();
        allCompletionDates.add(DateTime(date.year, date.month, date.day));
      }
      allScheduledWeekdays.addAll(days);
    }
    if (allCompletionDates.isEmpty || allScheduledWeekdays.isEmpty) return 0;
    int streak = 0;
    var now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    if (allScheduledWeekdays.contains(checkDate.weekday) && !allCompletionDates.contains(checkDate)) {
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

  Widget _buildProgressCard(List<QueryDocumentSnapshot> allHabits) {
    int totalHabitsForSelectedDay = 0;
    int completedOnSelectedDay = 0;
    for (var habit in allHabits) {
      final data = habit.data() as Map<String, dynamic>;
      final days = List<int>.from(data['days'] ?? []);
      if (days.contains(_selectedDate.weekday)) {
        totalHabitsForSelectedDay++;
        final completions = List<Timestamp>.from(data['completions'] ?? []);
        if (_wasCompletedOnDate(_selectedDate, completions)) {
          completedOnSelectedDay++;
        }
      }
    }
    final progress = totalHabitsForSelectedDay > 0 ? completedOnSelectedDay / totalHabitsForSelectedDay : 0.0;
    final streak = _getStreakFromHabitsData(allHabits);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Progreso Diario', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              if (streak > 0)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, color: AppColors.success, size: 16),
                        const SizedBox(width: 4),
                        Flexible(child: Text('¡$streak día${streak != 1 ? 's' : ''} de racha!', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('$completedOnSelectedDay de $totalHabitsForSelectedDay hábitos completados', style: TextStyle(color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildCategoriesHeader() {
    return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 30, 20, 10), child: Text('Categorías', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600))));
  }

  SliverToBoxAdapter _buildCategoriesSection() {
    final categories = [
      {'name': 'Salud', 'icon': Icons.favorite, 'color': AppColors.categoryHealth},
      {'name': 'Mente', 'icon': Icons.self_improvement, 'color': AppColors.categoryMind},
      {'name': 'Trabajo', 'icon': Icons.work, 'color': AppColors.categoryProductivity},
      {'name': 'Creativo', 'icon': Icons.palette, 'color': AppColors.categoryCreativity},
      {'name': 'Finanzas', 'icon': Icons.attach_money, 'color': AppColors.categoryFinance},
    ];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () => _getAiHabitSuggestions(category['name'] as String),
              child: Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 60, height: 60, decoration: BoxDecoration(color: (category['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Icon(category['icon'] as IconData, color: category['color'] as Color, size: 28)),
                    const SizedBox(height: 8),
                    Flexible(child: Text(category['name'] as String, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]))),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHabitsListHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(_isSameDay(_selectedDate, DateTime.now()) ? "Hábitos de Hoy" : "Hábitos del ${DateFormat('d MMM', 'es_ES').format(_selectedDate)}", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            TextButton.icon(onPressed: () => _showAddHabitBottomSheet(), icon: const Icon(Icons.add_circle_outline, size: 20), label: const Text('Agregar'), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsList(List<QueryDocumentSnapshot> allHabits) {
    final habitsForDay = allHabits.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final days = List<int>.from(data?['days'] ?? []);
      return days.contains(_selectedDate.weekday);
    }).toList();

    if (habitsForDay.isEmpty) {
      return SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_available, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), Text('No hay hábitos para este día', style: TextStyle(fontSize: 16, color: Colors.grey[600]))]))));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final habit = habitsForDay[index];
          final data = habit.data() as Map<String, dynamic>;
          return _buildModernHabitCard(habit.id, data);
        },
        childCount: habitsForDay.length,
      ),
    );
  }

  Widget _buildModernHabitCard(String habitId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Hábito sin nombre';
    final category = data['category'] ?? 'health';
    final completions = List<Timestamp>.from(data['completions'] ?? []);
    final isCompleted = _wasCompletedOnDate(_selectedDate, completions);
    final timeData = data['specificTime'] as Map<String, dynamic>?;
    final color = AppColors.getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleHabit(habitId, completions),
          onLongPress: () => _showEditHabitBottomSheet(habitId, data),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isCompleted ? color : Colors.grey[200]!, width: 2),
              boxShadow: [if (!isCompleted) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isCompleted ? color : Colors.grey[300]!, width: 2),
                  ),
                  child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: isCompleted ? color : Colors.black87, decoration: isCompleted ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis),
                      if (timeData != null) Text(_formatTime(timeData), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddHabitBottomSheet() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => const AddHabitBottomSheet(), // Sin parámetros para crear nuevo
    );
  }

  void _showEditHabitBottomSheet(String habitId, Map<String, dynamic> data) {
    final timeData = data['specificTime'] as Map<String, dynamic>? ?? {'hour': 12, 'minute': 0};
    final time = TimeOfDay(hour: timeData['hour'], minute: timeData['minute']);
    final habit = Habit(
      id: habitId,
      name: data['name'] ?? 'Sin nombre',
      category: data['category'] ?? 'health',
      days: List<int>.from(data['days'] ?? []),
      completions: List<Timestamp>.from(data['completions'] ?? []),
      specificTime: time,
      notifications: data['notifications'] ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
    );
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => EditHabitBottomSheet(habit: habit));
  }

  Future<void> _toggleHabit(String habitId, List<Timestamp> completions) async {
    if (!_isSameDay(_selectedDate, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo puedes modificar los hábitos del día de hoy.'), backgroundColor: AppColors.warning));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final selectedTimestamp = Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));
    final isCompleted = _wasCompletedOnDate(_selectedDate, completions);
    final habitRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('habits').doc(habitId);
    if (isCompleted) {
      final completionToRemove = completions.firstWhere((ts) => _isSameDay(ts.toDate(), _selectedDate));
      await habitRef.update({'completions': FieldValue.arrayRemove([completionToRemove])});
    } else {
      await habitRef.update({'completions': FieldValue.arrayUnion([selectedTimestamp])});
      if (mounted) HapticFeedback.lightImpact();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _wasCompletedOnDate(DateTime date, List<Timestamp> completions) {
    return completions.any((ts) => _isSameDay(ts.toDate(), date));
  }

  String _formatTime(Map<String, dynamic> timeData) {
    final hour = timeData['hour'] as int;
    final minute = timeData['minute'] as int;
    final time = TimeOfDay(hour: hour, minute: minute);
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat.jm('es_ES').format(dateTime);
  }
}