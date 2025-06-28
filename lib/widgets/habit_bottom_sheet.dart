import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;

import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';

class HabitBottomSheet extends StatefulWidget {
  final Habit? habit; // Si es null, estamos creando. Si tiene valor, estamos editando
  final String? prefilledName;
  final String? prefilledCategory;
  
  const HabitBottomSheet({
    super.key,
    this.habit,
    this.prefilledName,
    this.prefilledCategory,
  });

  @override
  State<HabitBottomSheet> createState() => _HabitBottomSheetState();
}

class _HabitBottomSheetState extends State<HabitBottomSheet>
    with TickerProviderStateMixin {
  // Controladores de animación
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _categoryAnimationController;
  
  // Controladores y estado
  late final TextEditingController _nameController;
  final Set<int> _selectedDays = {};
  late String _selectedCategory;
  late TimeOfDay _selectedTime;
  bool _enableNotifications = true;
  bool _isLoading = false;
  
  // Para animaciones de categorías
  String? _previousCategory;

  bool get isEditMode => widget.habit != null;

  @override
  void initState() {
    super.initState();
    
    // Inicializar animaciones
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _categoryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Inicializar valores
    if (isEditMode) {
      // Modo edición
      final habit = widget.habit!;
      _nameController = TextEditingController(text: habit.name);
      _selectedDays.addAll(habit.days);
      _selectedCategory = habit.category;
      _selectedTime = habit.specificTime;
      _enableNotifications = habit.notifications;
    } else {
      // Modo creación
      _nameController = TextEditingController(text: widget.prefilledName ?? '');
      _selectedCategory = widget.prefilledCategory ?? 'health';
      _selectedDays.addAll([1, 2, 3, 4, 5]); // L-V por defecto
      _selectedTime = const TimeOfDay(hour: 8, minute: 0);
    }
    
    _previousCategory = _selectedCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _categoryAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Fondo con gradiente sutil
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCategoryColor().withOpacity(0.03),
                      Colors.white,
                      _getCategoryColor().withOpacity(0.01),
                    ],
                  ),
                ),
              ),
            ),
            
            Column(
              children: [
                // Handle bar elegante
                FadeTransition(
                  opacity: _fadeController,
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey[300]!,
                          Colors.grey[400]!,
                          Colors.grey[300]!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),

                // Header 
                _buildHeader(),

                // Contenido principal con animación
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNameInput(),
                          const SizedBox(height: 32),
                          _buildSectionTitle('Categoría', Icons.category_rounded),
                          const SizedBox(height: 16),
                          _buildCategoryGrid(),
                          const SizedBox(height: 32),
                          _buildSectionTitle('Horario', Icons.schedule_rounded),
                          const SizedBox(height: 16),
                          _buildTimeSelector(),
                          const SizedBox(height: 32),
                          _buildSectionTitle('Frecuencia', Icons.event_repeat_rounded),
                          const SizedBox(height: 16),
                          _buildDaysSelector(),
                          const SizedBox(height: 32),
                          _buildNotificationToggle(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Botón de acción flotante
                _buildActionButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode 
                    ? 'Editar Hábito' 
                    : (widget.prefilledName != null ? 'Personaliza tu Hábito' : 'Nuevo Hábito'),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  isEditMode 
                    ? 'Modifica los detalles de tu hábito'
                    : 'Crea un hábito que transforme tu vida',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (isEditMode)
                IconButton(
                  onPressed: () => _showDeleteConfirmation(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.grey[700],
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getCategoryColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: _getCategoryColor(),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _getCategoryColor().withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller: _nameController,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
          onChanged: (_) => HapticFeedback.selectionClick(),
          decoration: InputDecoration(
            labelText: 'Nombre del Hábito',
            labelStyle: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            hintText: 'ej. Meditación Matutina',
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(
              Icons.edit_rounded,
              color: _getCategoryColor(),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _getCategoryColor(),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {'id': 'health', 'name': 'Salud', 'icon': Icons.favorite_rounded, 'gradient': [const Color(0xFF4ADE80), const Color(0xFF22C55E)]},
      {'id': 'mind', 'name': 'Mente', 'icon': Icons.self_improvement, 'gradient': [const Color(0xFF818CF8), const Color(0xFF6366F1)]},
      {'id': 'productivity', 'name': 'Trabajo', 'icon': Icons.work_rounded, 'gradient': [const Color(0xFF60A5FA), const Color(0xFF3B82F6)]},
      {'id': 'relationships', 'name': 'Social', 'icon': Icons.people_rounded, 'gradient': [const Color(0xFFF472B6), const Color(0xFFEC4899)]},
      {'id': 'creativity', 'name': 'Creativo', 'icon': Icons.palette_rounded, 'gradient': [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]},
      {'id': 'finance', 'name': 'Finanzas', 'icon': Icons.attach_money_rounded, 'gradient': [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)]},
      {'id': 'otros', 'name': 'Otros', 'icon': Icons.more_horiz_rounded, 'gradient': [const Color(0xFF94A3B8), const Color(0xFF64748B)]},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedCategory == category['id'];
        final gradientColors = category['gradient'] as List<Color>;
        
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 50)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _previousCategory = _selectedCategory;
                _selectedCategory = category['id'] as String;
                _categoryAnimationController.forward(from: 0);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: isSelected 
                  ? LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                    ? gradientColors.first 
                    : Colors.grey[200]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                      ? gradientColors.first.withOpacity(0.3)
                      : Colors.black.withOpacity(0.03),
                    blurRadius: isSelected ? 20 : 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      category['icon'] as IconData,
                      color: isSelected ? Colors.white : gradientColors.first,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category['name'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeSelector() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                timePickerTheme: TimePickerThemeData(
                  backgroundColor: Colors.white,
                  hourMinuteTextColor: _getCategoryColor(),
                  hourMinuteColor: _getCategoryColor().withOpacity(0.1),
                  dialHandColor: _getCategoryColor(),
                  dialBackgroundColor: _getCategoryColor().withOpacity(0.05),
                  dialTextColor: const Color(0xFF1E293B),
                  dayPeriodTextColor: _getCategoryColor(),
                  dayPeriodColor: _getCategoryColor().withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  hourMinuteShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  dayPeriodShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedTime = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getCategoryColor().withOpacity(0.05),
              _getCategoryColor().withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getCategoryColor().withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: _getCategoryColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTime.format(context),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Toca para cambiar',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(
              Icons.edit_rounded,
              color: _getCategoryColor(),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSelector() {
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    
    return Column(
      children: [
        // Quick select chips con diseño 
        Container(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildQuickSelectChip(
                'Todos los días',
                Icons.calendar_today_rounded,
                () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDays.clear();
                    _selectedDays.addAll([1, 2, 3, 4, 5, 6, 7]);
                  });
                },
              ),
              const SizedBox(width: 12),
              _buildQuickSelectChip(
                'Entre semana',
                Icons.work_outline_rounded,
                () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDays.clear();
                    _selectedDays.addAll([1, 2, 3, 4, 5]);
                  });
                },
              ),
              const SizedBox(width: 12),
              _buildQuickSelectChip(
                'Fin de semana',
                Icons.weekend_rounded,
                () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDays.clear();
                    _selectedDays.addAll([6, 7]);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Day selector con animaciones
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final dayNum = index + 1;
            final isSelected = _selectedDays.contains(dayNum);
            
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 50)),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(dayNum);
                    } else {
                      _selectedDays.add(dayNum);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: isSelected 
                      ? LinearGradient(
                          colors: [
                            _getCategoryColor(),
                            _getCategoryColor().withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                    color: isSelected ? null : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                        ? _getCategoryColor() 
                        : Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected 
                          ? _getCategoryColor().withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                        blurRadius: isSelected ? 15 : 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      days[index],
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildQuickSelectChip(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: _getCategoryColor(),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            _getCategoryColor().withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFBBF24),
                  const Color(0xFFF59E0B),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recordatorios Diarios',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Te avisaremos a la hora programada',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: _enableNotifications,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                setState(() => _enableNotifications = value);
              },
              activeColor: _getCategoryColor(),
              activeTrackColor: _getCategoryColor().withOpacity(0.3),
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[200],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: _scaleController..forward(),
            curve: Curves.elasticOut,
          )),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : (isEditMode ? _updateHabit : _createHabit),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isLoading 
                      ? [Colors.grey[400]!, Colors.grey[300]!]
                      : [_getCategoryColor(), _getCategoryColor().withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _isLoading 
                        ? Colors.grey.withOpacity(0.3) 
                        : _getCategoryColor().withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isEditMode ? Icons.check_rounded : Icons.add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEditMode ? 'Actualizar Hábito' : 'Crear Hábito',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
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

  // Helpers
  Color _getCategoryColor() {
    switch (_selectedCategory) {
      case 'health':
        return AppColors.categoryHealth;
      case 'mind':
        return AppColors.categoryMind;
      case 'productivity':
        return AppColors.categoryProductivity;
      case 'relationships':
        return AppColors.categoryRelationships;
      case 'creativity':
        return AppColors.categoryCreativity;
      case 'finance':
        return AppColors.categoryFinance;
      default:
        return Colors.grey;
    }
  }

  void _createHabit() async {
    if (_nameController.text.trim().isEmpty || _selectedDays.isEmpty) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Text(
                'Por favor completa todos los campos',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final habit = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'days': _selectedDays.toList()..sort(),
        'specificTime': {
          'hour': _selectedTime.hour,
          'minute': _selectedTime.minute,
        },
        'notifications': _enableNotifications,
        'completions': [],
        'createdAt': Timestamp.now(),
        'streak': 0,
        'longestStreak': 0,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .add(habit);

      if (_enableNotifications) {
        await NotificationService.scheduleHabitNotification(
          habitId: docRef.id,
          habitName: _nameController.text.trim(),
          time: _selectedTime,
          days: _selectedDays.toList(),
        );
      }

      if (!mounted) return;
      
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text(
                '¡Hábito creado exitosamente! 🎉',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _updateHabit() async {
    if (_nameController.text.trim().isEmpty || _selectedDays.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedData = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'days': _selectedDays.toList()..sort(),
        'specificTime': {
          'hour': _selectedTime.hour,
          'minute': _selectedTime.minute,
        },
        'notifications': _enableNotifications,
      };
      
      await FirestoreService.updateHabit(widget.habit!.id, updatedData);
      
      // Actualizar notificaciones
      await NotificationService.cancelHabitNotifications(
        widget.habit!.id,
        widget.habit!.days,
      );
      
      if (_enableNotifications) {
        await NotificationService.scheduleHabitNotification(
          habitId: widget.habit!.id,
          habitName: _nameController.text.trim(),
          time: _selectedTime,
          days: _selectedDays.toList(),
        );
      }
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  '¡Hábito actualizado! ✨',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
  void _showDeleteConfirmation(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Eliminar Hábito?',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Esta acción no se puede deshacer.\nTodo el progreso se perderá.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          _deleteHabit();
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Eliminar',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _deleteHabit() async {
    await FirestoreService.deleteHabit(widget.habit!.id);
    await NotificationService.cancelHabitNotifications(
      widget.habit!.id,
      widget.habit!.days,
    );
  }
}