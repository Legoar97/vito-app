// File: ai_coach_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';
import 'dart:math' as math;

import '../theme/app_colors.dart';
import '../services/vertex_ai_service.dart';
import '../models/chat_message.dart';
import '../services/stats_processing_service.dart';

// <<< Se eliminó el widget 'BackgroundBlob' y las animaciones de fondo >>>

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
  
  late AnimationController _typingAnimationController;
  
  bool _isTyping = false;
  final User? user = FirebaseAuth.instance.currentUser;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    
    _typingAnimationController = AnimationController(
      duration: const Duration(seconds: 2), vsync: this
    );
    
    _loadUserName();
  }
  
  void _loadUserName() async {
    if (user != null) {
      final displayName = user!.displayName ?? '';
      _userName = displayName.isNotEmpty ? displayName.split(' ').first : 'amigo';
    }
  }

  @override
  void dispose() {
    _summarizeAndSaveConversation();
    _typingAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // (El resto de la lógica como _summarizeAndSaveConversation y _scrollToBottom se mantiene igual)
  Future<void> _summarizeAndSaveConversation() async {
    if (_messages.length > 4 && user != null) {
      try {
        final summary = await VertexAIService.summarizeConversation(conversationHistory: _messages);
        if (summary.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'lastVitoSummary': summary});
        }
      } catch (e) {
        print('Error al guardar el resumen: $e');
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // <<< 1. FONDO CAMBIADO A BLANCO SÓLIDO >>>
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Se eliminó el fondo orgánico de aquí.
          
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(child: _buildChatArea()),
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          _buildFloatingHeader(),
          _buildFloatingInputField(),
        ],
      ),
    );
  }

