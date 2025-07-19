// lib/screens/ai_coach_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:convert';

import '../theme/app_colors.dart';
import '../services/vertex_ai_service.dart';
import '../models/chat_message.dart';
import '../services/stats_processing_service.dart';

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
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  
  bool _isTyping = false;
  final User? user = FirebaseAuth.instance.currentUser;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    
    _typingAnimationController = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..forward();
    _scaleController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
    
    _loadUserName();
  }
  
  void _loadUserName() async {
    if (user != null) {
      final displayName = user?.displayName ?? '';
      _userName = displayName.isNotEmpty ? displayName.split(' ').first : 'amigo';
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _updateLongitudinalProfile();
    _typingAnimationController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

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
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              AppColors.primary.withOpacity(0.08),
              const Color(0xFFF9F9FB),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeaderSimplificado(),
            Expanded(
              child: _buildChatContent(),
            ),
            _buildInputFieldFijo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSimplificado() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vito', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                  Text('Tu compañero de bienestar', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: _showInfoDialog,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Icon(Icons.info_outline_rounded, color: Colors.grey[700], size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    if (_messages.isEmpty && !_isTyping) {
      return _buildEnhancedEmptyState();
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildEnhancedTypingIndicator();
        }
        return _AnimatedMessage(child: _buildEnhancedMessage(_messages[index]));
      },
    );
  }

  Widget _buildEnhancedEmptyState() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            ScaleTransition(
              scale: CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
              child: const Icon(Icons.spa_outlined, color: AppColors.primary, size: 80),
            ),
            const SizedBox(height: 24),
            Text(
              'Una conversación puede cambiar tu día',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estoy aquí para escucharte, $_userName.',
              style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 40),
            _buildConversationStarters(),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationStarters() {
    final starters = [
      {'icon': Icons.lightbulb_outline, 'text': '¿Cómo puedo mejorar mis hábitos?'},
      {'icon': Icons.favorite_outline, 'text': 'Necesito motivación'},
      {'icon': Icons.psychology_outlined, 'text': 'Quiero reducir mi estrés'},
      {'icon': Icons.bedtime_outlined, 'text': 'Ayúdame a dormir mejor'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: starters.map((starter) => 
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _messageController.text = starter['text'] as String;
            _sendMessage();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(starter['icon'] as IconData, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  starter['text'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildEnhancedMessage(ChatMessage message) {
    final isVito = message.type == MessageType.vito;

    return Padding(
      padding: EdgeInsets.only(
        left: isVito ? 20 : 80,
        right: isVito ? 80 : 20,
        bottom: 16,
      ),
      child: Row(
        mainAxisAlignment:
            isVito ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isVito) ...[
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isVito ? Colors.white : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isVito ? 8 : 24),
                  bottomRight: Radius.circular(isVito ? 24 : 8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              // Uso corregido de GptMarkdown:
              child: GptMarkdown(
                message.text, // el Markdown como argumento posicional :contentReference[oaicite:0]{index=0}
                style: GoogleFonts.poppins( // 'style' espera un TextStyle :contentReference[oaicite:1]{index=1}
                  color: isVito
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInputFieldFijo() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
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
                hintText: 'Escribe tu mensaje...',
                hintStyle: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: InkWell(
              onTap: _isTyping || _messageController.text.isEmpty ? null : _sendMessage,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isTyping || _messageController.text.isEmpty ? Colors.grey.shade400 : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (!_isTyping && _messageController.text.isNotEmpty)
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTypingIndicator() {
    _typingAnimationController.repeat();
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 80, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(24),
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
                const SizedBox(width: 6),
                _buildTypingDot(1),
                const SizedBox(width: 6),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3 + (0.7 * math.sin(value * math.pi))),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

// DENTRO DE: lib/screens/ai_coach_screen.dart -> _AICoachScreenState

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
      // PASO 1: Obtener el contexto enriquecido (ver siguiente sección).
      final userContext = await _getUserContext();

      // PASO 2: Llamada ÚNICA y DIRECTA a la IA. No más 'switch' ni 'classifyUserIntent'.
      final responseText = await VertexAIService.getSmartResponse(
        conversationHistory: _messages,
        userContext: userContext,
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: responseText,
            type: MessageType.vito,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('🚨 Error en la llamada principal a la IA: $e');
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: "Uups, mis circuitos se cruzaron. ¿Podrías repetirme eso?",
            type: MessageType.vito,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    }
  }

  Future<Map<String, dynamic>> _getUserContext() async {
    if (user == null) return {'userName': 'Usuario', 'wellnessReport': 'No hay datos disponibles.'};

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userData = userDoc.data() ?? {};
      final wellnessReport = await StatsProcessingService.getWellnessReportForAI();

      // CORRECCIÓN: Usar '??' correctamente con valores por defecto.
      return {
        'userName': _userName,
        'wellnessReport': wellnessReport,
        'lastConversationSummary': userData['lastVitoSummary'] ?? 'Ninguna conversación previa.',
        'emotionalHistory': userData['historialEstadoEmocional'] ?? [], // Asumiendo que es una lista
        'declaredGoals': userData['declaredGoals'] ?? [], // Asumiendo que es una lista
        'coreValues': userData['valoresFundamentales'] ?? [], // Asumiendo que es una lista
        'identifiedStrengths': userData['fortalezasIdentificadas'] ?? [], // Asumiendo que es una lista
        'commonCognitiveDistortions': userData['distorsionesCognitivasComunes'] ?? [], // Asumiendo que es una lista
        'successfulStrategies': userData['estrategiasExitosas'] ?? [], // Asumiendo que es una lista
        'recurringThemes': userData['recurringThemes'] ?? [], // Asumiendo que es una lista
      };
    } catch (e) {
      print('Error al obtener el contexto del usuario para la IA: $e');
      return {
        'userName': _userName,
        'lastConversationSummary': 'No disponible.',
        'wellnessReport': 'No se pudo cargar el informe de bienestar.'
      };
    }
  }

  Future<void> _updateLongitudinalProfile() async {
    // Solo procesamos si la conversación es suficientemente larga para ser significativa
    if (_messages.length <= 4 || user == null) return;

    try {
      print("🧠 Iniciando actualización del perfil longitudinal...");

      // Primero, obtenemos el perfil actual del usuario desde Firestore.
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final currentUserProfile = userDoc.data() ?? {};

      // --- INICIO DE LA CORRECCIÓN ---
      // Creamos un mapa "serializable" para enviar a la IA.
      // Esto es crucial porque json.encode no puede manejar objetos Timestamp de Firestore.
      final Map<String, dynamic> serializableProfile = Map.from(currentUserProfile);
      
      serializableProfile.updateAll((key, value) {
        if (value is Timestamp) {
          // Convertimos el Timestamp a una cadena de texto estándar (ISO 8601)
          return value.toDate().toIso8601String();
        }
        // Si tienes Timestamps dentro de otras listas o mapas, necesitarías una conversión más profunda (recursiva).
        // Para campos de primer nivel, esto es suficiente.
        return value;
      });
      // --- FIN DE LA CORRECCIÓN ---

      // Llamamos a la función del servicio de IA, pasándole el perfil ya serializado.
      final updatesJsonString = await VertexAIService.updateUserProfileFromConversation(
        conversationHistory: _messages,
        currentUserProfile: serializableProfile, // Usamos el perfil corregido
      );

      // Decodificamos la respuesta JSON de la IA.
      final Map<String, dynamic> updates = json.decode(updatesJsonString);

      if (updates.isNotEmpty) {
        // Actualizamos el documento del usuario en Firestore.
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
          updates,
          SetOptions(merge: true),
        );
        print("✅ Perfil longitudinal actualizado con éxito.");
      }
    } catch (e) {
      print('🚨 Error al actualizar el perfil longitudinal: $e');
    }
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
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.secondary.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sobre Vito AI',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Soy tu coach personal de bienestar, diseñado para ayudarte a alcanzar tus metas y mejorar tu calidad de vida.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildInfoFeature(Icons.track_changes, 'Crear y mejorar hábitos'),
                _buildInfoFeature(Icons.psychology, 'Consejos personalizados'),
                _buildInfoFeature(Icons.favorite, 'Apoyo motivacional'),
                _buildInfoFeature(Icons.calendar_today, 'Planificación de rutinas'),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Entendido',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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

  Widget _buildInfoFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: const Color(0xFF475569),
            ),
          ),
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
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
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