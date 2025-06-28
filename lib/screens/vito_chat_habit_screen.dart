import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';

import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/vertex_ai_service.dart';

// Tipos de mensajes en el chat
enum MessageType { vito, user }

// Modelo para un mensaje
class ChatMessage {
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final bool isTyping;

  ChatMessage({
    required this.text,
    required this.type,
    required this.timestamp,
    this.isTyping = false,
  });
}

// Modelo para el hábito en construcción
class HabitBuilder {
  String? name;
  String? category;
  List<int>? days;
  TimeOfDay? time;
  int? duration; // Para ejercicio, meditación, etc
  double? amount; // Para ahorro, agua, etc
  String? unit; // minutos, pesos, litros, etc
  
  bool get isComplete => name != null && category != null && days != null && time != null;
}

class VitoChatHabitSheet extends StatefulWidget {
  final Habit? habit; // Para modo edición
  final String? initialMessage; // Para cuando viene de una sugerencia
  
  const VitoChatHabitSheet({
    super.key,
    this.habit,
    this.initialMessage,
  });

  @override
  State<VitoChatHabitSheet> createState() => _VitoChatHabitSheetState();
}

class _VitoChatHabitSheetState extends State<VitoChatHabitSheet>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _slideController;
  late AnimationController _vitoAvatarController;
  late AnimationController _messageAnimationController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  // Estado del chat
  final List<ChatMessage> _messages = [];
  bool _isVitoTyping = false;
  final HabitBuilder _habitBuilder = HabitBuilder();
  bool _isProcessing = false;
  
  // Info del usuario
  String _userName = '';
  
  bool get isEditMode => widget.habit != null;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    
    _vitoAvatarController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _loadUserName();
    _initializeChat();
  }
  
  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName?.split(' ').first ?? 'amigo';
      });
    }
  }
  
  void _initializeChat() {
    // Mensaje inicial de Vito
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        if (isEditMode) {
          _addVitoMessage(
            '¡Hola $_userName! 👋\n\n¿Qué te gustaría cambiar de tu hábito "${widget.habit!.name}"?'
          );
          
          // Agregar botones de edición/eliminación después del mensaje inicial
          Future.delayed(const Duration(milliseconds: 1000), () {
            setState(() {
              _messages.add(ChatMessage(
                text: 'EDIT_MODE_BUTTONS',
                type: MessageType.vito,
                timestamp: DateTime.now(),
              ));
            });
            _scrollToBottom();
          });
        } else {
          _addVitoMessage(
            '¡Hola $_userName! 👋\n\nSoy Vito, tu asistente personal de bienestar. ¿Qué hábito te gustaría crear hoy?\n\nPuedes decirme algo como:\n• "Meditar 10 minutos todas las mañanas"\n• "Acostarme a las 10 pm de lunes a viernes"\n• "Salir a correr 30 min lunes, miércoles y viernes"'
          );
          
          // Si hay un mensaje inicial (de una sugerencia), procesarlo
          if (widget.initialMessage != null) {
            Future.delayed(const Duration(seconds: 2), () {
              _messageController.text = widget.initialMessage!;
              _sendMessage();
            });
          }
        }
      }
    });
  }
    
  void _addVitoMessage(String text, {bool withTyping = true}) async {
    if (withTyping) {
      setState(() => _isVitoTyping = true);
      await Future.delayed(Duration(milliseconds: math.min(text.length * 10, 2000)));
    }
    
    setState(() {
      _isVitoTyping = false;
      _messages.add(ChatMessage(
        text: text,
        type: MessageType.vito,
        timestamp: DateTime.now(),
      ));
    });
    
    _scrollToBottom();
    HapticFeedback.lightImpact();
  }
  
  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        type: MessageType.user,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isProcessing) return;
    
    _messageController.clear();
    _addUserMessage(text);
    
    setState(() => _isProcessing = true);
    
    // Procesar el mensaje
    await _processUserInput(text);
    
    setState(() => _isProcessing = false);
  }
  
  Future<void> _processUserInput(String input) async {
    // Aquí simularemos el procesamiento de IA
    // En producción, esto llamaría a Vertex AI
    
    final lowerInput = input.toLowerCase();
    
    // Extraer información del input
    _extractHabitInfo(lowerInput);
    
    // Verificar qué información falta y preguntar
    if (_habitBuilder.name == null) {
      _addVitoMessage(
        '¿Podrías decirme específicamente qué hábito quieres crear? Por ejemplo: "leer", "hacer ejercicio", "meditar"... 🤔'
      );
    } else if (_habitBuilder.days == null || _habitBuilder.days!.isEmpty) {
      _addVitoMessage(
        'Perfecto, quieres ${_habitBuilder.name}. ¿Qué días te gustaría hacerlo? 📅\n\nPuedes decir:\n• "Todos los días"\n• "De lunes a viernes"\n• "Lunes, miércoles y viernes"\n• "Solo los domingos"'
      );
    } else if (_habitBuilder.time == null) {
      _addVitoMessage(
        '¡Genial! ¿A qué hora prefieres ${_habitBuilder.name}? ⏰\n\nPor ejemplo: "a las 6 am", "7:30 pm", "por la mañana"...'
      );
    } else if (_needsAdditionalInfo()) {
      _askForAdditionalInfo();
    } else {
      // Tenemos toda la información necesaria
      _confirmHabit();
    }
  }
  
  void _extractHabitInfo(String input) {
    // Extraer nombre del hábito
    if (_habitBuilder.name == null) {
      // Buscar verbos comunes de hábitos
      final habitPatterns = {
        'meditar': 'Meditación',
        'correr': 'Salir a correr',
        'caminar': 'Caminata',
        'leer': 'Lectura',
        'escribir': 'Escritura',
        'ahorrar': 'Ahorro',
        'agua': 'Tomar agua',
        'dormir': 'Dormir temprano',
        'despertar': 'Despertar temprano',
        'ejercicio': 'Hacer ejercicio',
        'yoga': 'Practicar yoga',
        'estudiar': 'Estudiar',
      };
      
      for (final pattern in habitPatterns.keys) {
        if (input.contains(pattern)) {
          _habitBuilder.name = habitPatterns[pattern];
          _categorizeHabit(pattern);
          break;
        }
      }
    }
    
    // Extraer días
    if (input.contains('todos los días') || input.contains('diario') || input.contains('diariamente')) {
      _habitBuilder.days = [1, 2, 3, 4, 5, 6, 7];
    } else if (input.contains('lunes a viernes') || input.contains('entre semana')) {
      _habitBuilder.days = [1, 2, 3, 4, 5];
    } else if (input.contains('fin de semana') || input.contains('fines de semana')) {
      _habitBuilder.days = [6, 7];
    } else {
      // Buscar días específicos
      final dayMap = {
        'lunes': 1, 'martes': 2, 'miércoles': 3, 'miercoles': 3,
        'jueves': 4, 'viernes': 5, 'sábado': 6, 'sabado': 6,
        'domingo': 7,
      };
      
      List<int> extractedDays = [];
      for (final day in dayMap.keys) {
        if (input.contains(day)) {
          extractedDays.add(dayMap[day]!);
        }
      }
      
      if (extractedDays.isNotEmpty) {
        _habitBuilder.days = extractedDays..sort();
      }
    }
    
    // Extraer hora
    final timeRegex = RegExp(r'(\d{1,2}):?(\d{2})?\s*(am|pm|AM|PM)?');
    final match = timeRegex.firstMatch(input);
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      final period = match.group(3)?.toLowerCase();
      
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      
      _habitBuilder.time = TimeOfDay(hour: hour, minute: minute);
    } else if (input.contains('mañana')) {
      _habitBuilder.time = const TimeOfDay(hour: 7, minute: 0);
    } else if (input.contains('tarde')) {
      _habitBuilder.time = const TimeOfDay(hour: 15, minute: 0);
    } else if (input.contains('noche')) {
      _habitBuilder.time = const TimeOfDay(hour: 20, minute: 0);
    }
    
    // Extraer duración (para ejercicio, meditación, etc)
    final durationRegex = RegExp(r'(\d+)\s*(minutos?|min|horas?|hr)');
    final durationMatch = durationRegex.firstMatch(input);
    if (durationMatch != null) {
      int value = int.parse(durationMatch.group(1)!);
      String unit = durationMatch.group(2)!.toLowerCase();
      
      if (unit.contains('hora')) {
        _habitBuilder.duration = value * 60; // Convertir a minutos
      } else {
        _habitBuilder.duration = value;
      }
      _habitBuilder.unit = 'minutos';
    }
    
    // Extraer cantidad (para ahorro, agua, etc)
    final amountRegex = RegExp(r'(\d+\.?\d*)\s*(mil|k|pesos|cop|litros?|l|vasos?)');
    final amountMatch = amountRegex.firstMatch(input);
    if (amountMatch != null) {
      double value = double.parse(amountMatch.group(1)!);
      String unit = amountMatch.group(2)!.toLowerCase();
      
      if (unit.contains('mil') || unit == 'k') {
        value *= 1000;
        _habitBuilder.amount = value;
        _habitBuilder.unit = 'pesos';
      } else if (unit.contains('peso') || unit.contains('cop')) {
        _habitBuilder.amount = value;
        _habitBuilder.unit = 'pesos';
      } else if (unit.contains('litro') || unit == 'l') {
        _habitBuilder.amount = value;
        _habitBuilder.unit = 'litros';
      } else if (unit.contains('vaso')) {
        _habitBuilder.amount = value;
        _habitBuilder.unit = 'vasos';
      }
    }
  }
  
  void _categorizeHabit(String habitType) {
    // Categorizar automáticamente basado en el tipo de hábito
    final categories = {
      'health': ['correr', 'caminar', 'ejercicio', 'yoga', 'agua', 'dormir'],
      'mind': ['meditar', 'leer', 'escribir', 'estudiar'],
      'finance': ['ahorrar', 'presupuesto', 'inversión'],
      'productivity': ['despertar', 'planificar', 'organizar'],
    };
    
    for (final category in categories.entries) {
      if (category.value.contains(habitType)) {
        _habitBuilder.category = category.key;
        return;
      }
    }
    
    _habitBuilder.category = 'otros';
  }
  
  bool _needsAdditionalInfo() {
    final habit = _habitBuilder.name?.toLowerCase() ?? '';
    
    // Hábitos que necesitan duración
    if (['meditar', 'correr', 'caminar', 'ejercicio', 'yoga', 'leer', 'estudiar']
        .any((h) => habit.contains(h))) {
      return _habitBuilder.duration == null;
    }
    
    // Hábitos que necesitan cantidad
    if (['ahorrar', 'agua'].any((h) => habit.contains(h))) {
      return _habitBuilder.amount == null;
    }
    
    return false;
  }
  
  void _askForAdditionalInfo() {
    final habit = _habitBuilder.name?.toLowerCase() ?? '';
    
    if (['meditar', 'correr', 'caminar', 'ejercicio', 'yoga', 'leer', 'estudiar']
        .any((h) => habit.contains(h))) {
      _addVitoMessage(
        '¿Por cuánto tiempo quieres ${_habitBuilder.name}? ⏱️\n\nPor ejemplo: "30 minutos", "1 hora", "45 min"...'
      );
    } else if (habit.contains('ahorrar')) {
      _addVitoMessage(
        '¿Cuánto dinero quieres ahorrar? 💰\n\nPor ejemplo: "50 mil pesos", "100k", "200.000 cop"...'
      );
    } else if (habit.contains('agua')) {
      _addVitoMessage(
        '¿Cuánta agua quieres tomar? 💧\n\nPor ejemplo: "2 litros", "8 vasos", "1.5L"...'
      );
    }
  }
  
  void _confirmHabit() {
    // Construir el resumen del hábito
    String summary = '¡Perfecto! He preparado tu hábito:\n\n';
    summary += '✅ **${_habitBuilder.name}**\n';
    
    // Días
    final dayNames = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final selectedDayNames = _habitBuilder.days!
        .map((d) => dayNames[d - 1])
        .join(', ');
    summary += '📅 Días: $selectedDayNames\n';
    
    // Hora
    summary += '⏰ Hora: ${_habitBuilder.time!.format(context)}\n';
    
    // Info adicional
    if (_habitBuilder.duration != null) {
      summary += '⏱️ Duración: ${_habitBuilder.duration} ${_habitBuilder.unit}\n';
    }
    if (_habitBuilder.amount != null) {
      summary += '💵 Cantidad: ${_habitBuilder.amount?.toStringAsFixed(0)} ${_habitBuilder.unit}\n';
    }
    
    summary += '\n¿Te parece bien? Puedo crearlo ahora o ajustar lo que necesites 🎯';
    
    // Agregar el mensaje con un marcador especial para los botones
    setState(() {
      _messages.add(ChatMessage(
        text: summary,
        type: MessageType.vito,
        timestamp: DateTime.now(),
      ));
      // Agregar los botones inmediatamente después
      _messages.add(ChatMessage(
        text: 'ACTION_BUTTONS',
        type: MessageType.vito,
        timestamp: DateTime.now(),
      ));
    });
    
    _scrollToBottom();
    HapticFeedback.lightImpact();
  }
  
  Future<void> _createHabitFromBuilder() async {
    setState(() => _isProcessing = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');
      
      // Agregar info adicional al nombre si existe
      String habitName = _habitBuilder.name!;
      if (_habitBuilder.duration != null) {
        habitName += ' (${_habitBuilder.duration} min)';
      } else if (_habitBuilder.amount != null) {
        habitName += ' (${_habitBuilder.amount?.toStringAsFixed(0)} ${_habitBuilder.unit})';
      }
      
      final habit = {
        'name': habitName,
        'category': _habitBuilder.category ?? 'otros',
        'days': _habitBuilder.days!..sort(),
        'specificTime': {
          'hour': _habitBuilder.time!.hour,
          'minute': _habitBuilder.time!.minute,
        },
        'notifications': true,
        'completions': [],
        'createdAt': Timestamp.now(),
        'streak': 0,
        'longestStreak': 0,
        // Campos adicionales si existen
        if (_habitBuilder.duration != null) 'duration': _habitBuilder.duration,
        if (_habitBuilder.amount != null) 'targetAmount': _habitBuilder.amount,
        if (_habitBuilder.unit != null) 'unit': _habitBuilder.unit,
      };
      
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .add(habit);
      
      // Programar notificaciones
      await NotificationService.scheduleHabitNotification(
        habitId: docRef.id,
        habitName: habitName,
        time: _habitBuilder.time!,
        days: _habitBuilder.days!,
      );
      
      if (!mounted) return;
      
      _addVitoMessage(
        '¡Listo! 🎉\n\nTu hábito "${_habitBuilder.name}" ha sido creado exitosamente.\n\nTe enviaré recordatorios todos los días seleccionados a las ${_habitBuilder.time!.format(context)}.\n\n¡Vamos por ese cambio positivo! 💪',
        withTyping: false,
      );
      
      // Cerrar después de un delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          HapticFeedback.heavyImpact();
          Navigator.pop(context);
        }
      });
      
    } catch (e) {
      _addVitoMessage(
        'Oh no 😔\n\nHubo un problema al crear tu hábito. ¿Podrías intentarlo de nuevo?',
        withTyping: false,
      );
      setState(() => _isProcessing = false);
    }
  }
  
  void _showDeleteConfirmation() {
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
                          Navigator.of(ctx).pop();
                          _deleteHabit();
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
    setState(() => _isProcessing = true);
    
    try {
      await FirestoreService.deleteHabit(widget.habit!.id);
      await NotificationService.cancelHabitNotifications(
        widget.habit!.id,
        widget.habit!.days,
      );
      
      if (!mounted) return;
      
      _addVitoMessage(
        '¡Hábito eliminado! 👍\n\nEspero que encuentres nuevos hábitos que se adapten mejor a tus objetivos.',
        withTyping: false,
      );
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          HapticFeedback.heavyImpact();
          Navigator.pop(context);
        }
      });
    } catch (e) {
      _addVitoMessage(
        'Oh no 😔 Hubo un problema al eliminar el hábito. ¿Intentamos de nuevo?',
        withTyping: false,
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _slideController.dispose();
    _vitoAvatarController.dispose();
    _messageAnimationController.dispose();
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
        child: Column(
          children: [
            // Header
            _buildChatHeader(),
            
            // Messages area
            Expanded(
              child: _buildMessagesArea(),
            ),
            
            // Input area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar animado de Vito
          AnimatedBuilder(
            animation: _vitoAvatarController,
            builder: (context, child) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15 + (5 * math.sin(_vitoAvatarController.value * 2 * math.pi)),
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.spa,
                  color: Colors.white,
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          
          // Título
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Vito',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Online',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  isEditMode ? 'Editando hábito' : 'Asistente de hábitos',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          
          // Botón cerrar
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
    );
  }
  
  Widget _buildMessagesArea() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: _messages.length + (_isVitoTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isVitoTyping && index == _messages.length) {
            return _buildTypingIndicator();
          }
          
          final message = _messages[index];
          
          // Si es un mensaje de botones de acción
          if (message.text == 'ACTION_BUTTONS') {
            return _buildActionButtons();
          }
          
          return _buildMessage(message);
        },
      ),
    );
  }
  
  Widget _buildMessage(ChatMessage message) {
    final isVito = message.type == MessageType.vito;
    
    // Si es un mensaje de botones de acción
    if (message.text == 'ACTION_BUTTONS') {
      return _buildActionButtons();
    }
    
    // Si son botones del modo edición
    if (message.text == 'EDIT_MODE_BUTTONS') {
      return _buildEditModeButtons();
    }
    
    return Padding(
      padding: EdgeInsets.only(
        left: isVito ? 0 : 60,
        right: isVito ? 60 : 0,
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isVito) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.8),
                    AppColors.primary.withOpacity(0.6),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.spa,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isVito ? Colors.white : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isVito ? 4 : 20),
                  bottomRight: Radius.circular(isVito ? 20 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isVito ? Colors.black : AppColors.primary).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: isVito ? const Color(0xFF1E293B) : Colors.white,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  Widget _buildEditModeButtons() {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildActionButton(
            'Modificar',
            Icons.edit_rounded,
            AppColors.primary,
            () {
              // Remover los botones de la lista
              _messages.removeWhere((m) => m.text == 'EDIT_MODE_BUTTONS');
              _addVitoMessage(
                'Dime qué quieres cambiar:\n• El nombre del hábito\n• Los días\n• La hora\n• La duración o cantidad\n\nO simplemente escríbeme los cambios que necesitas 😊'
              );
            },
          ),
          _buildActionButton(
            'Eliminar',
            Icons.delete_outline_rounded,
            AppColors.error,
            () => _showDeleteConfirmation(),
          ),
          _buildActionButton(
            'Cancelar',
            Icons.close_rounded,
            Colors.grey[600]!,
            () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primary.withOpacity(0.6),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3 + (0.5 * math.sin(value * math.pi))),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        // Repetir la animación
        setState(() {});
      },
    );
  }
  
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 16),
      child: Wrap(
        spacing: 12,
        children: [
          _buildActionButton(
            'Crear hábito',
            Icons.check_circle,
            AppColors.success,
            () => _createHabitFromBuilder(),
          ),
          _buildActionButton(
            'Ajustar',
            Icons.edit,
            AppColors.warning,
            () {
              // Remover los botones de la lista
              _messages.removeWhere((m) => m.text == 'ACTION_BUTTONS');
              _addVitoMessage(
                '¿Qué te gustaría cambiar? Puedes decirme cualquier ajuste que necesites 😊'
              );
            },
          ),
        ],
      ),
    );
  }
    
  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón de sugerencias rápidas
          IconButton(
            onPressed: _showQuickSuggestions,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lightbulb_outline,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Campo de texto
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus 
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isProcessing,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Describe tu hábito...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Botón enviar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: _isProcessing ? null : _sendMessage,
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isProcessing
                      ? [Colors.grey[400]!, Colors.grey[300]!]
                      : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isProcessing ? Colors.grey : AppColors.primary)
                          .withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showQuickSuggestions() {
    HapticFeedback.lightImpact();
    
    final suggestions = [
      'Meditar 10 minutos todas las mañanas a las 6 am',
      'Ahorrar 50 mil pesos todos los domingos',
      'Salir a correr 30 minutos lunes, miércoles y viernes a las 7 pm',
      'Leer 20 páginas antes de dormir',
      'Tomar 8 vasos de agua al día',
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sugerencias rápidas',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            ...suggestions.map((suggestion) => ListTile(
              onTap: () {
                Navigator.pop(context);
                _messageController.text = suggestion;
                _sendMessage();
              },
              leading: Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 20,
              ),
              title: Text(
                suggestion,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              contentPadding: EdgeInsets.zero,
            )),
          ],
        ),
      ),
    );
  }
}