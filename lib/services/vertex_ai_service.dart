import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/chat_message.dart';

class VertexAIService {
  static const String _projectId = 'vito-app-463903';
  static const String _location = 'us-central1';
  static const String _model = 'gemini-2.0-flash-lite';

  static AutoRefreshingAuthClient? _authClient;

  static Future<void> initialize() async {
    // Si ya está inicializado, no hacer nada.
    if (_authClient != null) return;
    try {
      final credentialsJson =
          await rootBundle.loadString('assets/service-account-key.json');
      final credentials =
          ServiceAccountCredentials.fromJson(json.decode(credentialsJson));
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      _authClient = await clientViaServiceAccount(credentials, scopes);
      print('Vertex AI initialized successfully');
    } catch (e) {
      print('Error initializing Vertex AI: $e');
      throw Exception('Failed to initialize Vertex AI Service: $e');
    }
  }

  /// Proporciona consejos y conversación general sobre hábitos.
  static Future<String> getHabitAdvice({
    required List<ChatMessage> conversationHistory,
    required Map<String, dynamic> userContext,
  }) async {
    final systemPrompt = '''
      Eres Vito, un coach de bienestar y hábitos. Eres amable, motivador y directo. Usas emojis de forma natural 😊✨.
      Tus ejes son: Mindfulness 🧘, hábitos saludables 🪴, manejo del estrés 😌, y propósito diario 🎯.
      REGLAS CLAVE:
      1. Usa el contexto del usuario que te proporciono, pero no lo menciones directamente.
      2. Si el usuario no tiene hábitos y pide un plan, pregúntale sobre qué hábito le gustaría trabajar.
      3. Si el usuario parece abrumado, sugiere acciones pequeñas y conscientes.
      4. Responde siempre en el idioma del usuario.
      ''';

    final contents = conversationHistory.map((msg) {
      if (msg.text.contains("Hola! Soy Vito")) return null;
      return {'role': msg.isUser ? 'user' : 'model', 'parts': [{'text': msg.text}]};
    }).whereType<Map<String, dynamic>>().toList();

    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      final lastUserPrompt = contents.last['parts'][0]['text'];
      String contextString = '''
        ---
        Contexto del Usuario (Usa esta información para personalizar tu respuesta):
        - Hábitos actuales: ${userContext['habits']}
        - Estado de ánimo hoy: ${userContext['moodToday']}
        ---
        ''';
      contents.last['parts'][0]['text'] = "$contextString\n\nConsulta del Usuario: $lastUserPrompt";
    }

    return _generateContent(systemPrompt, contents);
  }

  /// Genera sugerencias de hábitos iniciales durante el onboarding.
  static Future<String> getOnboardingSuggestions(Map<String, dynamic> userProfile) async {
    final systemPrompt = '''
      Eres un experto en bienestar. Tu tarea es analizar el perfil de un nuevo usuario y generar 5 hábitos iniciales personalizados.
      REGLAS:
      1. Basa tus sugerencias en los datos proporcionados: 'goals', 'interests', y 'experienceLevel'.
      2. Si 'experienceLevel' es 'beginner', los hábitos deben ser muy simples.
      3. Asigna a cada hábito una categoría válida: 'health', 'mind', 'productivity', 'creativity', 'relationships', 'finance'.
      4. Tu respuesta DEBE ser únicamente un objeto JSON válido, sin texto adicional.
      ESTRUCTURA JSON:
      {
        "habits": [
          { "name": "Nombre del Hábito 1", "category": "categoria_valida" },
          { "name": "Nombre del Hábito 2", "category": "categoria_valida" },
          { "name": "Nombre del Hábito 3", "category": "categoria_valida" },
          { "name": "Nombre del Hábito 4", "category": "categoria_valida" },
          { "name": "Nombre del Hábito 5", "category": "categoria_valida" }
        ]
      }
    ''';
    
    final userContextPrompt = 'Analiza el siguiente perfil y genera los hábitos:\n${jsonEncode(userProfile)}';
    final contents = [{'role': 'user', 'parts': [{'text': userContextPrompt}]}];
    
    return _generateContent(systemPrompt, contents, forceJsonOutput: true);
  }
  
  /// Genera una rutina de hábitos basada en un objetivo del usuario.
  static Future<String> getRoutine({required String userGoal, required Map<String, dynamic> userContext}) async {
    final systemPrompt = '''
      Eres un experto en bienestar. Tu tarea es crear una rutina de 3 a 4 hábitos basada en el objetivo de un usuario.
      REGLAS:
      1. La rutina debe ser coherente y los hábitos deben apoyarse entre sí.
      2. Considera el contexto del usuario para adaptar la dificultad y el enfoque de la rutina.
      3. Asigna a cada hábito una categoría válida: 'health', 'mind', 'productivity', 'creativity', 'relationships', 'finance'.
      4. Tu respuesta DEBE ser únicamente un objeto JSON válido, sin texto adicional.
      ESTRUCTURA JSON:
      {
        "habits": [
          { "name": "Nombre del Hábito 1", "category": "categoria_valida" },
          { "name": "Nombre del Hábito 2", "category": "categoria_valida" },
          { "name": "Nombre del Hábito 3", "category": "categoria_valida" }
        ]
      }
    ''';
    
    final userContextPrompt = 'Crea una rutina para el siguiente objetivo: "$userGoal".\nContexto del usuario: ${jsonEncode(userContext)}';
    final contents = [{'role': 'user', 'parts': [{'text': userContextPrompt}]}];
    
    return _generateContent(systemPrompt, contents, forceJsonOutput: true);
  }

  /// Método base privado para interactuar con la API de Gemini.
  static Future<String> _generateContent(String systemPrompt, List<Map<String, dynamic>> contents, {bool forceJsonOutput = false}) async {
    if (_authClient == null) {
      await initialize();
    }
    
    final endpoint = 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/$_model:generateContent';

    final requestBody = {
      'systemInstruction': {
        'parts': [{'text': systemPrompt}]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.8,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 1024,
        if (forceJsonOutput) 'responseMimeType': 'application/json',
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'}
      ]
    };

    try {
      final response = await _authClient!.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
            return content['parts'][0]['text'] ?? "No se pudo obtener una respuesta del asistente.";
          }
        }
      }
      
      print('Vertex AI response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      throw Exception('Error: No se recibió una respuesta válida del servidor (Código: ${response.statusCode})');

    } catch (e) {
      print('Error calling Vertex AI: $e');
      throw Exception("Lo siento, ocurrió un error al contactar al asistente de IA. Por favor, intenta nuevamente.");
    }
  }
}
// End of file