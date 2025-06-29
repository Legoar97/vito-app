import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // Animaciones
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _breathingController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  
  // Focus nodes para animaciones
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Inicializar animaciones con duraciones más largas y chill
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..forward();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..forward();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
    
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // Listeners para animaciones de focus
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _breathingController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if(mounted) {
        _showErrorSnackBar(_getErrorMessage(e.code));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    HapticFeedback.lightImpact();
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showWarningSnackBar('Ingresa un correo válido para restablecer la contraseña');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showSuccessSnackBar('Se ha enviado un enlace de recuperación a tu correo');
      }
    } on FirebaseAuthException catch (e) {
       if (mounted) {
        _showErrorSnackBar(_getErrorMessage(e.code));
      }
    }
  }

  String _getErrorMessage(String code) {
    print('Firebase Auth Error Code: $code'); // ¡Muy útil para depurar!
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta registrada con este correo.';
      case 'wrong-password':
      case 'invalid-credential': // Nuevo código de error para credenciales inválidas
        return 'Las credenciales no son validas. Inténtalo de nuevo.';
      case 'invalid-email':
        return 'El formato del correo electrónico es inválido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta de nuevo más tarde.';
      case 'network-request-failed':
        return 'Error de red. Revisa tu conexión a internet.';
      default:
        return 'Ocurrió un error inesperado. Por favor, intenta de nuevo.';
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente más suave y calmado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6B5B95), // Lavanda suave
                  const Color(0xFF88B0D3), // Azul cielo tranquilo
                  const Color(0xFFB8E6B8), // Verde menta relajante
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // Efecto de ondas suaves en el fondo
          ..._buildWaveElements(),
          
          // Partículas flotantes zen
          ..._buildFloatingParticles(),
          
          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildLogo(),
                    const SizedBox(height: 50),
                    _buildGlassCard(),
                    const SizedBox(height: 24),
                    _buildRegisterLink(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildWaveElements() {
    return [
      // Onda inferior
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
      // Segunda onda más suave
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
  
// En tu clase _LoginScreenState (dentro de login_screen.dart)

  Widget _buildLogo() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutQuart,
        )),
        // --- CAMBIO CLAVE: Se eliminó el AnimatedBuilder y el Transform.scale ---
        // Ahora devolvemos directamente la columna con los elementos visuales estáticos.
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    // Usamos valores fijos en lugar de los que dependen de 'breathValue'
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.spa_rounded,
                size: 60,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Vito',
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Tu espacio de bienestar',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
    
  Widget _buildGlassCard() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuart),
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _fadeController,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
        ),
        child: AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: Colors.white.withOpacity(0.15 + _breathingController.value * 0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          icon: Icons.email_rounded,
                          label: 'Correo electrónico',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => 
                            value!.isEmpty || !value.contains('@') 
                              ? 'Ingresa un correo válido' 
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          icon: Icons.lock_rounded,
                          label: 'Contraseña',
                          isPassword: true,
                          validator: (value) => 
                            value!.length < 6 
                              ? 'Mínimo 6 caracteres' 
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              '¿Olvidaste tu contraseña?',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildLoginButton(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    final bool isFocused = focusNode.hasFocus;
    final bool hasText = controller.text.isNotEmpty;

    // Envolvemos todo en una columna para tener el label arriba
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Label que aparece/desaparece suavemente
        Padding(
          padding: const EdgeInsets.only(left: 20.0, bottom: 8.0),
          child: AnimatedOpacity(
            opacity: isFocused || hasText ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeIn,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        
        // 2. El campo de texto con efecto de vidrio
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFocused 
                  ? Colors.white.withOpacity(0.4)
                  : Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: isFocused ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ] : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                obscureText: isPassword && _obscurePassword,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
                decoration: InputDecoration(
                  // CAMBIO CLAVE: Usamos hintText y lo ocultamos cuando el label de arriba es visible
                  hintText: isFocused || hasText ? '' : label,
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16, // Hacemos que el hint tenga el mismo tamaño que el texto
                    fontWeight: FontWeight.w300,
                  ),
                  // Ya no usamos labelText aquí
                  prefixIcon: Icon(
                    icon,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  suffixIcon: isPassword
                      ? IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword 
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.red.shade300, width: 1),
                  ),
                  errorStyle: GoogleFonts.poppins(color: Colors.red.shade200, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                validator: validator,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLoginButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      child: AnimatedBuilder(
        animation: _breathingController,
        builder: (context, child) {
          return ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.9 + _breathingController.value * 0.1),
              foregroundColor: const Color(0xFF6B5B95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: _isLoading ? 0 : 5 + _breathingController.value * 3,
              shadowColor: Colors.white.withOpacity(0.3),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF6B5B95),
                      ),
                    ),
                  )
                : Text(
                    'Iniciar Sesión',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
          );
        },
      ),
    );
  }
  
  Widget _buildRegisterLink() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Primera vez aquí?',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.7),
              fontSize: 15,
              fontWeight: FontWeight.w300,
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/signup');
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(
              children: [
                Text(
                  'Únete a Vito',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.9),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withOpacity(0.5),
                    decorationThickness: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter para las ondas suaves
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