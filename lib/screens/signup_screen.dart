import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate() || !_termsAccepted) return;

    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona tu fecha de nacimiento'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // <<< MEJORA >>> Se añade la bandera para el onboarding
        await FirestoreService.createOrUpdateUserProfile(
          userId: userCredential.user!.uid,
          displayName: _nameController.text.trim(),
          additionalData: {
            'gender': _selectedGender,
            'birthDate': _selectedBirthDate,
            'termsAcceptedOn': Timestamp.now(),
            'onboardingCompleted': false, // Se marca que el usuario es nuevo
          },
        );
      }
      
      // La navegación a /onboarding ahora será manejada por la lógica global
      // en main.dart, que detectará que el usuario es nuevo.
      // No es necesario un context.go() aquí, pero lo dejamos por si acaso.
      if (mounted) context.go('/onboarding');

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getErrorMessage(e.code)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Ya existe una cuenta con este email.';
      case 'weak-password': return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'invalid-email': return 'El formato del email es inválido.';
      default: return 'Ocurrió un error. Inténtalo de nuevo.';
    }
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(child: Text(content, style: GoogleFonts.inter())),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const String termsAndConditionsText = '''Última actualización: 26 de junio de 2025

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
    const String privacyPolicyText = '''Última actualización: 26 de junio de 2025

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
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
                  const SizedBox(height: kToolbarHeight),
                  Text(
                    'Crea tu Cuenta',
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completa tus datos para empezar',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: _nameController,
                    decoration: _buildInputDecoration('Nombre de Usuario', Icons.person_outline),
                    validator: (value) => value!.isEmpty ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration('Correo Electrónico', Icons.email_outlined),
                    validator: (value) => value!.isEmpty || !value.contains('@') ? 'Ingresa un correo válido' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: _buildInputDecoration('Género', Icons.wc_outlined),
                    items: ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir']
                        .map((label) => DropdownMenuItem(child: Text(label), value: label))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedGender = value),
                     validator: (value) => value == null ? 'Selecciona una opción' : null,
                  ),
                   const SizedBox(height: 20),
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _selectedBirthDate == null ? '' : DateFormat('dd/MM/yyyy').format(_selectedBirthDate!)
                    ),
                    decoration: _buildInputDecoration('Fecha de Nacimiento', Icons.calendar_today_outlined),
                    onTap: () => _selectDate(context),
                     validator: (value) => _selectedBirthDate == null ? 'Selecciona tu fecha de nacimiento' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _buildInputDecoration('Contraseña', Icons.lock_outline, isPassword: true),
                    validator: (value) => value!.length < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    decoration: _buildInputDecoration('Confirmar Contraseña', Icons.lock_outline),
                    validator: (value) => value != _passwordController.text ? 'Las contraseñas no coinciden' : null,
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (value) => setState(() => _termsAccepted = value!),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                            children: [
                              const TextSpan(text: 'He leído y acepto los '),
                              TextSpan(
                                text: 'Términos de Uso',
                                style: const TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = () => _showLegalDialog('Términos de Uso', termsAndConditionsText),
                              ),
                              const TextSpan(text: ' y la '),
                              TextSpan(
                                text: 'Política de Privacidad',
                                style: const TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = () => _showLegalDialog('Política de Privacidad', privacyPolicyText),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _termsAccepted ? _signUp : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              disabledBackgroundColor: Colors.grey.shade300,
                            ),
                            child: const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isPassword = false}) {
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