Widget _buildFloatingHeader() {
  return Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 15),
          decoration: BoxDecoration(
            // <<< ¡AQUÍ ESTÁ LA MAGIA! >>>
            // Se reemplazó el color sólido por un gradiente sutil.
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.primary.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 1.5),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vito',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'En línea',
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _showInfoDialog,
                icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildChatArea() {
    return _messages.isEmpty && !_isTyping
        ? _buildEmptyState()
        : ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 95, bottom: 20, left: 20, right: 20),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isTyping && index == _messages.length) return _buildTypingIndicator();
              return _AnimatedMessage(child: _buildMessage(_messages[index]));
            },
          );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // <<< 4. ÍCONO DE ESTADO VACÍO AHORA ES MORADO >>>
          Icon(Icons.auto_awesome_outlined, color: AppColors.primary.withOpacity(0.7), size: 60),
          const SizedBox(height: 20),
          Text(
            'Inicia una conversación',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            'Vito está listo para escucharte.',
            style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isVito = message.type == MessageType.vito;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isVito ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                // <<< 5. BURBUJA DEL USUARIO AHORA ES DE UN SOLO COLOR MORADO >>>
                color: isVito ? Colors.grey.shade100 : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isVito ? 4 : 24),
                  bottomRight: Radius.circular(isVito ? 24 : 4),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: GoogleFonts.poppins(color: isVito ? const Color(0xFF1E293B) : Colors.white, fontSize: 15, height: 1.55),
                  listBullet: GoogleFonts.poppins(color: isVito ? const Color(0xFF1E293B) : Colors.white, fontSize: 15),
                  strong: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isVito ? const Color(0xFF1E293B) : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFloatingInputField() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isTyping,
                style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _isTyping || _messageController.text.isEmpty ? null : _sendMessage,
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _isTyping || _messageController.text.isEmpty ? Colors.grey.shade300 : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (El resto de métodos como _sendMessage, _getUserContext, etc., se mantienen sin cambios)
  
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isTyping) return;

    HapticFeedback.lightImpact();

    final userMessage = ChatMessage(text: messageText, type: MessageType.user, timestamp: DateTime.now());
    setState(() { _messages.add(userMessage); _isTyping = true; });
    _messageController.clear();
    _scrollToBottom();

    String responseText;
    try {
      final classification = await VertexAIService.classifyIntentAndSentiment(userMessage: messageText, conversationHistory: _messages);
      final intent = classification['intent'] ?? 'general_chat';
      final sentiment = classification['sentiment'] ?? 'neutral';

      switch (intent) {
        case 'greeting': responseText = messageText.toLowerCase().contains('cómo estás') ? '¡Gracias por preguntar! 😊 Estoy listo y con toda la energía para ayudarte. ¿Cómo estás tú hoy?' : '¡Hola de nuevo, ¿cómo estás?! ¿Hay algo en lo que pueda ayudarte o alguna idea que te ronde la cabeza hoy?'; break;
        case 'crisis': responseText = 'Comprendo que estás en un momento extremadamente difícil. Es muy valiente de tu parte buscar ayuda.\n\n**Por favor, debes saber que no soy un profesional de la salud. Lo más importante ahora es que hables con alguien que sí pueda ofrecerte el apoyo que necesitas.**\n\nContacta a una línea de prevención de crisis o a un servicio de emergencia de inmediato. No estás solo en esto. Tu vida es increíblemente valiosa.'; break;
        case 'venting': responseText = await VertexAIService.getCompassionateResponse(conversationHistory: _messages); break;
        default:
          if (sentiment == 'negative' && intent != 'seeking_advice') {
            responseText = await VertexAIService.getCompassionateResponse(conversationHistory: _messages);
          } else {
            final userContext = await _getUserContext();
            responseText = await VertexAIService.getHabitAdvice(conversationHistory: _messages, userContext: userContext);
          }
          break;
      }
    } catch (e) {
      print('Error en la lógica de _sendMessage: $e');
      responseText = "Uups, parece que mis circuitos se cruzaron por un momento. ¿Podrías repetirme eso, por favor?";
    }

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: responseText, type: MessageType.vito, timestamp: DateTime.now()));
      });
      _scrollToBottom();
    }
  }

  Future<Map<String, dynamic>> _getUserContext() async {
    if (user == null) return {'userName': 'Usuario', 'wellnessReport': 'No hay datos disponibles.'};
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final lastSummary = userDoc.data()?['lastVitoSummary'] as String? ?? 'Ninguna conversación previa.';
      final wellnessReport = await StatsProcessingService.getWellnessReportForAI();
      return {'userName': _userName, 'lastConversationSummary': lastSummary, 'wellnessReport': wellnessReport};
    } catch (e) {
      print('Error al obtener el contexto del usuario para la IA: $e');
      return {'userName': _userName, 'lastConversationSummary': 'No disponible.', 'wellnessReport': 'No se pudo cargar el informe de bienestar.'};
    }
  }

  Widget _buildTypingIndicator() {
    _typingAnimationController.repeat();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24),
              bottomLeft: Radius.circular(4), bottomRight: Radius.circular(24),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(children: [_buildTypingDot(0), const SizedBox(width: 4), _buildTypingDot(1), const SizedBox(width: 4), _buildTypingDot(2)]),
        ),
      ],
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final value = (_typingAnimationController.value + (index * 0.3)) % 1.0;
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3 + (0.5 * math.sin(value * math.pi))),
            shape: BoxShape.circle,
          ),
        );
      },
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
                ),
                const SizedBox(height: 20),
                Text('Sobre Vito AI', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                const SizedBox(height: 12),
                Text('Soy tu coach de bienestar. Puedo ayudarte con:', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B), height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                _buildInfoItem(Icons.track_changes, 'Crear y mejorar hábitos'),
                _buildInfoItem(Icons.psychology, 'Consejos personalizados'),
                _buildInfoItem(Icons.favorite, 'Apoyo motivacional'),
                _buildInfoItem(Icons.calendar_today, 'Planificación de rutinas'),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: Text('Entendido', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF475569))),
        ],
      ),
    );
  }
}

class _AnimatedMessage extends StatefulWidget {
  final Widget child;
  const _AnimatedMessage({required this.child});

  @override
  State<_AnimatedMessage> createState() => __AnimatedMessageState();
}

class __AnimatedMessageState extends State<_AnimatedMessage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}