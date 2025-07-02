import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

import '../models/habit.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/vertex_ai_service.dart';

enum MessageType { vito, user }

class ChatMessage {
  final String text;
  final MessageType type;
  final DateTime timestamp;
  ChatMessage({required this.text, required this.type, required this.timestamp});
}

// --- HABIT BUILDER ACTUALIZADO ---
class HabitBuilder {
  String? type;
  String? name;
  String? category;
  List<int>? days;
  TimeOfDay? time;
  int? targetValue; // Reemplaza duration y amount
  String? unit;

  void updateWith(Map<String, dynamic> data) {
    if (data.containsKey('type')) type = data['type'];
    if (data.containsKey('name')) name = data['name'];
    if (data.containsKey('category')) category = data['category'];
    if (data.containsKey('days')) days = List<int>.from(data['days']);
    if (data.containsKey('time')) {
      final timeParts = (data['time'] as String).split(':');
      time = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
    }
    // La IA ahora nos da targetValue y unit directamente.
    if (data.containsKey('targetValue')) targetValue = (data['targetValue'] as num?)?.toInt();
    if (data.containsKey('unit')) unit = data['unit'];
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'name': name,
      'category': category,
      'days': days,
      'time': time != null ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}' : null,
      'targetValue': targetValue,
      'unit': unit,
    };
  }

  bool get isReadyForConfirmation => name != null && days != null && days!.isNotEmpty && time != null;
}

class VitoChatHabitSheet extends StatefulWidget {
  final Habit? habit;
  final String? initialMessage;
  
  const VitoChatHabitSheet({super.key, this.habit, this.initialMessage});

  @override
  State<VitoChatHabitSheet> createState() => _VitoChatHabitSheetState();
}

class _VitoChatHabitSheetState extends State<VitoChatHabitSheet> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _vitoAvatarController;
  late AnimationController _messageAnimationController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final List<ChatMessage> _messages = [];
  bool _isVitoTyping = false;
  final HabitBuilder _habitBuilder = HabitBuilder();
  bool _isProcessing = false;
  
  String _userName = '';
  
  bool get isEditMode => widget.habit != null;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _vitoAvatarController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
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
          final habit = widget.habit!;
          _habitBuilder.name = habit.name;
          _habitBuilder.category = habit.category;
          _habitBuilder.days = habit.days;
          _habitBuilder.time = habit.specificTime;
          // ------------------------------------

          _addVitoMessage(
            '¡Hola $_userName! 👋\n\n¿Qué te gustaría cambiar de tu hábito "${widget.habit!.name}"?'
          );
          
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
            '¡Hola $_userName! 👋\n\nSoy Vito, tu asistente de bienestar. ¿Qué hábito te gustaría crear?\n\nPuedes decirme algo como:\n* "Meditar 10 minutos todas las mañanas"\n* "Acostarme a las 10 pm de lunes a viernes"\n* "Salir a correr 30 min lunes, miércoles y viernes"'
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
    final conversationHistory = _messages.map((msg) {
      return {'role': msg.type == MessageType.user ? 'user' : 'model', 'parts': [{'text': msg.text}]};
    }).toList();
    
    // 2. Llamamos al servicio de IA
    final jsonResponse = await VertexAIService.parseHabitFromText(
      userInput: text,
      conversationHistory: conversationHistory,
      existingHabitData: _habitBuilder.toMap(),
    );

    // 3. Procesamos la respuesta estructurada de la IA
    _handleAIResponse(jsonResponse);

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _handleAIResponse(String jsonResponse) {
    try {
      final response = jsonDecode(jsonResponse);
      final status = response['status'];

      switch (status) {
        case 'greeting':
          _addVitoMessage(response['message']);
          break;
        
        case 'incomplete':
          _addVitoMessage(response['question']);
          break;

        case 'delete_confirmation':
          _showDeleteConfirmation();
          break;

        case 'complete':
          final habitData = Map<String, dynamic>.from(response['data']);
          _habitBuilder.updateWith(habitData);

          // Una vez que la IA dice que está completo, confirmamos.
          _confirmHabit();
          break;
          
        case 'error':
        default:
          _addVitoMessage(response['message'] ?? 'Lo siento, tuve un problema. ¿Intentamos de nuevo?');
          break;
      }
    } catch (e) {
      print("Error al decodificar JSON de la IA: $e");
      _addVitoMessage('No entendí muy bien. ¿Podrías decirlo de otra manera?');
    }
  }
  
  void _confirmHabit() {
    // Construimos el resumen usando la sintaxis CORRECTA de Markdown
    String summary = '¡Perfecto! He preparado tu hábito. Así es como se ve:\n\n';

    // Usamos '*' seguido de espacios para crear una lista con viñetas.
    summary += '*   **Hábito:** ${_habitBuilder.name}\n';
    
    final dayNames = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
    if (_habitBuilder.days != null && _habitBuilder.days!.isNotEmpty) {
      final selectedDayNames = _habitBuilder.days!.map((d) => dayNames[d - 1]).join(', ');
      summary += '*   **Días:** 📅 $selectedDayNames\n'; // <-- Añadido '*'
    }
    
    if (_habitBuilder.time != null) {
      final formattedTime = _habitBuilder.time!.format(context);
      summary += '*   **Hora:** ⏰ $formattedTime\n'; // <-- Añadido '*'
    }
    
    if (_habitBuilder.type == 'timed' && _habitBuilder.targetValue != null) {
      summary += '*   **Duración:** ⏱️ ${_habitBuilder.targetValue} minutos\n'; // <-- Añadido '*'
    }
    
    if (_habitBuilder.type == 'quantifiable' && _habitBuilder.targetValue != null) {
      final unit = _habitBuilder.unit ?? '';
      summary += '*   **Objetivo:** 🎯 ${_habitBuilder.targetValue} $unit\n'; // <-- Añadido '*'
    }
    
    summary += '\n¿Te parece bien?';
    
    setState(() {
      _messages.add(ChatMessage(text: summary, type: MessageType.vito, timestamp: DateTime.now()));
      _messages.add(ChatMessage(text: 'ACTION_BUTTONS', type: MessageType.vito, timestamp: DateTime.now()));
    });
    
    _scrollToBottom();
  }

  // --- LÓGICA DE CREACIÓN CORREGIDA ---
  Future<void> _createHabitFromBuilder() async {
    setState(() => _isProcessing = true);
    
    // --- CAMBIO CLAVE: Bloqueamos la UI ANTES de empezar ---
    // Removemos los botones de acción para que el usuario no pueda volver a interactuar.
    _messages.removeWhere((m) => m.text == 'ACTION_BUTTONS');
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final habit = {
        'type': _habitBuilder.type ?? 'simple',
        'name': _habitBuilder.name!,
        'category': _habitBuilder.category ?? 'otros',
        'days': _habitBuilder.days!..sort(),
        'specificTime': {
          'hour': _habitBuilder.time!.hour,
          'minute': _habitBuilder.time!.minute,
        },
        'targetValue': _habitBuilder.targetValue,
        'unit': _habitBuilder.unit,
        'notifications': true,
        'completions': {}, // Inicia como mapa vacío
        'createdAt': Timestamp.now(),
        'streak': 0,
        'longestStreak': 0,
      };
      
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .add(habit);
      
      // Solo programamos notificaciones si el hábito se creó correctamente
      await NotificationService.scheduleHabitNotification(
        habitId: docRef.id,
        habitName: _habitBuilder.name!,
        time: _habitBuilder.time!,
        days: _habitBuilder.days!,
      );
      
      if (!mounted) return;
      
      _addVitoMessage('¡Listo! ✅\n\nTu hábito "${_habitBuilder.name}" ha sido creado. ¡Vamos por ese cambio positivo! 💪', withTyping: false);
      
      // Esperamos un poco para que el usuario lea el mensaje y luego cerramos.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });
      
    } catch (e) {
      // Si algo falla, ahora sí mostramos el error.
      print("Error creando hábito: $e"); // Bueno para depurar
      if (mounted) {
        _addVitoMessage('Oh no 😔\n\nHubo un problema al crear tu hábito. ¿Podrías intentarlo de nuevo desde el principio?', withTyping: false);
        setState(() => _isProcessing = false);
      }
    }
  }

