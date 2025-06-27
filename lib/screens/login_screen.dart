import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // El router en main.dart se encargará de redirigir a /home
    } on FirebaseAuthException catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getErrorMessage(e.code)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    // (Esta función se mantiene igual)
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un correo válido para restablecer la contraseña.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se ha enviado un enlace de recuperación a tu correo.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getErrorMessage(e.code)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'No existe una cuenta con este email.';
      case 'wrong-password': return 'Contraseña incorrecta.';
      case 'invalid-email': return 'El formato del email es inválido.';
      default: return 'Ocurrió un error. Inténtalo de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gradientStart, AppColors.backgroundLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.spa_outlined, size: 80, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Bienvenido a Vito',
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicia sesión para continuar',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration('Correo Electrónico', Icons.email_outlined),
                    validator: (value) => value!.isEmpty || !value.contains('@') ? 'Ingresa un correo válido' : null,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _buildInputDecoration('Contraseña', Icons.lock_outline, isPassword: true),
                    validator: (value) => value!.length < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null,
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                  
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("¿No tienes una cuenta?"),
                      TextButton(
                        // --- CAMBIO AQUÍ ---
                        // Ahora navega a la nueva pantalla de registro.
                        onPressed: () => context.push('/signup'),
                        child: const Text('Regístrate'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isPassword = false}) {
    // (Esta función se mantiene igual)
     return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.8)),
      suffixIcon: isPassword 
        ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ) 
        : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
       enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
