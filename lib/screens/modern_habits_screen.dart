// lib/screens/modern_habits_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../models/habit.dart';
import '../models/suggested_habit.dart';
import 'vito_chat_habit_screen.dart';
import '../services/notification_service.dart';

// Controllers
import '../controllers/habits_controller.dart';
import '../controllers/timer_controller.dart';
import '../controllers/tutorial_controller.dart';

// Widgets
import '../widgets/progress_card.dart';
import '../widgets/habits_app_bar.dart';
import '../widgets/suggestions_section.dart';
import '../widgets/coach_welcome_view.dart';
import '../widgets/habit_cards/habit_card_factory.dart';
import '../widgets/tutorial/tutorial_overlay.dart';

class ModernHabitsScreen extends StatefulWidget {
  const ModernHabitsScreen({super.key});

  @override
  State<ModernHabitsScreen> createState() => _ModernHabitsScreenState();
}

class _ModernHabitsScreenState extends State<ModernHabitsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingAnimationController;
  late AnimationController _pulseAnimationController;
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..forward();
    _floatingAnimationController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _pulseAnimationController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _scrollController = ScrollController()
      ..addListener(() {
        if (mounted) {
          setState(() {
            _scrollOffset = _scrollController.offset;
          });
        }
      });
  }

  void _initializeServices() {
    NotificationService.scheduleDailyMoodReminder();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingAnimationController.dispose();
    _pulseAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Tus controladores no reciben argumentos, así que los creamos vacíos.
        ChangeNotifierProvider(create: (_) => HabitsController()),
        ChangeNotifierProvider(create: (_) => TimerController()),
        ChangeNotifierProvider(create: (_) => TutorialController()),
      ],
      child: Consumer3<HabitsController, TimerController, TutorialController>(
        builder: (context, habitsCtrl, timerCtrl, tutorialCtrl, child) {
          if (tutorialCtrl.showTutorial == false && habitsCtrl.userName.isNotEmpty) {
            tutorialCtrl.checkOnboardingStatus();
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Stack(
              children: [
                _buildMainContent(habitsCtrl, timerCtrl, tutorialCtrl),
                if (!tutorialCtrl.showTutorial) _buildIdeaChip(habitsCtrl),
                if (tutorialCtrl.showTutorial)
                  TutorialOverlay(
                    controller: tutorialCtrl,
                    userName: habitsCtrl.userName,
                    onComplete: _showAddHabitBottomSheet,
                  ),
              ],
            ),
            floatingActionButton: Container(
              key: tutorialCtrl.fabKey,
              child: _buildFloatingActionButton(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(HabitsController habitsCtrl, TimerController timerCtrl, TutorialController tutorialCtrl) {
    return AbsorbPointer(
      absorbing: tutorialCtrl.showTutorial,
      child: CustomScrollView(
        physics: tutorialCtrl.showTutorial ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
        controller: _scrollController,
        slivers: [
          HabitsAppBar(
            animationController: _animationController,
            scrollOffset: _scrollOffset,
            selectedDate: habitsCtrl.selectedDate,
            onDateChanged: habitsCtrl.updateSelectedDate,
            onPreviousDay: habitsCtrl.navigatePreviousDay,
            onNextDay: habitsCtrl.navigateNextDay,
            greeting: habitsCtrl.getGreeting(),
            quote: habitsCtrl.getMotivationalQuote(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                key: tutorialCtrl.progressCardKey,
                child: _buildProgressSection(habitsCtrl, tutorialCtrl),
              ),
            ),
          ),
          if (habitsCtrl.isLoadingSuggestions) _buildLoadingSuggestionsIndicator(),
          if (habitsCtrl.suggestedHabits.isNotEmpty)
            SuggestionsSection(
              suggestions: habitsCtrl.suggestedHabits,
              animationController: _animationController,
              onAddHabit: _addSuggestedHabitWithForm,
              onDismiss: habitsCtrl.clearSuggestions,
            ),
          _buildHabitsListHeader(habitsCtrl),
          _buildHabitsList(habitsCtrl, timerCtrl, tutorialCtrl),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildProgressSection(HabitsController habitsCtrl, TutorialController tutorialCtrl) {
    return StreamBuilder<QuerySnapshot>(
      stream: habitsCtrl.allHabitsStream,
      builder: (context, snapshot) {
        final allHabits = snapshot.data?.docs ?? [];
        
        // --- LLAMADA A PROGRESSCARD CORREGIDA ---
        if (tutorialCtrl.showTutorial) {
          return ProgressCard(
            allHabits: const [], // Se pasa una lista vacía
            totalHabits: 0,
            completedHabits: 0,
            progress: 0.0,
            streak: 0,
            animationController: _animationController,
          );
        }

        final progressData = habitsCtrl.getProgressForSelectedDay(allHabits);
        final streak = habitsCtrl.getStreakFromHabitsData(allHabits);

        return ProgressCard(
          allHabits: allHabits,
          totalHabits: progressData['total'] ?? 0,
          completedHabits: progressData['completed'] ?? 0,
          progress: progressData['progress'] ?? 0.0,
          streak: streak,
          animationController: _animationController,
        );
      },
    );
  }

  Widget _buildHabitsList(HabitsController habitsCtrl, TimerController timerCtrl, TutorialController tutorialCtrl) {
    if (tutorialCtrl.showTutorial) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: habitsCtrl.allHabitsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }

        final allHabits = snapshot.data!.docs;
        final habitsForDay = habitsCtrl.getHabitsForSelectedDay(allHabits);

        if (habitsForDay.isEmpty) {
          return _buildEmptyHabitsMessage();
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final habitDoc = habitsForDay[index];
              final data = habitDoc.data() as Map<String, dynamic>;
              
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + (index * 100)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                  );
                },
                child: HabitCardFactory.buildHabitCard(
                  habitId: habitDoc.id,
                  data: data,
                  selectedDate: habitsCtrl.selectedDate,
                  onToggleSimple: habitsCtrl.toggleSimpleHabit,
                  // --- LLAMADA FINAL Y CORRECTA ---
                  // Se pasa directamente la función del controlador que ahora solo pide (habitId, change)
                  onUpdateQuantifiable: habitsCtrl.updateQuantifiableProgress,
                  onStartTimer: timerCtrl.startTimer,
                  onStopTimer: timerCtrl.stopTimer,
                  onLongPress: _showEditHabitBottomSheet,
                  activeTimerHabitId: timerCtrl.activeTimerHabitId,
                  timerSecondsRemaining: timerCtrl.timerSecondsRemaining,
                ),
              );
            },
            childCount: habitsForDay.length,
          ),
        );
      },
    );
  }
  
  // --- WIDGETS Y FUNCIONES AUXILIARES (COMPLETOS Y SIN DUPLICADOS) ---

  SliverToBoxAdapter _buildLoadingSuggestionsIndicator() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 12),
                Text('Vito está pensando...', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHabitsListHeader(HabitsController habitsCtrl) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              habitsCtrl.isSameDay(habitsCtrl.selectedDate, DateTime.now()) ? "Hábitos de hoy" : "Hábitos del ${DateFormat('d MMM', 'es_ES').format(habitsCtrl.selectedDate)}",
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
            ),
            Text('Toca para completar', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildEmptyHabitsMessage() {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(60.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: Icon(Icons.event_available, size: 40, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              Text('No hay hábitos para este día', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('Agrega uno nuevo para empezar', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdeaChip(HabitsController habitsCtrl) {
    return Positioned(
      bottom: 95, right: 20,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          final categories = ['Salud', 'Mente', 'Trabajo', 'Creativo', 'Finanzas'];
          final randomCategory = categories[math.Random().nextInt(categories.length)];
          habitsCtrl.getAiHabitSuggestions(randomCategory);
        },
        child: Material(
          color: Colors.white, elevation: 6,
          shadowColor: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Ideas', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + (_pulseAnimationController.value * 0.05),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20 + (_pulseAnimationController.value * 10), offset: const Offset(0, 10))],
            ),
            child: FloatingActionButton(
              onPressed: _showAddHabitBottomSheet,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }
  
  void _showAddHabitBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const VitoChatHabitSheet());
  }

  void _addSuggestedHabitWithForm(SuggestedHabit habit) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => VitoChatHabitSheet(initialMessage: habit.name))
        .then((_) {
      if (mounted) context.read<HabitsController>().removeSuggestion(habit);
    });
  }

  void _showEditHabitBottomSheet(String habitId, Map<String, dynamic> data) {
    // --- CONSTRUCTOR CORREGIDO SIN 'fromMap' ---
    // Se construye el objeto Habit directamente con su constructor por defecto.
    final timeData = data['specificTime'] as Map<String, dynamic>? ?? {'hour': 12, 'minute': 0};
    final habit = Habit(
      id: habitId,
      name: data['name'] ?? 'Sin nombre',
      category: data['category'] ?? 'health',
      days: List<int>.from(data['days'] ?? []),
      specificTime: TimeOfDay(hour: timeData['hour'], minute: timeData['minute']),
      notifications: data['notifications'] ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
      type: data['type'] as String? ?? 'simple',
      completions: Map<String, dynamic>.from(data['completions'] ?? {}),
      targetValue: data['targetValue'] as int?,
      unit: data['unit'] as String?,
    );
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => VitoChatHabitSheet(habit: habit));
  }
}