import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';

class AddHabitBottomSheet extends StatefulWidget {
  final String? prefilledName;
  final String? prefilledCategory;
  
  const AddHabitBottomSheet({
    super.key,
    this.prefilledName,
    this.prefilledCategory,
  });

  @override
  State<AddHabitBottomSheet> createState() => _AddHabitBottomSheetState();
}

class _AddHabitBottomSheetState extends State<AddHabitBottomSheet> {
  // --- Controladores y estado del widget ---
  late final TextEditingController _nameController;
  final Set<int> _selectedDays = {}; // Lunes=1, Martes=2, ..., Domingo=7
  late String _selectedCategory; // Categoría por defecto
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _enableNotifications = true;
  bool _isLoading = false; // Para prevenir múltiples envíos

  @override
  void initState() {
    super.initState();
    // Inicializar con valores prellenados si existen
    _nameController = TextEditingController(text: widget.prefilledName ?? '');
    _selectedCategory = widget.prefilledCategory ?? 'health';
    // Por defecto, seleccionar todos los días
    _selectedDays.addAll([1, 2, 3, 4, 5, 6, 7]);
  }

  @override
  void dispose() {
    // Es importante limpiar los controladores para liberar memoria.
    _nameController.dispose();
    super.dispose();
  }

  /// Método principal que construye la interfaz de usuario del widget.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // 1. Barra de agarre (Handle bar)
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // 2. Encabezado con título y botón de cierre
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.prefilledName != null 
                    ? 'Personaliza tu Hábito' 
                    : 'Crear Nuevo Hábito',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 3. Contenido principal del formulario con scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name input
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.inter(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Nombre del Hábito',
                      hintText: 'ej. Meditación Matutina',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Category selection
                  Text(
                    'Categoría',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryGrid(),
                  const SizedBox(height: 32),
                  
                  // Time selection
                  Text(
                    'Horario',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeSelector(),
                  const SizedBox(height: 32),
                  
                  // Days selection
                  Text(
                    'Repetir',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDaysSelector(),
                  const SizedBox(height: 32),
                  
                  // Notifications toggle
                  _buildNotificationToggle(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // 4. Botón de acción para crear el hábito
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 34), // Padding extra abajo por SafeArea
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createHabit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Crear Hábito',
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
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {'id': 'health', 'name': 'Salud', 'icon': Icons.favorite, 'color': AppColors.categoryHealth},
      {'id': 'mind', 'name': 'Mente', 'icon': Icons.self_improvement, 'color': AppColors.categoryMind},
      {'id': 'productivity', 'name': 'Trabajo', 'icon': Icons.work, 'color': AppColors.categoryProductivity},
      {'id': 'relationships', 'name': 'Social', 'icon': Icons.people, 'color': AppColors.categoryRelationships},
      {'id': 'creativity', 'name': 'Creativo', 'icon': Icons.palette, 'color': AppColors.categoryCreativity},
      {'id': 'finance', 'name': 'Finanzas', 'icon': Icons.attach_money, 'color': AppColors.categoryFinance},
      {'id': 'otros', 'name': 'Otros', 'icon': Icons.more_horiz, 'color': Colors.grey}, // Agregada categoría Otros
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedCategory == category['id'];
        
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = category['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? (category['color'] as Color).withOpacity(0.2) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? category['color'] as Color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category['icon'] as IconData,
                  color: isSelected ? category['color'] as Color : Colors.grey[600],
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  category['name'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? category['color'] as Color : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeSelector() {
    return GestureDetector(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                timePickerTheme: TimePickerThemeData(
                  backgroundColor: Colors.white,
                  hourMinuteTextColor: AppColors.primary,
                  hourMinuteColor: AppColors.primary.withOpacity(0.1),
                  dialHandColor: AppColors.primary,
                  dialBackgroundColor: AppColors.primary.withOpacity(0.1),
                  dialTextColor: Colors.black87,
                  dayPeriodTextColor: AppColors.primary,
                  dayPeriodColor: AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  _selectedTime.format(context),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Icon(Icons.edit, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysSelector() {
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    
    return Column(
      children: [
        // Quick select buttons
        Row(
          children: [
            _buildQuickSelectChip('Todos los días', () {
              setState(() {
                _selectedDays.clear();
                _selectedDays.addAll([1, 2, 3, 4, 5, 6, 7]);
              });
            }),
            const SizedBox(width: 8),
            _buildQuickSelectChip('Entre semana', () {
              setState(() {
                _selectedDays.clear();
                _selectedDays.addAll([1, 2, 3, 4, 5]);
              });
            }),
            const SizedBox(width: 8),
            _buildQuickSelectChip('Fin de semana', () {
              setState(() {
                _selectedDays.clear();
                _selectedDays.addAll([6, 7]);
              });
            }),
          ],
        ),
        const SizedBox(height: 16),
        // Day selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final dayNum = index + 1;
            final isSelected = _selectedDays.contains(dayNum);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDays.remove(dayNum);
                  } else {
                    _selectedDays.add(dayNum);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    days[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
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

  Widget _buildQuickSelectChip(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recordatorios Diarios',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Recibe notificaciones a la hora del hábito',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableNotifications,
            onChanged: (value) => setState(() => _enableNotifications = value),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  void _createHabit() async {
    if (_nameController.text.trim().isEmpty || _selectedDays.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor completa el nombre y los días'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Prevenir múltiples envíos
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
      
      // Cerrar el bottom sheet ANTES de mostrar el snackbar
      Navigator.pop(context);
      
      // Pequeño delay para asegurar que el bottom sheet se cerró
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('¡Hábito creado exitosamente!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear el hábito: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}