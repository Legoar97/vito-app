import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/habit.dart'; // Importamos el modelo de datos
import '../services/firestore_service.dart'; // Importamos el servicio centralizado
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class EditHabitBottomSheet extends StatefulWidget {
  // Ahora recibe un objeto Habit completo, lo que es más limpio y seguro.
  final Habit habit;

  const EditHabitBottomSheet({
    super.key,
    required this.habit,
  });

  @override
  State<EditHabitBottomSheet> createState() => _EditHabitBottomSheetState();
}

class _EditHabitBottomSheetState extends State<EditHabitBottomSheet> {
  late TextEditingController _nameController;
  late Set<int> _selectedDays;
  late String _selectedCategory;
  late TimeOfDay _selectedTime;
  late bool _enableNotifications;

  @override
  void initState() {
    super.initState();
    // Inicializamos los valores del formulario directamente desde el objeto Habit.
    final habit = widget.habit;
    _nameController = TextEditingController(text: habit.name);
    _selectedDays = Set<int>.from(habit.days);
    _selectedCategory = habit.category;
    _selectedTime = habit.specificTime;
    _enableNotifications = habit.notifications;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Header con opción de eliminar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Editar Hábito',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _showDeleteConfirmation(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Contenido del formulario con el estilo restaurado
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.inter(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Nombre del Hábito',
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
                  Text('Categoría', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _buildCategoryGrid(),
                  const SizedBox(height: 32),
                  Text('Horario', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _buildTimeSelector(),
                  const SizedBox(height: 32),
                  Text('Repetir', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _buildDaysSelector(),
                  const SizedBox(height: 32),
                  _buildNotificationToggle(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // Botón de acción
          Container(
            padding: const EdgeInsets.all(24),
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
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _updateHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 56),
                   shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Actualizar Hábito',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Métodos de la UI (Restaurados a su versión completa y con estilo) ---
   Widget _buildCategoryGrid() {
    final categories = [
      {'id': 'health', 'name': 'Salud', 'icon': Icons.favorite, 'color': AppColors.categoryHealth},
      {'id': 'mind', 'name': 'Mente', 'icon': Icons.self_improvement, 'color': AppColors.categoryMind},
      {'id': 'productivity', 'name': 'Trabajo', 'icon': Icons.work, 'color': AppColors.categoryProductivity},
      {'id': 'relationships', 'name': 'Social', 'icon': Icons.people, 'color': AppColors.categoryRelationships},
      {'id': 'creativity', 'name': 'Creativo', 'icon': Icons.palette, 'color': AppColors.categoryCreativity},
      {'id': 'finance', 'name': 'Finanzas', 'icon': Icons.attach_money, 'color': AppColors.categoryFinance},
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
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary),
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
        // Usa Wrap en lugar de Row para que los chips se ajusten automáticamente
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickSelectChip('Diariamente', () {
              setState(() {
                _selectedDays.clear();
                _selectedDays.addAll([1, 2, 3, 4, 5, 6, 7]);
              });
            }),
            _buildQuickSelectChip('L-V', () {
              setState(() {
                _selectedDays.clear();
                _selectedDays.addAll([1, 2, 3, 4, 5]);
              });
            }),
            _buildQuickSelectChip('S-D', () {
              setState(() {
                _selectedDays.clear();
                _selectedDays.addAll([6, 7]);
              });
            }),
          ],
        ),
        const SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Más compacto
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(16),
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
          const Expanded(
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: AppColors.warning),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recordatorios Diarios',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                       Text(
                        'Recibe notificaciones a la hora del hábito',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
  
  // --- Lógica de la Base de Datos ---

  Future<void> _updateHabit() async {
    // Validaciones
    if (_nameController.text.trim().isEmpty || _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa todos los campos')));
      return;
    }

    final updatedData = {
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'days': _selectedDays.toList()..sort(),
      'specificTime': {'hour': _selectedTime.hour, 'minute': _selectedTime.minute},
      'notifications': _enableNotifications,
    };
    
    // Usamos el servicio centralizado para actualizar
    await FirestoreService.updateHabit(widget.habit.id, updatedData);
    
    // Cancela notificaciones antiguas y programa las nuevas si es necesario
    await NotificationService.cancelHabitNotifications(widget.habit.id, widget.habit.days);
    if (_enableNotifications) {
      await NotificationService.scheduleHabitNotification(
        habitId: widget.habit.id,
        habitName: _nameController.text.trim(),
        time: _selectedTime,
        days: _selectedDays.toList(),
      );
    }
    
    if (mounted) Navigator.pop(context);
  }
  
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Hábito?'),
        content: const Text('Esta acción no se puede deshacer. Todo el progreso de este hábito se perderá.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            onPressed: () {
              _deleteHabit();
              Navigator.of(ctx).pop(); // Cierra el diálogo
              Navigator.of(context).pop(); // Cierra el BottomSheet
            },
          )
        ],
      ),
    );
  }
  
  Future<void> _deleteHabit() async {
    // Usamos el servicio centralizado para eliminar
    await FirestoreService.deleteHabit(widget.habit.id);
    await NotificationService.cancelHabitNotifications(widget.habit.id, widget.habit.days);
  }
}
