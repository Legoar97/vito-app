import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import '../models/chat_message.dart' as app; // Usamos un prefijo para evitar colisiones

class VertexAIService {
  static const String _projectId = 'vito-app-463903';
  static const String _location = 'us-central1';
  // Nota: Considera usar un modelo más avanzado como 'gemini-1.5-flash' o 'gemini-1.5-pro' para el parsing
  // de hábitos, ya que es una tarea compleja. 'gemini-1.0-pro' es un buen punto de partida.
  static const String _model = 'gemini-2.0-flash-lite';

  static AutoRefreshingAuthClient? _authClient;

  static Future<void> initialize() async {
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
// lib/services/vertex_ai_service.dart

// ... (dentro de la clase VertexAIService)

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
  // --- NUEVA FUNCIÓN PARA EL CHAT DE HÁBITOS ---

  /// Analiza el input del usuario para crear o editar un hábito y devuelve un JSON.
  ///
  /// El JSON de respuesta tendrá la siguiente estructura:
  /// - Si falta información: `{"status": "incomplete", "question": "¿Qué días te gustaría hacerlo?"}`
  /// - Si la información está completa: `{"status": "complete", "data": {...}}`
  /// - Si hay un error: `{"status": "error", "message": "No entendí bien."}`
  static Future<String> parseHabitFromText({
    required String userInput,
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? existingHabitData,
  }) async {
    final systemPrompt = '''
      Eres Vito, un asistente experto en la creación de hábitos. Tu única función es analizar el texto de un usuario y la conversación previa para extraer detalles de un hábito. Tu respuesta DEBE SER SIEMPRE un único objeto JSON válido, sin texto adicional.

      REGLAS DE EXTRACCIÓN:
      1.  **Nombre (name):** String. El nombre conciso del hábito. Ej: "Meditar", "Salir a correr", "Ahorrar".
      2.  **Categoría (category):** String. Clasifica el hábito en UNA de las siguientes: 'health', 'mind', 'productivity', 'relationships', 'creativity', 'finance', 'otros'.
      3.  **Días (days):** List<int>. Una lista de números del 1 (Lunes) al 7 (Domingo).
          - "diario", "todos los días" -> [1,2,3,4,5,6,7]
          - "entre semana" -> [1,2,3,4,5]
          - "fines de semana" -> [6,7]
          - "lunes, miércoles y viernes" -> [1,3,5]
      4.  **Hora (time):** String. La hora en formato "HH:mm" (24h).
          - "8 am" -> "08:00"
          - "7:30 pm" -> "19:30"
          - "mañana" -> "08:00"
          - "tarde" -> "15:00"
          - "noche" -> "20:00"
      5.  **Parámetros (parameters):** Map<String, dynamic>. Datos adicionales específicos del hábito.
          - Para ejercicio/meditación: `{"duration": 30}` (en minutos).
          - Para ahorro: `{"amount": 50000, "currency": "COP"}`.
          - Para tomar agua: `{"amount": 2, "unit": "litros"}` o `{"amount": 8, "unit": "vasos"}`.

      LÓGICA DE CONVERSACIÓN Y RESPUESTA JSON:
      1.  **Si el input del usuario es una pregunta o saludo no relacionado a un hábito** (ej. "hola", "¿cómo estás?"), responde con: `{"status": "greeting", "message": "¡Hola! Estoy listo para ayudarte a crear o modificar un hábito. ¿Qué tienes en mente?"}`.
      2.  **Si el input contiene información de un hábito pero faltan datos CLAVE** (nombre, días u hora), responde con: `{"status": "incomplete", "question": "¡Suena genial! Para confirmar, ¿qué días y a qué hora te gustaría hacerlo?"}`. Tu pregunta debe ser específica sobre lo que falta.
      3.  **Si ya tienes nombre, días y hora, pero falta un PARÁMETRO específico** (ej. duración para "correr" o cantidad para "ahorrar"), pregunta por él: `{"status": "incomplete", "question": "Perfecto. ¿Por cuánto tiempo te gustaría correr?"}`.
      4.  **Cuando tengas TODA la información necesaria**, responde con: `{"status": "complete", "data": {"name": "...", "category": "...", ...}}`.
      5.  **Modo Edición:** Si se provee `existingHabitData`, estás en modo edición. El usuario dirá qué quiere cambiar (ej: "cambia la hora a las 9pm"). Tu respuesta debe ser un JSON con `status: "complete"` y en el campo `data` incluye SOLO los campos que han cambiado. Ejemplo: `{"status": "complete", "data": {"time": "21:00"}}`.
      ''';

    final List<Map<String, dynamic>> chatHistory = List.from(conversationHistory ?? []);
    
    // Añadir el último mensaje del usuario con todo el contexto.
    chatHistory.add({
      'role': 'user',
      'parts': [{
        'text': 'CONTEXTO DEL HÁBITO EXISTENTE (si aplica): ${jsonEncode(existingHabitData)}\n\nINPUT DEL USUARIO: "$userInput"'
      }]
    });

    try {
        return await _generateContent(systemPrompt, chatHistory, forceJsonOutput: true);
    } catch (e) {
        // En caso de error de la API, devolver un JSON de error controlado.
        return jsonEncode({
            "status": "error",
            "message": "Lo siento, tuve un problema para procesar tu solicitud. ¿Podemos intentarlo de nuevo?"
        });
    }
  }

  /// Proporciona consejos y conversación general sobre hábitos.
  static Future<String> getHabitAdvice({
    required List<app.ChatMessage> conversationHistory,
    required Map<String, dynamic> userContext,
  }) async {
    final systemPrompt = '''
      Eres Vito, un coach de bienestar y hábitos. Eres amable, motivador y directo. Usas emojis de forma natural 😊✨.
      Tus ejes son: Mindfulness 🧘, hábitos saludables 🪴, manejo del estrés 😌, y propósito diario 🎯.
      REGLAS CLAVE:
      1. Usa el contexto del usuario que te proporciono, pero no lo menciones directamente.
      2. Si el usuario no tiene hábitos y pide un plan, pregúntale sobre qué hábito le gustaría trabajar.
      3. Si el usuario parece abrumado, sugiere acciones pequeñas y conscientes.
      4. Responde siempre en el idioma del usuario (español).
      ''';

    final contents = conversationHistory.map((msg) {
      if (msg.text.contains("Hola! Soy Vito")) return null;
      // Adaptado para el nuevo modelo ChatMessage
      return {'role': msg.type == app.MessageType.user ? 'user' : 'model', 'parts': [{'text': msg.text}]};
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
    // (Este método se mantiene igual, es muy bueno para el onboarding)
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
        'temperature': 0.7, // Un poco menos de temperatura para respuestas más predecibles en JSON
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
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
        // Manejo robusto de la respuesta
        if (data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null && content['parts'] != null && (content['parts'] as List).isNotEmpty) {
            return content['parts'][0]['text'] ?? _getErrorJson("No se pudo obtener una respuesta del asistente.");
          }
        }
      }
      
      print('Vertex AI response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      return _getErrorJson('Error: No se recibió una respuesta válida del servidor (Código: ${response.statusCode})');

    } catch (e) {
      print('Error calling Vertex AI: $e');
      return _getErrorJson("Lo siento, ocurrió un error al contactar al asistente de IA. Por favor, intenta nuevamente.");
    }
  }

  /// Helper para generar un JSON de error estandarizado
  static String _getErrorJson(String message) {
    return jsonEncode({"status": "error", "message": message});
  }
}
