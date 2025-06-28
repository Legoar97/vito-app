import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:intl/intl.dart';

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
      text: "¡Hola! Soy Vito, tu coach de bienestar con IA. ¿En qué te gustaría enfocarte hoy?",
      type: MessageType.vito,
      timestamp: DateTime.now(),
    ),
  ];
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  bool _isTyping = false;
  bool _showQuickActions = true;
  final User? user = FirebaseAuth.instance.currentUser;

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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // In a reversed ListView, 0 is the bottom.
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
          Text('Impulsado por Gemini', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.lightbulb_outline, 'label': 'Consejos', 'color': AppColors.warning},
      {'icon': Icons.calendar_today_outlined, 'label': 'Planificar', 'color': AppColors.primary},
      {'icon': Icons.favorite_border, 'label': 'Motivar', 'color': AppColors.error},
      {'icon': Icons.auto_awesome_motion_outlined, 'label': 'Crear Rutina', 'color': AppColors.success},
    ];

    return Container(
      key: const ValueKey('quickActions'),
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
    final isUser = message.type == MessageType.user;
    
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
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
              child: const Icon(Icons.person_outline, color: Colors.grey, size: 20),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    _animationController.repeat();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
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
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleQuickAction(String action) {
    String prompt;
    switch (action) {
      case 'Consejos':
        prompt = 'Dame un consejo rápido de bienestar.';
        break;
      case 'Planificar':
        prompt = 'Ayúdame a planificar mis hábitos para mañana.';
        break;
      case 'Motivar':
        prompt = 'Necesito una frase motivadora para seguir adelante.';
        break;
      case 'Crear Rutina':
        _showCreateRoutineDialog();
        return; 
      default:
        return;
    }
    _messageController.text = prompt;
    _sendMessage();
  }

  void _showCreateRoutineDialog() {
    final routineController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Generador de Rutinas IA'),
          content: TextField(
            controller: routineController,
            decoration: const InputDecoration(
              hintText: 'Ej: "mañanas productivas"',
              labelText: '¿Qué tipo de rutina quieres?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (routineController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _sendMessage(isRoutineRequest: true, userContent: routineController.text);
                }
              },
              child: const Text('Generar'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _sendMessage({bool isRoutineRequest = false, String? userContent}) async {
    final messageText = userContent ?? _messageController.text.trim();
    if (messageText.isEmpty) return;

    if (_showQuickActions) {
      setState(() => _showQuickActions = false);
    }

    final userMessage = ChatMessage(text: messageText, type: MessageType.user, timestamp: DateTime.now());

    setState(() {
      _messages.insert(0, userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    final userContext = await _getUserContext();
    final conversationForAPI = _messages.reversed.toList();
    
    if (isRoutineRequest) {
      final jsonResponse = await VertexAIService.getRoutine(userGoal: messageText, userContext: userContext);
      _handleRoutineResponse(jsonResponse);

    } else {
      final response = await VertexAIService.getHabitAdvice(conversationHistory: conversationForAPI, userContext: userContext);
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.insert(0, ChatMessage(text: response, type: MessageType.vito, timestamp: DateTime.now()));
        });
      }
    }
    
    _animationController.stop();
    _scrollToBottom();
  }

  void _handleRoutineResponse(String jsonResponse) {
    setState(() => _isTyping = false);
    try {
      final decoded = jsonDecode(jsonResponse);
      final List<dynamic> habits = decoded['habits'];
      
      _messages.insert(0, ChatMessage(text: "¡Claro! He preparado esta rutina para ti. ¿Quieres añadirla a tus hábitos?", type: MessageType.vito, timestamp: DateTime.now()));
      
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Rutina Sugerida por Vito'),
            content: SingleChildScrollView(
              child: ListBody(
                children: habits.map<Widget>((habit) {
                  return ListTile(
                    leading: Icon(AppColors.getCategoryIcon(habit['category'] ?? 'otros')),
                    title: Text(habit['name']),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () {
                _addRoutineHabits(habits);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Rutina añadida a tus hábitos!'), backgroundColor: AppColors.success));
              }, child: const Text('Añadir Hábitos')),
            ],
          );
        }
      );
    } catch (e) {
      _messages.insert(0, ChatMessage(text: "Lo siento, no pude procesar la rutina. Inténtalo de nuevo.", type: MessageType.vito, timestamp: DateTime.now()));
    }
  }

  Future<void> _addRoutineHabits(List<dynamic> habits) async {
    if (user == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    final habitsCollection = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits');

    for (var habit in habits) {
      final newHabitRef = habitsCollection.doc();
      batch.set(newHabitRef, {
        'name': habit['name'],
        'category': habit['category'] ?? 'otros',
        'days': [1, 2, 3, 4, 5, 6, 7],
        'specificTime': {'hour': 8, 'minute': 0},
        'notifications': true, 'completions': [], 'createdAt': Timestamp.now(), 'streak': 0, 'longestStreak': 0,
      });
    }

    await batch.commit();
  }
  
  Future<Map<String, dynamic>> _getUserContext() async {
    if (user == null) return {};

    try {
      final habitsSnapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('habits').get();
      final habitsDetails = habitsSnapshot.docs.map((doc) {
        final data = doc.data();
        final completions = List<Timestamp>.from(data['completions'] ?? []);
        final isCompletedToday = completions.any((ts) => DateUtils.isSameDay(ts.toDate(), DateTime.now()));
        return {
          'name': data['name'],
          'frequency': (data['days'] as List).length,
          'isCompletedToday': isCompletedToday
        };
      }).toList();

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final moodDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('mood_tracker').doc(todayStr).get();
      final moodToday = moodDoc.exists ? moodDoc.data()!['mood'] : 'No registrado';
      
      return {
        'habits': habitsDetails,
        'moodToday': moodToday,
      };
    } catch (e) {
      print('Error al obtener el contexto del usuario: $e');
      return {};
    }
  }
}
