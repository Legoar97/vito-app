// File: lib/services/mood_ai_service.dart
import 'vertex_ai_service.dart';

class MoodAiService {
  static Future<String> generateMoodResponse(String mood, String? previousMoods) async {
    final prompt = '''
Eres Vito, un asistente de bienestar amigable y empático. 
El usuario acaba de registrar que se siente "$mood".

${previousMoods != null ? 'Historial reciente de estados de ánimo: $previousMoods' : ''}

Genera una frase corta, personalizada y reconfortante (máximo 2 líneas) que:
1. Reconozca su estado emocional actual
2. Sea única y no cliché
3. Sea cálida y de apoyo
4. Si es apropiado, sugiera sutilmente una acción positiva
5. Use un tono conversacional y cercano

Importante: NO uses frases genéricas como "todo estará bien" o "mañana será mejor día".
La respuesta debe sentirse personal y genuina.
''';

    try {
      final response = await VertexAIService.generateResponse(prompt);
      return response;
    } catch (e) {
      // Respuestas de respaldo personalizadas por mood
      return _getFallbackResponse(mood);
    }
  }

  static String _getFallbackResponse(String mood) {
    final responses = {
      'Feliz': 'Me alegra mucho que te sientas así. Tu energía positiva es contagiosa.',
      'Tranquilo': 'Qué bueno que encuentres paz en este momento. La calma es un superpoder.',
      'Emocionado': '¡Tu entusiasmo se siente desde aquí! Aprovecha esa energía increíble.',
      'Triste': 'Está bien sentirse así a veces. Estoy aquí contigo.',
      'Ansioso': 'Respira conmigo. Inhala... exhala. Un paso a la vez.',
      'Enojado': 'Tu frustración es válida. ¿Qué tal si la transformamos en algo productivo?',
      'Cansado': 'El descanso también es productivo. Tu cuerpo te está pidiendo lo que necesita.',
      'Confundido': 'La claridad llegará. A veces las mejores respuestas vienen cuando dejamos de buscarlas.',
    };
    
    return responses[mood] ?? 'Gracias por compartir cómo te sientes. Cada emoción es parte de tu historia.';
  }

  static Future<String> generateJournalPrompt(String mood) async {
    final prompt = '''
Genera una pregunta reflexiva corta (máximo 15 palabras) para alguien que se siente "$mood".
La pregunta debe invitar a la introspección sin ser invasiva.
No uses signos de interrogación al inicio.
Hazla en español, cálida y abierta.
''';

    try {
      final response = await VertexAIService.generateResponse(prompt);
      return response;
    } catch (e) {
      return _getFallbackJournalPrompt(mood);
    }
  }

  static String _getFallbackJournalPrompt(String mood) {
    final prompts = {
      'Feliz': '¿Qué momento de hoy te hizo sonreír?',
      'Tranquilo': '¿Qué te ayudó a encontrar esta paz?',
      'Emocionado': '¿Qué es lo que más esperas de lo que viene?',
      'Triste': '¿Hay algo que necesites soltar hoy?',
      'Ansioso': '¿Qué es una cosa que sí puedes controlar ahora?',
      'Enojado': '¿Qué límite necesitas establecer?',
      'Cansado': '¿Qué has estado cargando que podrías dejar ir?',
      'Confundido': '¿Qué pregunta necesitas hacerte?',
    };
    
    return prompts[mood] ?? '¿Qué necesitas expresar en este momento?';
  }
}