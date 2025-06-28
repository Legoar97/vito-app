import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;
  
  // Animaciones
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _breathingController;
  late AnimationController _waveController;
  late AnimationController _particleController;
  
  // Focus nodes
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  
  // Página actual del formulario
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    
    // Inicializar animaciones
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..forward();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1800),
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
    
    // Listeners
    _nameFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
    _confirmPasswordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _breathingController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _pageController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6B5B95),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  void _nextPage() {
    if (_currentPage == 0) {
      // Validar página 1
      if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
        _showSnackBar('Por favor completa todos los campos', AppColors.warning);
        return;
      }
      if (!_emailController.text.contains('@')) {
        _showSnackBar('Ingresa un correo válido', AppColors.warning);
        return;
      }
    }
    
    HapticFeedback.lightImpact();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage++);
  }
  
  void _previousPage() {
    HapticFeedback.lightImpact();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage--);
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate() || !_termsAccepted) return;

    if (_selectedBirthDate == null) {
      _showSnackBar('Por favor, selecciona tu fecha de nacimiento', AppColors.warning);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await FirestoreService.createOrUpdateUserProfile(
          userId: userCredential.user!.uid,
          displayName: _nameController.text.trim(),
          additionalData: {
            'gender': _selectedGender,
            'birthDate': _selectedBirthDate,
            'termsAcceptedOn': Timestamp.now(),
            'onboardingCompleted': false,
          },
        );
      }
      
      if (mounted) context.go('/onboarding');

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnackBar(_getErrorMessage(e.code), AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Ya existe una cuenta con este email';
      case 'weak-password': return 'La contraseña es muy débil';
      case 'invalid-email': return 'El formato del email es inválido';
      default: return 'Ocurrió un error. Inténtalo de nuevo';
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

  void _showLegalDialog(String title, String content) {
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
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF6B5B95).withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Entendido',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6B5B95),
                      fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente suave
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
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (_currentPage > 0) {
                        _previousPage();
                      } else {
                        context.pop();
                      }
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
                  // Indicadores de página
                  if (_currentPage < 2)
                    Row(
                      children: List.generate(3, (index) => Container(
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _currentPage 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                ],
              ),
            ),
          ),
          
          // Contenido principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPage1(),
                    _buildPage2(),
                    _buildPage3(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Elementos visuales (ondas y partículas)
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
  
  // Página 1: Información básica
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          FadeTransition(
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
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Bienvenido a Vito',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Comencemos con lo básico',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 50),
          SlideTransition(
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
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          icon: Icons.person_rounded,
                          label: 'Tu nombre',
                          validator: (value) => 
                            value!.isEmpty ? 'Ingresa tu nombre' : null,
                        ),
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 32),
                        _buildNextButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Página 2: Información personal
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'Un poco más sobre ti',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Esto nos ayuda a personalizar tu experiencia',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withOpacity(0.15),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Column(
                  children: [
                    _buildGenderSelector(),
                    const SizedBox(height: 20),
                    _buildDatePicker(),
                    const SizedBox(height: 32),
                    _buildNextButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Página 3: Contraseña y términos
  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'Protege tu cuenta',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea una contraseña segura',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withOpacity(0.15),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      icon: Icons.lock_rounded,
                      label: 'Contraseña',
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleObscure: () => setState(() => 
                        _obscurePassword = !_obscurePassword
                      ),
                      validator: (value) => 
                        value!.length < 6 
                          ? 'Mínimo 6 caracteres' 
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      icon: Icons.lock_rounded,
                      label: 'Confirmar contraseña',
                      isPassword: true,
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () => setState(() => 
                        _obscureConfirmPassword = !_obscureConfirmPassword
                      ),
                      validator: (value) => 
                        value != _passwordController.text 
                          ? 'Las contraseñas no coinciden' 
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _buildTermsCheckbox(),
                    const SizedBox(height: 32),
                    _buildSignUpButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Widgets auxiliares
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
  }) {
    final bool isFocused = focusNode.hasFocus;
    final bool hasText = controller.text.isNotEmpty;

    // CAMBIO CLAVE 1: Envolvemos todo en una Columna para poner el label arriba
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CAMBIO CLAVE 2: Este es nuestro nuevo label externo, animado
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
        
        // El campo de texto, ahora sin `labelText` y con `hintText`
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
                obscureText: obscureText,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
                decoration: InputDecoration(
                  // CAMBIO CLAVE 3: Usamos hintText que desaparece cuando el label de arriba aparece
                  hintText: isFocused || hasText ? '' : label,
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16, // Mismo tamaño que el texto
                    fontWeight: FontWeight.w300,
                  ),
                  // Se eliminó labelText y labelStyle de aquí
                  prefixIcon: Icon(
                    icon,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  suffixIcon: isPassword
                      ? IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            onToggleObscure?.call();
                          },
                          icon: Icon(
                            obscureText 
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
                    borderSide: BorderSide(
                      color: Colors.red.shade300,
                      width: 1,
                    ),
                  ),
                  errorStyle: GoogleFonts.poppins(
                    color: Colors.red.shade200,
                    fontSize: 12,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                validator: validator,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildGenderSelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: 'Género',
              labelStyle: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
              prefixIcon: Icon(
                Icons.people_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
            dropdownColor: const Color(0xFF6B5B95),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
            items: ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir']
                .map((label) => DropdownMenuItem(
                  value: label,
                  child: Text(label),
                ))
                .toList(),
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _selectedGender = value);
            },
            validator: (value) => value == null ? 'Selecciona una opción' : null,
          ),
        ),
      ),
    );
  }
  
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Fecha de nacimiento',
                labelStyle: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
                prefixIcon: Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              child: Text(
                _selectedBirthDate == null 
                    ? '' 
                    : DateFormat('dd/MM/yyyy').format(_selectedBirthDate!),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            unselectedWidgetColor: Colors.white.withOpacity(0.5),
          ),
          child: Checkbox(
            value: _termsAccepted,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _termsAccepted = value!);
            },
            checkColor: const Color(0xFF6B5B95),
            activeColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w300,
              ),
              children: [
                const TextSpan(text: 'He leído y acepto los '),
                TextSpan(
                  text: 'Términos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withOpacity(0.5),
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () => 
                    _showLegalDialog('Términos de Uso', _termsText),
                ),
                const TextSpan(text: ' y '),
                TextSpan(
                  text: 'Privacidad',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withOpacity(0.5),
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () => 
                    _showLegalDialog('Política de Privacidad', _privacyText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildNextButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      child: AnimatedBuilder(
        animation: _breathingController,
        builder: (context, child) {
          return ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.9 + _breathingController.value * 0.1),
              foregroundColor: const Color(0xFF6B5B95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 5 + _breathingController.value * 3,
              shadowColor: Colors.white.withOpacity(0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continuar',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSignUpButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      child: AnimatedBuilder(
        animation: _breathingController,
        builder: (context, child) {
          return ElevatedButton(
            onPressed: (_isLoading || !_termsAccepted) ? null : _signUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.9 + _breathingController.value * 0.1),
              foregroundColor: const Color(0xFF6B5B95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: (_isLoading || !_termsAccepted) ? 0 : 5 + _breathingController.value * 3,
              shadowColor: Colors.white.withOpacity(0.3),
              disabledBackgroundColor: Colors.white.withOpacity(0.3),
              disabledForegroundColor: Colors.white.withOpacity(0.7),
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
                    'Crear cuenta',
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
  
  // Textos legales
  static const String _termsText = '''Última actualización: 26 de junio de 2025

¡Hola! Soy Iván, el creador de Vito. Te agradezco por usar mi aplicación. Para que todo esté claro entre nosotros, aquí te explico las reglas del juego.

Al usar Vito, aceptas estos términos. Si no estás de acuerdo, te pido que no uses la app.

1. Tu Cuenta
Para usar Vito, necesitas una cuenta. Te pido que la información que me das sea real y la mantengas actualizada. Tú eres responsable de mantener tu contraseña segura y de lo que se haga con tu cuenta.

2. Propiedad Intelectual
Todo el contenido, diseño y funcionalidades de Vito son mi creación y propiedad. Por favor, respeta mi trabajo.

3. Terminación de la Cuenta
Me reservo el derecho de suspender o eliminar tu cuenta si no cumples con estos términos, para proteger a la comunidad y la integridad de la app.

4. Límite de Responsabilidad
Pongo todo mi esfuerzo para que Vito funcione de maravilla, pero como soy una sola persona, no puedo garantizar que sea perfecta. Usas la app bajo tu propio riesgo y no soy responsable por problemas como la pérdida de datos.

5. Cambios
Puede que actualice estos términos en el futuro si la app crece o cambia. Si eso pasa, te lo haré saber.

¡Gracias por leer! Si tienes cualquier duda, no dudes en escribirme.''';
  
  static const String _privacyText = '''Última actualización: 26 de junio de 2025

¡Hola! Soy Iván. Tu privacidad es súper importante para mí. En este documento te explico de forma clara y sencilla qué datos recojo y para qué los uso.

1. ¿Qué información guardo?
Para que puedas usar Vito, necesito algunos datos. No te pediré nada que no sea necesario. Esto es lo que guardo:
- Tu nombre y correo electrónico, para crear tu cuenta.
- Tu fecha de nacimiento y género (si decides compartirlos), para futuras funcionalidades de personalización.
- La información de tus hábitos (cuáles creas, cuándo los completas, etc.). Esto es el corazón de la app y es fundamental para que puedas ver tu progreso.

2. ¿Para qué uso tu información?
Uso tus datos exclusivamente para:
- Que la aplicación funcione correctamente y puedas ver tu progreso.
- Mejorar la aplicación y crear nuevas funcionalidades que te sirvan.
- Poder ayudarte si tienes algún problema técnico.
- Jamás venderé tus datos a terceros. ¡Promesa!

3. ¿Cómo protejo tus datos?
Uso los servicios de Firebase (de Google), que son líderes en seguridad, para almacenar tu información. Hago todo lo posible para mantener tus datos seguros, pero recuerda que en internet nada es 100% infalible.

4. Tus derechos
Tú tienes el control. Desde la pantalla de tu perfil, puedes ver y eliminar tu cuenta cuando quieras. Si eliminas tu cuenta, todos tus datos se borrarán permanentemente.

Si tienes alguna pregunta sobre cómo manejo tu privacidad, ¡escríbeme! La transparencia es lo primero.

¡Gracias por usar Vito!''';
}

// Custom Painter para las ondas (reutilizado del login)
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