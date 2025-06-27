import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:math' as math;

import '../theme/app_colors.dart';
import '../services/vertex_ai_service.dart';
import '../models/chat_message.dart';

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "¡Hola! Soy Vito, tu coach de bienestar con IA. Estoy aquí para ayudarte a construir mejores hábitos y alcanzar tus metas. ¿En qué te gustaría trabajar hoy?",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  bool _isTyping = false;
  bool _showQuickActions = true; // <-- AÑADIDO: Para controlar la visibilidad

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FE), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              // <<<--- MODIFICADO: Animación para ocultar las acciones rápidas
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return SizeTransition(sizeFactor: animation, child: child);
                },
                child: _showQuickActions ? _buildQuickActions() : const SizedBox.shrink(),
              ),
              Expanded(
                child: _buildChatList(),
              ),
              _buildInputField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // ... (Sin cambios aquí)
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Coach de Bienestar IA', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Impulsado por Vertex AI', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    // ... (Sin cambios aquí)
     final actions = [
      {'icon': Icons.lightbulb, 'label': 'Consejos', 'color': AppColors.warning},
      {'icon': Icons.trending_up, 'label': 'Analizar', 'color': AppColors.success},
      {'icon': Icons.calendar_today, 'label': 'Planificar', 'color': AppColors.primary},
      {'icon': Icons.favorite, 'label': 'Motivar', 'color': AppColors.error},
    ];

    return Container(
      key: const ValueKey('quickActions'), // Key para el AnimatedSwitcher
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return GestureDetector(
            onTap: () => _handleQuickAction(action['label'] as String),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      action['icon'] as IconData,
                      color: action['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatList() {
    // ... (Sin cambios aquí)
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isTyping && index == 0) {
          return _buildTypingIndicator();
        }
        final messageIndex = _isTyping ? index - 1 : index;
        final message = _messages[messageIndex];
        return _buildMessage(message);
      },
    );
  }

  Widget _buildMessage(ChatMessage message) {
    // ... (Sin cambios aquí)
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  listBullet: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, color: Colors.grey[600], size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    // ... (Sin cambios aquí)
    _animationController.repeat();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    // ... (Sin cambios aquí)
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final offset = math.sin((_animationController.value * 2 * math.pi) + (index * math.pi / 2)) * 3;
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildInputField() {
    // ... (Sin cambios aquí)
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
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
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Pregúntame sobre hábitos...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _handleQuickAction(String action) {
    // ... (Sin cambios aquí)
    String prompt;
    switch (action) {
      case 'Consejos':
        prompt = '¿Puedes darme algunos consejos para mejorar mis hábitos diarios?';
        break;
      case 'Analizar':
        prompt = '¿Puedes analizar mi progreso de hábitos y sugerir mejoras?';
        break;
      case 'Planificar':
        prompt = 'Ayúdame a crear un plan semanal de hábitos';
        break;
      case 'Motivar':
        prompt = 'Necesito algo de motivación para seguir con mis hábitos';
        break;
      default:
        return;
    }
    _messageController.text = prompt;
    _sendMessage();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // <<<--- AÑADIDO: Oculta las acciones rápidas al enviar el primer mensaje
    if (_showQuickActions) {
      setState(() {
        _showQuickActions = false;
      });
    }

    final userMessage = ChatMessage(
      text: _messageController.text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    final userContext = await _getUserContext();
    
    // <<<--- MODIFICADO: Prepara el historial para la API
    // Se revierte la lista aquí para que tenga el orden cronológico correcto (viejo a nuevo)
    final conversationForAPI = _messages.reversed.toList();

    // <<<--- MODIFICADO: Llama al servicio con el historial completo
    final response = await VertexAIService.getHabitAdvice(
      conversationHistory: conversationForAPI,
      userContext: userContext,
    );
    
    if(mounted) {
      setState(() {
        _isTyping = false;
        _messages.insert(0, ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }

    _animationController.stop();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    // ... (Sin cambios aquí)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<Map<String, dynamic>> _getUserContext() async {
    // ... (Sin cambios aquí)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'habits': [],
        'completionRate': 0,
        'streak': 0,
        'categories': [],
      };
    }

    try {
      final habitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .get();

      final habits = habitsSnapshot.docs.map((doc) => doc.data()['name'] as String? ?? 'Hábito sin nombre').toList();
      
      int totalHabitsToday = 0;
      int completedToday = 0;
      Set<String> categories = {};
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      for (var doc in habitsSnapshot.docs) {
        final data = doc.data();
        final days = List<int>.from(data['days'] ?? []);
        
        if(days.contains(today.weekday)) {
            totalHabitsToday++;

            final completions = List<Timestamp>.from(data['completions'] ?? []);
            
            if (completions.any((ts) {
                final date = ts.toDate();
                return date.year == today.year && date.month == today.month && date.day == today.day;
            })) {
              completedToday++;
            }
        }
        
        if (data['category'] != null) {
          categories.add(data['category']);
        }
      }
      
      final completionRate = totalHabitsToday > 0 
          ? ((completedToday / totalHabitsToday) * 100).round() 
          : 0;

      return {
        'habits': habits,
        'completionRate': completionRate,
        'streak': 7, // TODO: Calcular la racha real
        'categories': categories.toList(),
      };
    } catch (e) {
      if(mounted) {
        print('Error al obtener el contexto del usuario: $e');
      }
      return {
        'habits': [],
        'completionRate': 0,
        'streak': 0,
        'categories': [],
      };
    }
  }
}
