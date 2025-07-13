// lib/services/vertex_ai_service.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import '../models/chat_message.dart' as app;

/// Servicio para interactuar con la API de Vertex AI de Google Cloud.
/// Utiliza un modelo de IA (Gemini 1.5 Flash) con un prompt de sistema unificado
/// para gestionar todas las conversaciones de chat de forma contextual y coherente.
class VertexAIService {
  // --- Configuración del Servicio ---
  static const String _projectId = 'vito-app-463903';
  static const String _location = 'us-central1';
  static const String _model = 'gemini-2.0-flash-lite';
  static AutoRefreshingAuthClient? _authClient;

  // --- Personalidad Central de Vito (Unificada y Mejorada) ---
  static const String vitoCorePersonaPrompt = '''
  Eres 'Vito', un coach de bienestar integral. Tu nombre viene de "vida". Tu propósito es ser un guía empático, cálido y motivador. Te comunicas en español de forma natural y cercana.

  TUS PRINCIPIOS DE CONVERSACIÓN SON:
  1.  **Rol y Límites Claros:** Eres un compañero de hábitos y un animador, NO un terapeuta. Si el usuario expresa una crisis de salud mental (pensamientos de autolesión, etc.), tu ÚNICA respuesta debe ser: "Aprecio tu confianza al compartir esto. Suena como un momento muy difícil, y por eso mismo, lo más importante es que hables con un profesional que pueda darte el apoyo que mereces. Por favor, busca ayuda profesional. No estás solo/a en esto."
  2.  **Manejo de Saludos:** Si el usuario te saluda ("Hola", "¿Cómo estás?"), responde de forma cálida, breve y variada. Invítale siempre a conversar. Ejemplo: "¡Hola! Qué bueno verte. ¿Qué tienes en mente hoy?".
  3.  **Escucha Activa (Venting):** Si el usuario solo se está desahogando, tu rol es escuchar. Valida sus sentimientos ("Entiendo que eso sea frustrante", "Suena muy pesado") y haz preguntas abiertas ("¿Qué es lo que más te pesa de eso?"). NO intentes solucionar el problema de inmediato.
  4.  **Dar Consejos (Seeking Advice):** Si el usuario pide consejo, basa tus respuestas en la ciencia del comportamiento, pero de forma simple. Promueve los micro-hábitos (pasos ridículamente pequeños) y explica el "porqué" de forma sencilla.
  5.  **Memoria y Contexto:** Utiliza el contexto que se te proporciona sobre el usuario de forma sutil para personalizar tus respuestas. NO lo recites. En lugar de "Veo que tu ánimo hoy es triste", di "Veo que hoy es un día un poco gris. A veces pasa. Estoy aquí para escucharte si lo necesitas.".

  Tu tono es siempre paciente y optimista, usando emojis con moderación (🌱, ✨, 💪, 😊).
  ''';

  // --- Inicialización ---
  static Future<void> initialize() async {
    if (_authClient != null) return;
    try {
      final credentialsJson = await rootBundle.loadString('assets/service-account-key.json');
      final credentials = ServiceAccountCredentials.fromJson(json.decode(credentialsJson));
      _authClient = await clientViaServiceAccount(credentials, ['https://www.googleapis.com/auth/cloud-platform']);
      print('✅ Vertex AI Service inicializado.');
    } catch (e) {
      print('🚨 Error inicializando Vertex AI: $e');
      throw Exception('Falló la inicialización de Vertex AI Service: $e');
    }
  }

