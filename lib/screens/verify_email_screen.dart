// lib/screens/verify_email_screen.dart

import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> 
    with TickerProviderStateMixin {
  bool isEmailVerified = false;
  Timer? timer;
  bool canResendEmail = false;
  int resendCooldown = 0;
  Timer? cooldownTimer;
  
  // Animaciones
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _breathingController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  late AnimationController _checkController;
  
  // Animation para el ícono de email
  late Animation<double> _emailBounce;

  @override
  void initState() {
    super.initState();
    
    // Inicializar animaciones (esto está bien)
    _fadeController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..forward();
    _slideController = AnimationController(duration: const Duration(milliseconds: 1800), vsync: this)..forward();
    _breathingController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _waveController = AnimationController(duration: const Duration(seconds: 8), vsync: this)..repeat();
    _particleController = AnimationController(duration: const Duration(seconds: 20), vsync: this)..repeat();
    _checkController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _emailBounce = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut));
    
    final user = FirebaseAuth.instance.currentUser;
    isEmailVerified = user?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Inicia un cooldown inicial de 10 segundos antes de poder reenviar la primera vez.
      startCooldown(60); 
      
      // Comprueba si el email se verificó cada 3 segundos.
      timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    cooldownTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _breathingController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _checkController.dispose();
    super.dispose();
  }
  
  // Esta función maneja la cuenta regresiva.
  void startCooldown(int seconds) {
    setState(() {
      canResendEmail = false;
      resendCooldown = seconds;
    });
    
    cooldownTimer?.cancel(); // Cancela cualquier timer anterior para evitar errores.
    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldown > 0) {
        setState(() {
          resendCooldown--;
        });
      } else {
        setState(() {
          canResendEmail = true;
        });
        timer.cancel(); // Detiene el timer cuando llega a 0.
      }
    });
  }

  Future<void> checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    final wasVerified = isEmailVerified;
    if (mounted) {
      setState(() {
        isEmailVerified = user?.emailVerified ?? false;
      });
    }

    if (isEmailVerified && !wasVerified) {
      _checkController.forward();
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        timer?.cancel();
        context.go('/home');
      }
    }
  }

  Future<void> sendVerificationEmail() async {
    HapticFeedback.mediumImpact();
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      // Cuando se reenvía, inicia la cuenta regresiva de 60 segundos (1 minuto).
      startCooldown(60); 

      if (mounted) {
        _showSnackBar('¡Correo enviado! Revisa tu bandeja de entrada', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al enviar. Intenta más tarde', Colors.red);
      }
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6B5B95), // Lavanda
                  Color(0xFF88B0D3), // Azul cielo
                  Color(0xFFB8E6B8), // Verde menta
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // Ondas suaves
          ..._buildWaveElements(),
          
          // Partículas flotantes
          ..._buildFloatingParticles(),
          
          // Botón de retroceso
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      timer?.cancel();
                      await FirebaseAuth.instance.signOut();
                      if (mounted) context.go('/login');
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Contenido principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícono animado
                      FadeTransition(
                        opacity: _fadeController,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _slideController,
                            curve: Curves.easeOutQuart,
                          )),
                          child: AnimatedBuilder(
                            animation: _emailBounce,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _emailBounce.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.15),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(70),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            isEmailVerified 
                                                ? Icons.check_circle_rounded
                                                : Icons.mark_email_unread_rounded,
                                            size: 70,
                                            color: Colors.white,
                                          ),
                                          if (isEmailVerified)
                                            ScaleTransition(
                                              scale: _checkController,
                                              child: Icon(
                                                Icons.check_circle_rounded,
                                                size: 70,
                                                color: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Textos
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _fadeController,
                          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _slideController,
                            curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuart),
                          )),
                          child: Column(
                            children: [
                              Text(
                                isEmailVerified 
                                    ? '¡Email verificado!' 
                                    : 'Verifica tu email',
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isEmailVerified
                                    ? 'Redirigiendo...'
                                    : 'Hemos enviado un enlace de verificación a:',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w300,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  user?.email ?? 'tu-email@ejemplo.com',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Botones
                      if (!isEmailVerified) ...[
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _slideController,
                            curve: const Interval(0.5, 1.0, curve: Curves.easeOutQuart),
                          )),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _fadeController,
                              curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: AnimatedBuilder(
                                animation: _breathingController,
                                builder: (context, child) {
                                  return ElevatedButton.icon(
                                    onPressed: canResendEmail ? sendVerificationEmail : null,
                                    icon: Icon(
                                      Icons.send_rounded,
                                      color: canResendEmail 
                                          ? const Color(0xFF6B5B95)
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                    label: Text(
                                      canResendEmail
                                          ? 'Reenviar correo'
                                          : 'Espera ${resendCooldown}s',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canResendEmail
                                          ? Colors.white.withOpacity(0.9 + _breathingController.value * 0.1)
                                          : Colors.white.withOpacity(0.3),
                                      foregroundColor: canResendEmail
                                          ? const Color(0xFF6B5B95)
                                          : Colors.white.withOpacity(0.7),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: canResendEmail 
                                          ? 5 + _breathingController.value * 3
                                          : 0,
                                      shadowColor: Colors.white.withOpacity(0.3),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Texto informativo
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _fadeController,
                            curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Revisa también tu carpeta de spam',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Botón de cancelar
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _fadeController,
                            curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              timer?.cancel();
                              await FirebaseAuth.instance.signOut();
                              if (mounted) context.go('/login');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Usar otro email',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Elementos visuales (ondas)
  List<Widget> _buildWaveElements() {
    return [
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 150),
              painter: WavePainter(
                animationValue: _waveController.value,
                color: Colors.white.withOpacity(0.1),
              ),
            );
          },
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 120),
              painter: WavePainter(
                animationValue: _waveController.value + 0.5,
                color: Colors.white.withOpacity(0.05),
              ),
            );
          },
        ),
      ),
    ];
  }
  
  // Partículas flotantes
  List<Widget> _buildFloatingParticles() {
    return List.generate(6, (index) {
      final random = math.Random(index);
      final size = 60.0 + random.nextDouble() * 40;
      final left = random.nextDouble() * 400 - 100;
      final top = random.nextDouble() * 800 - 100;
      final delay = random.nextDouble();
      
      return Positioned(
        left: left,
        top: top,
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            final value = (_particleController.value + delay) % 1.0;
            return Transform.translate(
              offset: Offset(
                math.sin(value * 2 * math.pi) * 30,
                -value * 800,
              ),
              child: Opacity(
                opacity: (1 - value) * 0.3,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

// Wave Painter (reutilizado)
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  
  WavePainter({
    required this.animationValue,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final waveHeight = 20.0;
    final waveLength = size.width;
    
    path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x++) {
      final y = size.height - 50 + 
          math.sin((x / waveLength * 2 * math.pi) + (animationValue * 2 * math.pi)) * 
          waveHeight;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}