import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;

import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../screens/vito_chat_habit_screen.dart'; 

// Modelo para la Sugerencia de la IA
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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingAnimationController;
  late AnimationController _pulseAnimationController;
  DateTime _selectedDate = DateTime.now();

  // Estados para la lógica del Coach AI
  bool _isLoadingSuggestions = false;
  List<SuggestedHabit> _suggestedHabits = [];
  bool _showCoachWelcome = false;

  Stream<QuerySnapshot>? _allHabitsStream;
  final User? user = FirebaseAuth.instance.currentUser;

  // Estado para el tracker de ánimo
  String? _currentMood;

  // Controllers para animaciones
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    
    _floatingAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
    
    if (user != null) {
      _initializeStream();
      _checkIfFirstTime();
      _loadTodaysMood();
    }
  }

  void _initializeStream() {
    setState(() {
      _allHabitsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('habits')
          .snapshots();
    });
  }

  Future<void> _checkIfFirstTime() async {
    if (user == null) return;
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

  void _addSuggestedHabitWithForm(SuggestedHabit habit) {
    final habitToRemove = habit;
    
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      // --- CORRECCIÓN FINAL AQUÍ ---
      builder: (context) => VitoChatHabitSheet(
        // Le pasamos el nombre del hábito como el primer mensaje del usuario
        initialMessage: habit.name,
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _suggestedHabits.remove(habitToRemove));
      }
    });
  }

  Future<void> _loadTodaysMood() async {
    if (user == null) return;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await FirebaseFirestore.instance
      .collection('users').doc(user!.uid)
      .collection('mood_tracker').doc(todayStr).get();
    
    if (doc.exists && mounted) {
      setState(() {
        _currentMood = doc.data()?['mood'];
      });
    }
  }

  Future<void> _saveMood(String mood) async {
    if (user == null) return;
    HapticFeedback.lightImpact();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (_currentMood == mood) {
      await FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('mood_tracker').doc(todayStr).delete();
      if(mounted) setState(() => _currentMood = null);
    } else {
      await FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('mood_tracker').doc(todayStr)
        .set({'mood': mood, 'timestamp': FieldValue.serverTimestamp()});
    
      if (mounted) {
        setState(() => _currentMood = mood);
        _showSuccessSnackBar('¡Ánimo registrado!');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ), 
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      )
    );
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
    if (_showCoachWelcome) {
      return _buildCoachWelcomeView();
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Fondo con gradiente sutil
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.02),
                  AppColors.secondary.withOpacity(0.01),
                  Colors.white,
                ],
              ),
            ),
          ),
          // Formas decorativas animadas
          ..._buildFloatingShapes(),
          
          StreamBuilder<QuerySnapshot>(
            stream: _allHabitsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final allHabits = snapshot.data?.docs ?? [];
              
              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildPremiumSliverAppBar(),
                  _buildPremiumMoodTracker(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildPremiumProgressCard(allHabits),
                    ),
                  ),
                  if (_isLoadingSuggestions)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Vito está pensando...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_suggestedHabits.isNotEmpty)
                    _buildPremiumSuggestionsSection(),
                  _buildPremiumHabitsListHeader(),
                  _buildHabitIdeaSection(),
                  _buildPremiumHabitsList(allHabits),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // Botón flotante premium
  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + (_pulseAnimationController.value * 0.05),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20 + (_pulseAnimationController.value * 10),
                  offset: const Offset(0, 10),
                ),
              ],
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

  // Formas flotantes decorativas
  List<Widget> _buildFloatingShapes() {
    return [
      AnimatedBuilder(
        animation: _floatingAnimationController,
        builder: (context, child) {
          return Positioned(
            top: 100 + (30 * math.sin(_floatingAnimationController.value * 2 * math.pi)),
            right: -60,
            child: Transform.rotate(
              angle: _floatingAnimationController.value * math.pi,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _floatingAnimationController,
        builder: (context, child) {
          return Positioned(
            bottom: 200 + (20 * math.cos(_floatingAnimationController.value * 2 * math.pi)),
            left: -80,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.08),
                    AppColors.secondary.withOpacity(0.01),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  // Mood Tracker Premium
  SliverToBoxAdapter _buildPremiumMoodTracker() {
    final moods = [
      {'name': 'Feliz', 'icon': Icons.sentiment_very_satisfied, 'color': const Color(0xFF4ADE80), 'gradient': [const Color(0xFF4ADE80), const Color(0xFF22C55E)]},
      {'name': 'Normal', 'icon': Icons.sentiment_satisfied, 'color': const Color(0xFF60A5FA), 'gradient': [const Color(0xFF60A5FA), const Color(0xFF3B82F6)]},
      {'name': 'Triste', 'icon': Icons.sentiment_dissatisfied, 'color': const Color(0xFF94A3B8), 'gradient': [const Color(0xFF94A3B8), const Color(0xFF64748B)]},
      {'name': 'Estresado', 'icon': Icons.bolt, 'color': const Color(0xFFFBBF24), 'gradient': [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]},
      {'name': 'Motivado', 'icon': Icons.local_fire_department, 'color': const Color(0xFFF87171), 'gradient': [const Color(0xFFF87171), const Color(0xFFEF4444)]},
    ];

    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          )),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¿Cómo te sientes?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'Registra tu estado de ánimo',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: moods.map((moodData) {
                          final moodName = moodData['name'] as String;
                          final moodIcon = moodData['icon'] as IconData;
                          final gradientColors = moodData['gradient'] as List<Color>;
                          final isSelected = _currentMood == moodName;

                          return GestureDetector(
                            onTap: () => _saveMood(moodName),
                            child: AnimatedScale(
                              scale: isSelected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: EdgeInsets.all(isSelected ? 14 : 12),
                                decoration: BoxDecoration(
                                  gradient: isSelected 
                                    ? LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                  color: isSelected ? null : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: gradientColors.first.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ] : [],
                                ),
                                child: Icon(
                                  moodIcon,
                                  color: isSelected ? Colors.white : Colors.grey.shade600,
                                  size: 26,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_currentMood != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _currentMood!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoachWelcomeView() {
    final categories = [
      {'name': 'Salud', 'icon': Icons.favorite_rounded, 'color': AppColors.categoryHealth, 'gradient': [const Color(0xFF4ADE80), const Color(0xFF22C55E)]},
      {'name': 'Mente', 'icon': Icons.self_improvement, 'color': AppColors.categoryMind, 'gradient': [const Color(0xFF818CF8), const Color(0xFF6366F1)]},
      {'name': 'Trabajo', 'icon': Icons.work_rounded, 'color': AppColors.categoryProductivity, 'gradient': [const Color(0xFF60A5FA), const Color(0xFF3B82F6)]},
      {'name': 'Creativo', 'icon': Icons.palette_rounded, 'color': AppColors.categoryCreativity, 'gradient': [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]},
      {'name': 'Finanzas', 'icon': Icons.attach_money_rounded, 'color': AppColors.categoryFinance, 'gradient': [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)]},
    ];
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.spa,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "¡Hola! Soy Vito",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Tu coach personal de bienestar.\n¿En qué área te gustaría enfocarte hoy?",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: categories.map((category) {
                    final gradientColors = category['gradient'] as List<Color>;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _getAiHabitSuggestions(category['name'] as String);
                      },
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: gradientColors.first.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              category['icon'] as IconData,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category['name'] as String,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildPremiumSuggestionsSection() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeIn,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.08),
                AppColors.primary.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Vito sugiere:",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _suggestedHabits = []);
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._suggestedHabits.asMap().entries.map((entry) {
                final index = entry.key;
                final habit = entry.value;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            habit.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _addSuggestedHabitWithForm(habit),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.success, Color(0xFF22C55E)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildPremiumSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
                AppColors.secondary.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Patrón de fondo
              Positioned.fill(
                child: CustomPaint(
                  painter: _PatternPainter(),
                ),
              ),
              // Círculos decorativos con parallax
              Positioned(
                top: -50 - (_scrollOffset * 0.5),
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -40 - (_scrollOffset * 0.3),
                left: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _animationController,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.3, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Curves.easeOut,
                          )),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getMotivationalQuote(),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Center(
                          child: _buildPremiumWeekSelector(),
                        ),
                      ),
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
    final name = user?.displayName?.split(' ').first ?? '';
    if (hour < 12) return 'Buenos días${name.isNotEmpty ? ", $name" : ""}';
    if (hour < 18) return 'Buenas tardes${name.isNotEmpty ? ", $name" : ""}';
    return 'Buenas noches${name.isNotEmpty ? ", $name" : ""}';
  }

  String _getMotivationalQuote() {
    final quotes = [
      'Un paso a la vez, un día a la vez ✨',
      'Tu constancia es tu superpoder 💪',
      'Hoy es un gran día para brillar 🌟',
      'Pequeños cambios, grandes resultados 🚀',
      'Tu mejor versión te está esperando 🌱'
    ];
    return quotes[DateTime.now().day % quotes.length];
  }

  Widget _buildPremiumWeekSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            // --- CAMBIO AQUÍ: Retrocede un día ---
            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: _buildWeekDays(),
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            // --- CAMBIO AQUÍ: Avanza un día ---
            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildWeekDays() {
    // --- CAMBIO DE LÓGICA: El inicio es 2 días antes del seleccionado ---
    final startDay = _selectedDate.subtract(const Duration(days: 2));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) { // --- CAMBIO: Generamos solo 5 días ---
        final date = startDay.add(Duration(days: index));
        final isSelected = _isSameDay(date, _selectedDate);
        final isToday = _isSameDay(date, DateTime.now());

        // Pequeña animación para resaltar el día seleccionado
        final double scale = isSelected ? 1.1 : 1.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            // Si el usuario toca un día, la vista se centra en él
            setState(() => _selectedDate = date);
          },
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: 50,
              height: 75,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isToday && !isSelected
                      ? Colors.white.withOpacity(0.5)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E('es_ES').format(date).substring(0, 2).toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.d().format(date),
                    style: GoogleFonts.poppins(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        );
      }),
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

  Widget _buildPremiumProgressCard(List<QueryDocumentSnapshot> allHabits) {
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

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        )),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progreso de hoy',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '$completedOnSelectedDay de $totalHabitsForSelectedDay completados',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF87171), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$streak días',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Barra de progreso mejorada
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    height: 12,
                    width: MediaQuery.of(context).size.width * progress * 0.75,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(progress * 100).toInt()}% completado',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (progress == 1.0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '¡Día completo!',
                            style: GoogleFonts.poppins(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildHabitIdeaSection() {
    return SliverToBoxAdapter(
      child: Padding(
        // Un poco más de espacio vertical para que respire mejor
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            // Para mantenerlo simple, elegimos una categoría al azar para la IA.
            // El usuario no lo nota, pero nos da sugerencias variadas.
            final categories = ['Salud', 'Mente', 'Trabajo', 'Creativo', 'Finanzas'];
            final randomCategory = categories[math.Random().nextInt(categories.length)];
            _getAiHabitSuggestions(randomCategory);
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.05),
                  AppColors.secondary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ideas para Hábitos",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "Toca para recibir una sugerencia de la IA",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
  SliverToBoxAdapter _buildPremiumHabitsListHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSameDay(_selectedDate, DateTime.now()) 
                      ? "Hábitos de hoy" 
                      : "Hábitos del ${DateFormat('d MMM', 'es_ES').format(_selectedDate)}",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Toca para completar',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHabitsList(List<QueryDocumentSnapshot> allHabits) {
    final habitsForDay = allHabits.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final days = List<int>.from(data?['days'] ?? []);
      return days.contains(_selectedDate.weekday);
    }).toList();

    if (habitsForDay.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No hay hábitos para este día',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Agrega uno nuevo para empezar',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final habit = habitsForDay[index];
          final data = habit.data() as Map<String, dynamic>;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: _buildPremiumHabitCard(habit.id, data),
          );
        },
        childCount: habitsForDay.length,
      ),
    );
  }

  Widget _buildPremiumHabitCard(String habitId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Hábito sin nombre';
    final category = data['category'] ?? 'health';
    final completions = List<Timestamp>.from(data['completions'] ?? []);
    final isCompleted = _wasCompletedOnDate(_selectedDate, completions);
    final timeData = data['specificTime'] as Map<String, dynamic>?;
    final color = AppColors.getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleHabit(habitId, completions),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showEditHabitBottomSheet(habitId, data);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompleted 
                ? color.withOpacity(0.05) 
                : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isCompleted ? color.withOpacity(0.3) : Colors.grey[200]!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCompleted 
                    ? color.withOpacity(0.15) 
                    : Colors.black.withOpacity(0.03),
                  blurRadius: isCompleted ? 20 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: isCompleted 
                      ? LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                        )
                      : null,
                    color: isCompleted ? null : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCompleted ? color : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: isCompleted 
                    ? const Icon(Icons.check, color: Colors.white, size: 22)
                    : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? color : const Color(0xFF1E293B),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: color.withOpacity(0.5),
                          decorationThickness: 2,
                        ),
                      ),
                      if (timeData != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(timeData),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.celebration,
                      color: color,
                      size: 20,
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
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => const VitoChatHabitSheet(),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VitoChatHabitSheet(habit: habit),
    );
  }

  Future<void> _toggleHabit(String habitId, List<Timestamp> completions) async {
    if (!_isSameDay(_selectedDate, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Solo puedes modificar los hábitos de hoy',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    
    if (user == null) return;
    HapticFeedback.lightImpact();
    
    final selectedTimestamp = Timestamp.fromDate(
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
    );
    final isCompleted = _wasCompletedOnDate(_selectedDate, completions);
    final habitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('habits')
        .doc(habitId);
        
    if (isCompleted) {
      final completionToRemove = completions.firstWhere(
        (ts) => _isSameDay(ts.toDate(), _selectedDate)
      );
      await habitRef.update({
        'completions': FieldValue.arrayRemove([completionToRemove])
      });
    } else {
      await habitRef.update({
        'completions': FieldValue.arrayUnion([selectedTimestamp])
      });
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSuccessSnackBar('¡Hábito completado! 🎉');
      }
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
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat.jm('es_ES').format(dateTime);
  }
}

// Custom painter para el patrón del header
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Dibujar círculos decorativos
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 3; j++) {
        canvas.drawCircle(
          Offset(i * 80.0 + 40, j * 80.0 + 40),
          20,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}