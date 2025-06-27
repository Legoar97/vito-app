import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/chat_message.dart';

class VertexAIService {
  static const String _projectId = 'vito-app-463903';
  static const String _location = 'us-central1';
  static const String _model = 'gemini-2.0-flash-lite'; 
  
  static AutoRefreshingAuthClient? _authClient;

  // El método de inicialización no cambia
  static Future<void> initialize() async {
    try {
      final credentialsJson = await rootBundle.loadString('assets/service-account-key.json');
      final credentials = ServiceAccountCredentials.fromJson(json.decode(credentialsJson));
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      _authClient = await clientViaServiceAccount(credentials, scopes);
      print('Vertex AI initialized successfully');
    } catch (e) {
      print('Error initializing Vertex AI: $e');
      throw Exception('Failed to initialize Vertex AI Service: $e');
    }
  }

  static Future<String> getHabitAdvice({
    required List<ChatMessage> conversationHistory,
    required Map<String, dynamic> userContext,
  }) async {
    try {
      if (_authClient == null) {
        await initialize();
      }

      final endpoint = 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/$_model:generateContent';

      // Instrucción del sistema para guiar a la IA
      final systemPrompt = '''
      Eres Vito, un coach de bienestar y hábitos especializado en mindfulness, salud mental, autocuidado y calidad de vida. Tu enfoque principal es ayudar a las personas a desarrollar hábitos conscientes y sostenibles que mejoren su día a día. No das consejos genéricos ni abarcas temas fuera de esta área (como negocios, tecnología o relaciones complejas), a menos que estén directamente relacionados con el bienestar personal.

      🎯 TU ROL:
      Eres un guía amable, motivador y directo al grano. Escuchas activamente, haces preguntas poderosas y ofreces respuestas prácticas, breves y empáticas. Usas emojis de forma natural para hacer las respuestas más cálidas y atractivas 😊✨.

      🌱 EJES PRINCIPALES:
      1. Mindfulness y meditación 🧘
      2. Hábitos saludables y sostenibles 🪴
      3. Manejo del estrés y emociones 😌
      4. Rutinas de autocuidado 🛁
      5. Sueño y descanso 💤
      6. Propósito y enfoque diario 🎯

      📌 REGLAS CLAVE:
      1. Siempre mantén el contexto de la conversación actual.
      2. Usa el contexto del usuario que te proporciono, pero NO inventes información.
      3. Si el usuario no tiene hábitos aún (`habits: []`) y te pide crear un plan, NO asumas un hábito. Pregunta cuál le gustaría trabajar, por ejemplo:  
        👉 “¡Perfecto! ¿Sobre qué hábito te gustaría que creemos un plan? 📝”
      4. Si el usuario menciona estar abrumado, estresado o perdido, prioriza sugerencias suaves y conscientes, no planes exigentes.
      5. Si el usuario cambia de idioma, responde automáticamente en ese idioma.
      6. Sé positivo y alentador, pero no exageres ni uses frases vacías. Sé auténtico.

      🧠 EJEMPLO DE RESPUESTAS:
      - “¡Claro! Empezar con solo 5 minutos al día es una gran forma de incorporar la meditación 🧘. ¿Te gustaría que te recuerde una hora para hacerlo?”
      - “Si estás buscando más calma en tu día, podrías comenzar con respiraciones conscientes después de despertar 🌅. ¿Te gustaría una rutina simple para eso?”

      Tu misión es ayudar a los usuarios a reconectar con ellos mismos a través de pequeños cambios diarios 💫.
      ''';


      // Transforma el historial de la app al formato que espera la API de Gemini
      final contents = conversationHistory.map((msg) {
        if (msg.text.contains("Hola! Soy Vito")) {
          return null;
        }
        // Se define explícitamente el tipo del Map para mayor seguridad
        return <String, dynamic>{
          'role': msg.isUser ? 'user' : 'model',
          'parts': <Map<String, String>>[{'text': msg.text}]
        };
      }).whereType<Map<String, dynamic>>().toList(); // Filtra nulos y asegura el tipo

      // <<<--- BLOQUE CORREGIDO PARA EVITAR ERRORES DE TIPO --- >>>
      // Inyecta el contexto del usuario en el último mensaje para que siempre esté actualizado
      if (contents.isNotEmpty) {
        // Se trabaja con una copia tipada para evitar errores
        final Map<String, dynamic> lastContent = contents.last;

        if (lastContent['role'] == 'user') {
          // Se accede a los datos de forma segura con conversiones de tipo (casting)
          final List<dynamic> parts = lastContent['parts'] as List<dynamic>;
          final Map<String, dynamic> firstPart = parts.first as Map<String, dynamic>;
          final String lastUserPrompt = firstPart['text'] as String;

          String contextString = '''
---
Contexto Actual del Usuario (NO lo menciones a menos que sea relevante):
- Hábitos: ${userContext['habits']}
- Tasa de completación hoy: ${userContext['completionRate']}%
- Racha más alta: ${userContext['streak']} días
- Categorías de enfoque: ${userContext['categories']}
---
''';
          // Reemplaza el texto del último mensaje para añadir el contexto
          firstPart['text'] = "$contextString\n\nConsulta del Usuario: $lastUserPrompt";
        }
      }

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
        },
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'}
        ]
      };

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
      
      return "Error: No se recibió una respuesta válida del servidor (Código: ${response.statusCode}).";
    } catch (e) {
      print('Error calling Vertex AI: $e');
      return "Lo siento, ocurrió un error al contactar al asistente de IA. Por favor, intenta nuevamente.";
    }
  }
}