// En _VitoChatHabitSheetState

Future<void> _updateHabitFromBuilder() async {
  setState(() => _isProcessing = true);

  // --- CAMBIO CLAVE: Bloqueamos la UI ANTES de empezar ---
  _messages.removeWhere((m) => m.text == 'ACTION_BUTTONS');
  HapticFeedback.mediumImpact();
    
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.habit == null) throw Exception('Usuario o hábito no válido');

    final updatedData = {
      'name': _habitBuilder.name,
      'category': _habitBuilder.category,
      'days': _habitBuilder.days!..sort(),
      'specificTime': {
        'hour': _habitBuilder.time!.hour,
        'minute': _habitBuilder.time!.minute,
      },
      // Aquí podrías añadir los otros campos si la IA los modifica
      'targetValue': _habitBuilder.targetValue,
      'unit': _habitBuilder.unit,
      'type': _habitBuilder.type,
    };

    await FirestoreService.updateHabit(widget.habit!.id, updatedData);

    // Reprogramar notificaciones
    await NotificationService.cancelHabitNotifications(widget.habit!.id, widget.habit!.days);
    await NotificationService.scheduleHabitNotification(
      habitId: widget.habit!.id,
      habitName: _habitBuilder.name!,
      time: _habitBuilder.time!,
      days: _habitBuilder.days!,
    );
      
    if (!mounted) return;
      
    _addVitoMessage('¡Hábito actualizado! ✨\n\nLos cambios para "${_habitBuilder.name}" han sido guardados.', withTyping: false);
      
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });

  } catch (e) {
    print("Error actualizando hábito: $e"); // Bueno para depurar
    if (mounted) {
      _addVitoMessage('Ups, algo salió mal al actualizar. ¿Lo intentamos de nuevo?', withTyping: false);
      setState(() => _isProcessing = false);
    }
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
              child: MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: GoogleFonts.poppins(
                    fontSize: 15,
                    color: isVito ? const Color(0xFF1E293B) : Colors.white,
                    height: 1.5,
                  ),
                  strong: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: isVito ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  listBullet: GoogleFonts.poppins(
                    fontSize: 15,
                    color: isVito ? const Color(0xFF1E293B) : Colors.white,
                  ),
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
          // Botón inteligente que cambia según el modo
          _buildActionButton(
            isEditMode ? 'Guardar Cambios' : 'Crear Hábito',
            isEditMode ? Icons.save_alt_rounded : Icons.check_circle,
            AppColors.success,
            () => isEditMode ? _updateHabitFromBuilder() : _createHabitFromBuilder(),
          ),
          _buildActionButton(
            'Ajustar',
            Icons.edit,
            AppColors.warning,
            () {
              _messages.removeWhere((m) => m.text == 'ACTION_BUTTONS');
              _addVitoMessage('Claro, ¿qué te gustaría cambiar?');
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