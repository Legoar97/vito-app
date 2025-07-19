// lib/services/mood_ai_service.dart

import 'vertex_ai_service.dart';
import '../models/chat_message.dart' as app; // Necesario para simular la conversación

/// Servicio que utiliza IA para generar respuestas y prompts
/// relacionados con el estado de ánimo del usuario.
class MoodAiService {
  /// Genera una respuesta empática y contextual al estado de ánimo registrado por el usuario.
  static Future<String> generateMoodResponse({
    required String mood,
    required Map<String, dynamic> userContext,
  }) async {
    final simulatedHistory = [
      app.ChatMessage(
        text: 'Acabo de registrar que me siento "$mood".',
        type: app.MessageType.user,
        timestamp: DateTime.now(),
      ),
    ];

    try {
      // --- INICIO DE LA CORRECCIÓN ---

      // 1. Obtenemos la respuesta "cruda" de la IA, que puede contener el marcador [Nombre]
      final rawResponse = await VertexAIService.getSmartResponse(
        conversationHistory: simulatedHistory,
        userContext: userContext,
      );

      // 2. Extraemos el nombre del usuario del contexto.
      //    Usamos un valor de respaldo ('tú') por si el nombre no estuviera disponible.
      final userName = userContext['displayName'] as String? ?? 'tú';
      
      // 3. Obtenemos solo el primer nombre para un saludo más personal.
      final firstName = userName.split(' ').first;

      // 4. Reemplazamos el marcador de posición con el nombre real y devolvemos la respuesta final.
      return rawResponse.replaceAll('[Nombre]', firstName);

      // --- FIN DE LA CORRECCIÓN ---

    } catch (e) {
      print('🚨 Error en generateMoodResponse, usando fallback: $e');
      // La lógica de respaldo no se modifica.
      return _getFallbackResponse(mood);
    }
  }

  /// Genera una pregunta de introspección para el diario del usuario.
  static Future<String> generateJournalPrompt({
    required String mood,
    required Map<String, dynamic> userContext,
  }) async {
    final systemPrompt = '''
      Eres un coach de bienestar experto en mindfulness y escritura terapéutica.
      Tu única tarea es generar una pregunta reflexiva corta (máximo 15 palabras) para alguien que se siente "$mood".
      La pregunta debe invitar a la introspección sin ser invasiva.
      No uses signos de interrogación al inicio.
      Debe ser en español, cálida y abierta.
      Responde únicamente con la pregunta.
      ''';

    final userPrompt = 'Genera la pregunta para el estado de ánimo "$mood".';

    try {
      final response = await VertexAIService.generateUtilityText(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );
      return response.replaceAll('"', ''); // Limpiamos posibles comillas extra
    } catch (e) {
      print('🚨 Error en generateJournalPrompt, usando fallback: $e');
      return _getFallbackJournalPrompt(mood);
    }
  }

  // --- Funciones de Respaldo ---

  static String _getFallbackResponse(String mood) {
    final responses = {
      'Feliz': 'Me alegra mucho que te sientas así. Tu energía positiva es contagiosa. ✨',
      'Tranquilo': 'Qué bueno que encuentres paz en este momento. La calma es un superpoder. 🧘',
      'Emocionado': '¡Tu entusiasmo se siente desde aquí! Aprovecha esa energía increíble. 🔥',
      'Triste': 'Está bien sentirse así a veces. Te envío un abrazo virtual, estoy aquí contigo.',
      'Ansioso': 'Respira conmigo. Inhala... exhala. Un paso a la vez, estamos juntos en esto.',
      'Enojado': 'Tu frustración es válida. ¿Qué tal si la transformamos en algo productivo?',
      'Cansado': 'El descanso también es productivo. Tu cuerpo te está pidiendo lo que necesita. 💧',
      'Confundido': 'La claridad llegará. A veces las mejores respuestas vienen cuando dejamos de buscarlas.',
    };
    return responses[mood] ??
        'Gracias por compartir cómo te sientes. Cada emoción es parte de tu historia. 🌱';
  }

  static String _getFallbackJournalPrompt(String mood) {
    final prompts = {
      'Feliz': '¿Qué momento específico de hoy te hizo sonreír?',
      'Tranquilo': '¿Qué te ayudó a encontrar esta paz interior?',
      'Emocionado': '¿Qué es lo que más esperas de lo que está por venir?',
      'Triste': 'Si tu tristeza pudiera hablar, ¿qué diría?',
      'Ansioso': '¿Cuál es una cosa que sí puedes controlar en este momento?',
      'Enojado': '¿Qué límite importante necesitas establecer ahora mismo?',
      'Cansado': '¿Qué has estado cargando que podrías soltar, aunque sea por un momento?',
      'Confundido': '¿Qué pregunta necesitas hacerte a ti mismo, sin buscar aún la respuesta?',
    };
    return prompts[mood] ?? '¿Qué necesitas expresar en este momento?';
  }
}