  // =======================================================================
  // FUNCIÓN PRINCIPAL PARA EL CHAT CONVERSACIONAL
  // =======================================================================
  static Future<String> getSmartResponse({
    required List<app.ChatMessage> conversationHistory,
    required Map<String, dynamic> userContext,
  }) async {
    final contents = _prepareConversationHistory(conversationHistory);
    // Añadimos el contexto del usuario al último mensaje para que la IA lo "vea"
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      final lastUserPrompt = contents.last['parts'][0]['text'];
      final formattedContext = _formatUserContext(userContext);
      contents.last['parts'][0]['text'] = '$formattedContext\n\nConsulta del usuario: "$lastUserPrompt"';
    }
    return _generateContent(vitoCorePersonaPrompt, contents);
  }

  static Future<String> generateUtilityText({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final contents = [{'role': 'user', 'parts': [{'text': userPrompt}]}];
    // Usamos el motor principal, pero con un systemPrompt personalizado
    return _generateContent(systemPrompt, contents);
  }

  // =======================================================================
  // FUNCIONES SECUNDARIAS (NO SON DE CHAT EN VIVO)
  // =======================================================================

  /// **Analiza texto para crear o modificar un hábito (devuelve JSON).**
  static Future<String> parseHabitFromText({
    required String userInput,
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? existingHabitData,
  }) async {
    final systemPrompt = '''
    Eres Vito, un asistente experto en la creación y modificación de hábitos. Tu única función es analizar el texto del usuario y el historial para extraer o modificar los detalles de un hábito.
    Tu respuesta DEBE SER SIEMPRE un único objeto JSON válido, sin texto explicativo adicional.

    ## LÓGICA DE CONVERSACIÓN Y RESPUESTA JSON
    1.  **Información Incompleta:** Si faltan datos clave, pregunta de forma amable. Output: `{"status": "incomplete", "question": "¡Excelente meta! ¿A qué hora te gustaría hacerlo?"}`
    2.  **Eliminación:** Si el usuario pide eliminar, responde con `{"status": "delete_confirmation"}`.
    3.  **Completo:** Cuando tengas todos los datos, responde con `{"status": "complete", "data": {...}}`.
    ''';
    final List<Map<String, dynamic>> chatHistory = List.from(conversationHistory ?? []);
    chatHistory.add({
      'role': 'user',
      'parts': [{'text': 'CONTEXTO DEL HÁBITO EXISTENTE (si aplica): ${jsonEncode(existingHabitData)}\n\nINPUT DEL USUARIO: "$userInput"'}]
    });
    try {
        return await _generateContent(systemPrompt, chatHistory, forceJsonOutput: true);
    } catch (e) {
        return _getErrorJson("Lo siento, tuve un problema para procesar tu solicitud. ¿Podemos intentarlo de nuevo?");
    }
  }

  /// **Genera una rutina de 3-4 hábitos (devuelve JSON).**
  static Future<String> getRoutine({required String userGoal, required Map<String, dynamic> userContext}) async {
    final systemPrompt = '''
      Eres un experto en bienestar. Tu tarea es crear una rutina de 3 a 4 hábitos basada en el objetivo de un usuario.
      Tu respuesta DEBE ser únicamente un objeto JSON válido, sin texto adicional.
      ESTRUCTURA JSON: {"habits": [{"name": "Nombre Hábito 1", "category": "categoria"}, ...]}
      ''';
    final userContextPrompt = 'Crea una rutina para el siguiente objetivo: "$userGoal".\nContexto del usuario: ${jsonEncode(userContext)}';
    final contents = [{'role': 'user', 'parts': [{'text': userContextPrompt}]}];
    return _generateContent(systemPrompt, contents, forceJsonOutput: true);
  }

  /// **Genera sugerencias de hábitos para el onboarding (devuelve JSON).**
  static Future<String> getOnboardingSuggestions(Map<String, dynamic> userProfile) async {
    final systemPrompt = '''
      Eres un experto en bienestar. Analiza el perfil de un nuevo usuario y genera 5 hábitos iniciales.
      Tu respuesta DEBE ser únicamente un objeto JSON válido, sin texto adicional.
      ESTRUCTURA JSON: {"habits": [{"name": "Nombre Hábito 1", "category": "categoria"}, ...]}
      ''';
    final userContextPrompt = 'Analiza el siguiente perfil y genera los hábitos:\n${jsonEncode(userProfile)}';
    final contents = [{'role': 'user', 'parts': [{'text': userContextPrompt}]}];
    return _generateContent(systemPrompt, contents, forceJsonOutput: true);
  }

  /// **Resume una conversación para guardarla como memoria.**
  static Future<String> summarizeConversation({ required List<app.ChatMessage> conversationHistory }) async {
    final systemPrompt = '''
      Eres un analizador de conversaciones. Tu tarea es leer un chat y crear un resumen muy breve (máximo 2 frases) para que el coach Vito pueda recordarlo en el futuro.
      Enfócate en el estado emocional del usuario, el problema clave y cualquier plan acordado.
      Responde solo con el texto del resumen.
      ''';
    final conversationText = conversationHistory.map((m) => "${m.type == app.MessageType.user ? 'USER' : 'VITO'}: ${m.text}").join('\n\n');
    return _generateContent(systemPrompt, [{'role': 'user', 'parts': [{'text': conversationText}]}]);
  }

  // =======================================================================
  // MOTOR PRINCIPAL DE LA API Y HELPERS PRIVADOS
  // =======================================================================

  static Future<String> _generateContent(String systemPrompt, List<Map<String, dynamic>> contents, {bool forceJsonOutput = false}) async {
    if (_authClient == null) await initialize();
    
    final endpoint = 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/$_model:generateContent';
    
    final requestBody = {
      'systemInstruction': {'parts': [{'text': systemPrompt}]},
      'contents': contents,
      'generationConfig': {
        // MEJORA: Temperatura ajustada a 0.75 para un balance ideal
        // entre creatividad y consistencia para un coach.
        'temperature': 0.75,
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
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        // MEJORA: Manejo de respuesta vacía de forma más segura.
        // Devuelve un mensaje amigable en lugar de un JSON de error
        // para no romper las funciones que esperan un string.
        return text ?? "Lo siento, tuve un pequeño problema al pensar mi respuesta. ¿Podemos intentarlo de nuevo? 🌱";
      }

      print('🚨 Error en Vertex AI - Status: ${response.statusCode}, Body: ${response.body}');
      return _getErrorJson('No se recibió una respuesta válida del servidor (Código: ${response.statusCode})');
    } catch (e) {
      print('🚨 Excepción al llamar a Vertex AI: $e');
      return _getErrorJson("Lo siento, ocurrió un error al contactar al asistente de IA.");
    }
  }

  static List<Map<String, dynamic>> _prepareConversationHistory(List<app.ChatMessage> history) {
    return history.map((msg) => {
      'role': msg.type == app.MessageType.user ? 'user' : 'model',
      'parts': [{'text': msg.text}]
    }).toList();
  }

  /// MEJORA: Contexto enriquecido para darle al modelo una visión más completa
  /// del estado actual del usuario, incluyendo el progreso diario.
  static String _formatUserContext(Map<String, dynamic> userContext) {
    if (userContext.isEmpty) return "";
    
    final habitsList = userContext['habits'] as List<dynamic>? ?? [];
    final habitsString = habitsList.isNotEmpty
      ? habitsList.map((h) {
          final streak = h['streak'] > 0 ? " (racha de ${h['streak']} días)" : "";
          // Re-incorporamos este dato crucial para el contexto
          final completed = h['isCompletedToday'] == true ? " - ¡Completado hoy! ✅" : "";
          return "- ${h['name']}${streak}${completed}";
        }).join('\n')
      : "El usuario aún no ha añadido hábitos.";

    final lastSummary = userContext['lastConversationSummary'] ?? 'Ninguna conversación previa.';
    
    // Añadimos un resumen del progreso diario
    final completedCount = userContext['completedToday'] ?? 0;
    final totalCount = userContext['totalHabits'] ?? habitsList.length;

    return '''
--- CONTEXTO CLAVE DEL USUARIO (para tu conocimiento interno, no lo recites) ---
- Nombre: ${userContext['userName'] ?? 'Usuario'}
- Resumen de la última conversación: $lastSummary
- Estado de ánimo hoy: ${userContext['moodToday'] ?? 'No registrado'}
- Progreso de hoy: $completedCount de $totalCount hábitos completados.
- Hábitos actuales:
$habitsString
---
''';
  }

  static String _getErrorJson(String message) {
    return jsonEncode({"status": "error", "message": message});
  }
}