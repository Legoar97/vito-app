import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';
import 'dart:math' as math;
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
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  late AnimationController _fadeController;
  late AnimationController _vitoAnimationController;
  late AnimationController _typingAnimationController;
  
  bool _isTyping = false;
  final User? user = FirebaseAuth.instance.currentUser;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _vitoAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _typingAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _loadUserName();
    _addWelcomeMessage();
  }
  
  void _loadUserName() {
    if (user != null) {
      setState(() {
        _userName = user!.displayName?.split(' ').first ?? 'amigo';
      });
    }
  }
  
  void _addWelcomeMessage() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "¡Hola $_userName! 👋\n\nSoy Vito, tu coach personal de bienestar. Estoy aquí para ayudarte con tus hábitos, darte consejos personalizados y apoyarte en tu camino hacia una vida más saludable.\n\n¿En qué puedo ayudarte hoy?",
            type: MessageType.vito,
            timestamp: DateTime.now(),
          ));
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _vitoAnimationController.dispose();
    _typingAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(),
            Expanded(
              child: _buildChatArea(),
            ),
            _buildModernInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
            animation: _vitoAnimationController,
            builder: (context, child) {
              return Container(
                width: 56,
                height: 56,
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
                      blurRadius: 15 + (5 * math.sin(_vitoAnimationController.value * 2 * math.pi)),
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          
          // Título y estado
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vito AI Coach',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Siempre disponible para ti',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Botón de información
          IconButton(
            onPressed: () => _showInfoDialog(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: const Color(0xFF64748B),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8FAFC),
            Colors.white.withOpacity(0.8),
          ],
        ),
      ),
      child: _messages.isEmpty && !_isTyping
          ? _buildEmptyState()
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                
                return FadeTransition(
                  opacity: _fadeController,
                  child: _buildMessage(_messages[index], index),
                );
              },
            ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeController,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 50,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando a Vito...',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu coach personal está preparándose',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessage(ChatMessage message, int index) {
    final isVito = message.type == MessageType.vito;
    final bool isFirstMessage = index == 0 && isVito;
    
    return Padding(
      padding: EdgeInsets.only(
        left: isVito ? 0 : 60,
        right: isVito ? 60 : 0,
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isVito) ...[
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.8),
                          AppColors.primary.withOpacity(0.6),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                );
              },
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
                    color: (isVito ? Colors.black : AppColors.primary)
                        .withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isVito ? Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ) : null,
              ),
              child: isFirstMessage 
                  ? _buildAnimatedWelcomeText(message.text)
                  : MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: GoogleFonts.poppins(
                          color: isVito ? const Color(0xFF1E293B) : Colors.white,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        listBullet: GoogleFonts.poppins(
                          color: isVito ? const Color(0xFF1E293B) : Colors.white,
                          fontSize: 15,
                        ),
                        strong: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
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
  
  Widget _buildAnimatedWelcomeText(String text) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final visibleChars = (text.length * value).round();
        return Text(
          text.substring(0, visibleChars),
          style: GoogleFonts.poppins(
            color: const Color(0xFF1E293B),
            fontSize: 15,
            height: 1.5,
          ),
        );
      },
    );
  }
  
  Widget _buildTypingIndicator() {
    _typingAnimationController.repeat();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
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
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
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
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final value = (_typingAnimationController.value + (index * 0.3)) % 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3 + (0.5 * math.sin(value * math.pi))),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildModernInputField() {
    return Container(
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
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
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
                    enabled: !_isTyping,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        color: const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      suffixIcon: _messageController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _messageController.clear();
                                setState(() {});
                              },
                              icon: Icon(
                                Icons.clear_rounded,
                                color: const Color(0xFF94A3B8),
                                size: 20,
                              ),
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Botón de enviar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isTyping ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isTyping || _messageController.text.isEmpty
                              ? [Colors.grey[400]!, Colors.grey[300]!]
                              : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isTyping || _messageController.text.isEmpty
                                    ? Colors.grey
                                    : AppColors.primary)
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
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showInfoDialog() {
    HapticFeedback.lightImpact();
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
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
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sobre Vito AI',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Soy tu coach personal de bienestar potenciado por inteligencia artificial. Puedo ayudarte con:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildInfoItem(Icons.track_changes, 'Crear y mejorar hábitos'),
                _buildInfoItem(Icons.psychology, 'Consejos personalizados'),
                _buildInfoItem(Icons.favorite, 'Apoyo motivacional'),
                _buildInfoItem(Icons.calendar_today, 'Planificación de rutinas'),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Entendido',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isTyping) return;

    HapticFeedback.lightImpact();
    
    final userMessage = ChatMessage(
      text: messageText,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final userContext = await _getUserContext();
      final conversationForAPI = _messages.toList();
      
      final response = await VertexAIService.getHabitAdvice(
        conversationHistory: conversationForAPI,
        userContext: userContext,
      );
      
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: response,
            type: MessageType.vito,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: "Lo siento, hubo un problema al procesar tu mensaje. ¿Podrías intentarlo de nuevo?",
            type: MessageType.vito,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    }
    
    _typingAnimationController.stop();
  }
  
  Future<Map<String, dynamic>> _getUserContext() async {
    if (user == null) return {};

    try {
      final habitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('habits')
          .get();
          
      final habitsDetails = habitsSnapshot.docs.map((doc) {
        final data = doc.data();
        final completions = List<Timestamp>.from(data['completions'] ?? []);
        final isCompletedToday = completions.any((ts) => 
          DateUtils.isSameDay(ts.toDate(), DateTime.now())
        );
        
        return {
          'name': data['name'],
          'category': data['category'] ?? 'otros',
          'frequency': (data['days'] as List).length,
          'streak': data['streak'] ?? 0,
          'isCompletedToday': isCompletedToday,
        };
      }).toList();

      // Obtener mood del día si existe
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final moodSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('moods')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .limit(1)
          .get();
      
      String? moodToday;
      if (moodSnapshot.docs.isNotEmpty) {
        moodToday = moodSnapshot.docs.first.data()['mood'];
      }
      
      return {
        'userName': _userName,
        'habits': habitsDetails,
        'totalHabits': habitsDetails.length,
        'completedToday': habitsDetails.where((h) => h['isCompletedToday'] == true).length,
        'moodToday': moodToday ?? 'No registrado',
      };
    } catch (e) {
      print('Error al obtener el contexto del usuario: $e');
      return {'userName': _userName};
    }
  }
}