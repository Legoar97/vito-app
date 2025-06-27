import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;

import '../services/vertex_ai_service.dart';

// --- Widget Principal del Onboarding ---
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;
  late AnimationController _floatingAnimationController;
  int _currentPage = 0;

  // Datos del usuario
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedGoals = {};
  final Set<String> _selectedAreas = {};
  String _experienceLevel = '';

  // Hábitos generados por IA
  bool _isLoadingSuggestions = false;
  final List<Map<String, dynamic>> _suggestedHabits = [];
  final Set<int> _selectedHabitIndices = {};

  @override
  void initState() {
    super.initState();
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _scaleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _floatingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _loadUserName();
  }
  
  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      if (mounted) setState(() => _nameController.text = user.displayName!);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() => _nameController.text = userDoc.data()?['displayName'] ?? '');
      }
    } catch (e) {
      print("Error al cargar el nombre de usuario: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
    _floatingAnimationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _fadeAnimationController.forward(from: 0.0);
    _slideAnimationController.forward(from: 0.0);
    _scaleAnimationController.forward(from: 0.0);
    HapticFeedback.lightImpact();
  }

  void _nextPage() {
    if (!_validateCurrentPage()) return;
    if (_currentPage == 4) _generateHabitSuggestions();
    _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
  }

  void _previousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 1: if (_nameController.text.trim().isEmpty) return _showError('Por favor, dinos tu nombre'); return true;
      case 2: if (_selectedGoals.isEmpty) return _showError('Elige al menos un objetivo'); return true;
      case 3: if (_selectedAreas.isEmpty) return _showError('Elige al menos un área de enfoque'); return true;
      case 4: if (_experienceLevel.isEmpty) return _showError('Selecciona tu nivel de experiencia'); return true;
      case 5: if (_selectedHabitIndices.isEmpty) return _showError('Selecciona al menos un hábito para empezar'); return true;
      default: return true;
    }
  }

  bool _showError(String message) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
    return false;
  }

  Future<void> _generateHabitSuggestions() async {
    setState(() => _isLoadingSuggestions = true);
    final userProfileContext = {
      'goals': _selectedGoals.toList(), 
      'interests': _selectedAreas.toList(), 
      'experienceLevel': _experienceLevel,
      'language': 'es' // Asegurarnos de que responda en español
    };
    try {
      // NOTA: Asegúrate de que VertexAIService.getOnboardingSuggestions 
      // incluya en el prompt que las respuestas deben ser en español
      final jsonResponse = await VertexAIService.getOnboardingSuggestions(userProfileContext);
      if (mounted) {
        final suggestions = jsonDecode(jsonResponse)['habits'] as List;
        setState(() {
          _suggestedHabits.clear();
          _suggestedHabits.addAll(List<Map<String, dynamic>>.from(suggestions));
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoadingSuggestions = false);
        _showError('No pudimos conectar con la IA. Intenta de nuevo.');
        _previousPage();
      }
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_validateCurrentPage()) return;
    HapticFeedback.heavyImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.updateDisplayName(_nameController.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': _nameController.text.trim(), 'onboardingCompleted': true, 'profile': {'goals': _selectedGoals.toList(), 'interests': _selectedAreas.toList(), 'experienceLevel': _experienceLevel},
      }, SetOptions(merge: true));
      final batch = FirebaseFirestore.instance.batch();
      final habitsCollection = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('habits');
      for (final index in _selectedHabitIndices) {
        final habit = _suggestedHabits[index];
        final newHabitRef = habitsCollection.doc();
        batch.set(newHabitRef, {'name': habit['name'], 'category': habit['category'], 'days': [1, 2, 3, 4, 5, 6, 7], 'specificTime': {'hour': 8, 'minute': 0}, 'notifications': true, 'completions': [], 'createdAt': Timestamp.now(), 'streak': 0, 'longestStreak': 0});
      }
      await batch.commit();
      if (mounted) context.go('/home');
    } catch (e) {
      _showError('Ocurrió un error al guardar tu perfil.');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Fondo con gradiente animado
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.05),
                    AppColors.secondary.withOpacity(0.03),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
          
          // Círculos decorativos flotantes
          ..._buildFloatingShapes(),
          
          SafeArea(
            child: Column(
              children: [
                // Header con progreso elegante
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (_currentPage > 0)
                            GestureDetector(
                              onTap: _previousPage,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Color(0xFF64748B),
                                  size: 18,
                                ),
                              ),
                            )
                          else const SizedBox(width: 44),
                          
                          Expanded(
                            child: Center(
                              child: Text(
                                'Paso ${_currentPage + 1} de 7',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 44),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Barra de progreso elegante
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            height: 8,
                            width: MediaQuery.of(context).size.width * (_currentPage + 1) / 7,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(4),
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
                    ],
                  ),
                ),
                
                // Contenido principal
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    children: [
                      _buildWelcomePage(),
                      _buildNamePage(),
                      _buildGoalsPage(),
                      _buildAreasPage(),
                      _buildExperiencePage(),
                      _buildHabitSuggestionsPage(),
                      _buildCompletionPage(),
                    ],
                  ),
                ),
                
                // Botón de acción flotante
                if (_currentPage < 6)
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: _buildPremiumButton(
                      onPressed: _isLoadingSuggestions ? null : (_currentPage == 5 ? _completeOnboarding : _nextPage),
                      text: _currentPage == 5 ? 'Finalizar' : 'Continuar',
                      isLoading: _isLoadingSuggestions,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget de botón premium
  Widget _buildPremiumButton({
    required VoidCallback? onPressed,
    required String text,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey[400]!, Colors.grey[300]!],
                ),
                            borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // Formas flotantes decorativas
  List<Widget> _buildFloatingShapes() {
    return [
      AnimatedBuilder(
        animation: _floatingAnimationController,
        builder: (context, child) {
          return Positioned(
            top: 100 + (20 * math.sin(_floatingAnimationController.value * 2 * math.pi)),
            right: -50,
            child: Transform.rotate(
              angle: _floatingAnimationController.value * 2 * math.pi,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
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
            bottom: 150 + (15 * math.cos(_floatingAnimationController.value * 2 * math.pi)),
            left: -80,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  // --- Páginas del Onboarding ---

  Widget _buildWelcomePage() {
    final name = _nameController.text.isNotEmpty ? _nameController.text.split(' ').first : '';
    return _OnboardingStep(
      fadeAnimation: _fadeAnimationController,
      slideAnimation: _slideAnimationController,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _scaleAnimationController,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                Icons.spa_outlined,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            name.isNotEmpty ? 'Hola, $name' : 'Bienvenido a Vito',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Tu compañero personal para crear\nhábitos que transforman tu vida',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: const Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNamePage() {
    return _OnboardingStep(
      fadeAnimation: _fadeAnimationController,
      slideAnimation: _slideAnimationController,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¿Cómo te llamas?',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Me encantaría conocerte mejor',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Escribe tu nombre',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
              onChanged: (_) => HapticFeedback.selectionClick(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalsPage() {
    final goals = [
      {'id': 'health', 'title': 'Salud óptima', 'icon': Icons.favorite, 'gradient': [const Color(0xFFFF6B6B), const Color(0xFFFF8787)]},
      {'id': 'productivity', 'title': 'Productividad', 'icon': Icons.rocket_launch, 'gradient': [const Color(0xFF4ECDC4), const Color(0xFF44A08D)]},
      {'id': 'stress', 'title': 'Paz mental', 'icon': Icons.self_improvement, 'gradient': [const Color(0xFF667EEA), const Color(0xFF764BA2)]},
      {'id': 'happiness', 'title': 'Felicidad', 'icon': Icons.sentiment_very_satisfied, 'gradient': [const Color(0xFFF6D365), const Color(0xFFFDA085)]},
      {'id': 'growth', 'title': 'Crecimiento', 'icon': Icons.trending_up, 'gradient': [const Color(0xFF5EE7DF), const Color(0xFF66A6FF)]},
      {'id': 'balance', 'title': 'Balance', 'icon': Icons.balance, 'gradient': [const Color(0xFFA8EDEA), const Color(0xFFFED6E3)]},
    ];
    
    return _buildSelectionGrid(
      title: '¿Qué buscas lograr?',
      subtitle: 'Selecciona todos los que te inspiren',
      items: goals,
      selectedItems: _selectedGoals,
      onTap: (id) => setState(() {
        if (_selectedGoals.contains(id)) {
          _selectedGoals.remove(id);
        } else {
          _selectedGoals.add(id);
        }
        HapticFeedback.lightImpact();
      }),
    );
  }
  
  Widget _buildAreasPage() {
    final areas = [
      {'id': 'fitness', 'title': 'Fitness', 'icon': Icons.fitness_center, 'gradient': [const Color(0xFFFA709A), const Color(0xFFFEE140)]},
      {'id': 'mindfulness', 'title': 'Mindfulness', 'icon': Icons.spa, 'gradient': [const Color(0xFF8EC5FC), const Color(0xFFE0C3FC)]},
      {'id': 'nutrition', 'title': 'Nutrición', 'icon': Icons.restaurant, 'gradient': [const Color(0xFFD299C2), const Color(0xFFFEF9D7)]},
      {'id': 'sleep', 'title': 'Descanso', 'icon': Icons.bedtime, 'gradient': [const Color(0xFF89F7FE), const Color(0xFF66A6FF)]},
      {'id': 'creativity', 'title': 'Creatividad', 'icon': Icons.palette, 'gradient': [const Color(0xFFFDDB92), const Color(0xFFD1FDFF)]},
      {'id': 'social', 'title': 'Conexiones', 'icon': Icons.people, 'gradient': [const Color(0xFFB6CEE8), const Color(0xFFF578DC)]},
    ];
    
    return _buildSelectionGrid(
      title: 'Áreas de enfoque',
      subtitle: 'Elige las que más te interesen',
      items: areas,
      selectedItems: _selectedAreas,
      onTap: (id) => setState(() {
        if (_selectedAreas.contains(id)) {
          _selectedAreas.remove(id);
        } else {
          _selectedAreas.add(id);
        }
        HapticFeedback.lightImpact();
      }),
    );
  }
  
  Widget _buildSelectionGrid({
    required String title,
    String? subtitle,
    required List<Map<String, dynamic>> items,
    required Set<String> selectedItems,
    required Function(String) onTap,
  }) {
    return _OnboardingStep(
      fadeAnimation: _fadeAnimationController,
      slideAnimation: _slideAnimationController,
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 28),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedItems.contains(item['id']);
                return _ModernSelectionCard(
                  title: item['title'],
                  icon: item['icon'],
                  gradient: item['gradient'] ?? [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                  isSelected: isSelected,
                  onTap: () => onTap(item['id']),
                  delay: index * 50,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperiencePage() {
    final levels = [
      {
        'id': 'beginner',
        'title': 'Principiante',
        'subtitle': 'Estoy empezando mi viaje',
        'icon': Icons.eco,
        'gradient': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
      },
      {
        'id': 'intermediate',
        'title': 'Intermedio',
        'subtitle': 'Tengo algo de experiencia',
        'icon': Icons.local_fire_department,
        'gradient': [const Color(0xFFEB3349), const Color(0xFFF45C43)],
      },
      {
        'id': 'advanced',
        'title': 'Avanzado',
        'subtitle': 'Soy un veterano de hábitos',
        'icon': Icons.star,
        'gradient': [const Color(0xFFF2994A), const Color(0xFFF2C94C)],
      },
    ];
    
    return _OnboardingStep(
      fadeAnimation: _fadeAnimationController,
      slideAnimation: _slideAnimationController,
      child: Column(
        children: [
          Text(
            'Tu experiencia',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '¿Cuánto has trabajado con hábitos?',
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final level = levels[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ExperienceLevelCard(
                    title: level['title'] as String,
                    subtitle: level['subtitle'] as String,
                    icon: level['icon'] as IconData,
                    gradient: level['gradient'] as List<Color>,
                    isSelected: _experienceLevel == level['id'],
                    onTap: () => setState(() {
                      _experienceLevel = level['id'] as String;
                      HapticFeedback.lightImpact();
                    }),
                    delay: index * 100,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitSuggestionsPage() {
    return _OnboardingStep(
      fadeAnimation: _fadeAnimationController,
      slideAnimation: _slideAnimationController,
      child: _isLoadingSuggestions
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Loader personalizado
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              value: value * 0.7,
                              strokeWidth: 4,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'La IA está creando\ntu plan personalizado',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esto tomará solo un momento...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu plan personalizado',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Basado en tus objetivos y preferencias',
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
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _suggestedHabits.length,
                    itemBuilder: (context, index) {
                      final habit = _suggestedHabits[index];
                      return _HabitSuggestionCard(
                        title: habit['name'],
                        category: habit['category'],
                        isSelected: _selectedHabitIndices.contains(index),
                        onTap: () => setState(() {
                          if (_selectedHabitIndices.contains(index)) {
                            _selectedHabitIndices.remove(index);
                          } else {
                            _selectedHabitIndices.add(index);
                          }
                          HapticFeedback.lightImpact();
                        }),
                        delay: index * 50,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCompletionPage() {
    final name = _nameController.text.isNotEmpty ? _nameController.text.split(' ').first : '';
    return _OnboardingStep(
      fadeAnimation: _fadeAnimationController,
      slideAnimation: _slideAnimationController,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          Text(
            '¡Perfecto, $name!',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Todo está listo para comenzar\ntu transformación personal',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: const Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          _buildPremiumButton(
            onPressed: () => context.go('/home'),
            text: 'Comenzar ahora',
          ),
        ],
      ),
    );
  }
}

// --- Widgets Reutilizables Premium ---

class _OnboardingStep extends StatelessWidget {
  final Widget child;
  final Animation<double> fadeAnimation;
  final Animation<double> slideAnimation;
  
  const _OnboardingStep({
    required this.child,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([fadeAnimation, slideAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: slideAnimation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: child,
      ),
    );
  }
}

class _ModernSelectionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final bool isSelected;
  final VoidCallback onTap;
  final int delay;

  const _ModernSelectionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.isSelected,
    required this.onTap,
    this.delay = 0,
  });

  @override
  State<_ModernSelectionCard> createState() => _ModernSelectionCardState();
}

class _ModernSelectionCardState extends State<_ModernSelectionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    // Animación de entrada
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isSelected ? widget.gradient.first : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isSelected 
                        ? widget.gradient.first.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: widget.isSelected ? 20 : 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    if (widget.isSelected)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.gradient.map((c) => c.withOpacity(0.1)).toList(),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.isSelected
                                    ? widget.gradient
                                    : [Colors.grey[300]!, Colors.grey[400]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: Text(
                              widget.title,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.isSelected 
                                    ? widget.gradient.first
                                    : const Color(0xFF1E293B),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExperienceLevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final bool isSelected;
  final VoidCallback onTap;
  final int delay;

  const _ExperienceLevelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.isSelected,
    required this.onTap,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? gradient.first : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? gradient.first.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isSelected ? 20 : 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected ? gradient : [Colors.grey[300]!, Colors.grey[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? gradient.first : Colors.grey[400]!,
                    width: 2,
                  ),
                  color: isSelected ? gradient.first : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitSuggestionCard extends StatelessWidget {
  final String title;
  final String category;
  final bool isSelected;
  final VoidCallback onTap;
  final int delay;

  const _HabitSuggestionCard({
    required this.title,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getCategoryColor(category);
    final icon = AppColors.getCategoryIcon(category);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? color.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 20 : 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? color : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}