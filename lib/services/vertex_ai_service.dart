import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import '../models/chat_message.dart' as app; // Usamos un prefijo para evitar colisiones

class VertexAIService {
  static const String _projectId = 'vito-app-463903';
  static const String _location = 'us-central1';
  static const String _model = 'gemini-2.0-flash-lite'; // Usar gemini-1.5-flash-latest es una buena práctica

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
  
  static Future<String> parseHabitFromText({
    required String userInput,
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? existingHabitData,
  }) async {
    final systemPrompt = '''
      Eres Vito, un asistente experto en la creación de hábitos. Tu única función es analizar el texto de un usuario y la conversación previa para extraer detalles de un hábito. Tu respuesta DEBE SER SIEMPRE un único objeto JSON válido, sin texto adicional.

      REGLAS DE EXTRACCIÓN:
      1.  **Tipo de Hábito (type):** String. Clasifica el hábito en UNO de los siguientes:
          - 'simple': Para hábitos de sí/no. (Ej: "Tender la cama").
          - 'quantifiable': Si el usuario menciona una cantidad medible. (Ej: "Tomar 8 vasos de agua").
          - 'timed': Si el usuario menciona una duración de tiempo. (Ej: "Meditar 10 minutos", "Correr por media hora").
      2.  **Nombre (name):** String. El nombre conciso del hábito.
      3.  **Categoría (category):** String. Una de: 'health', 'mind', 'productivity', 'relationships', 'creativity', 'finance', 'otros'.
      4.  **Días (days):** List<int>. Del 1 (Lunes) al 7 (Domingo).
      5.  **Hora (time):** String. Formato "HH:mm".
      6.  **Valor Objetivo (targetValue):** int.
          - Para 'quantifiable': La cantidad total. (Ej: 8 para vasos, 20 para páginas).
          - Para 'timed': La duración total en MINUTOS. (Ej: 10 para 10 minutos, 30 para media hora).
      7.  **Unidad (unit):** String. (Solo para 'quantifiable'). Ej: "vasos", "páginas", "pasos".

      LÓGICA DE CONVERSACIÓN Y RESPUESTA JSON:
      1.  **MANEJO DE ELIMINACIÓN (MÁXIMA PRIORIDAD):**
          - Si el usuario expresa el deseo de eliminar o borrar el hábito (ej: "elimínalo", "borra este hábito"), responde con `{"status": "delete_confirmation"}`. No necesitas preguntar nada, el front-end se encargará de la confirmación.
      2.  **Si el input del usuario es una pregunta o saludo no relacionado a un hábito** (ej. "hola", "¿cómo estás?"), responde con: `{"status": "greeting", "message": "¡Hola! Estoy listo para ayudarte a crear o modificar un hábito. ¿Qué tienes en mente?"}`.
      3.  **Si faltan datos CLAVE** (nombre, días, hora, o el `targetValue` para tipos `quantifiable` o `timed`), pregunta por ellos.
          - Usuario: "Quiero tomar más agua" -> IA: `{"status": "incomplete", "question": "¡Gran idea! ¿Cuántos vasos de agua te gustaría tomar al día y a qué hora quieres empezar?"}`
          - Usuario: "Correr los lunes" -> IA: `{"status": "incomplete", "question": "Perfecto. ¿Por cuánto tiempo te gustaría correr y a qué hora?"}`
      4.  **Si ya tienes nombre, días y hora, pero falta un PARÁMETRO específico** (ej. duración para "correr" o cantidad para "ahorrar"), pregunta por él: `{"status": "incomplete", "question": "Perfecto. ¿Por cuánto tiempo te gustaría correr?"}`.
      5.  **Cuando tengas TODA la información necesaria**, responde con: `{"status": "complete", "data": {"name": "...", "category": "...", ...}}`.
      6.  **Modo Edición:** Si se provee `existingHabitData`, estás en modo edición. El usuario dirá qué quiere cambiar (ej: "cambia la hora a las 9pm"). Tu respuesta debe ser un JSON con `status: "complete"` y en el campo `data` incluye SOLO los campos que han cambiado. Ejemplo: `{"status": "complete", "data": {"time": "21:00"}}`.
      7.  **MANEJO DE ELIMINACIÓN (REGLA DE MÁXIMA PRIORIDAD):**
      - Si el usuario pide eliminar el hábito (ej: "elimínalo", "borra este hábito" o "eliminar"), DEBES pedir confirmación. Responde con `status: "delete_confirmation"` y una pregunta. Ejemplo: `{"status": "delete_confirmation", "question": "Entendido. ¿Estás seguro de que quieres eliminar el hábito '**Meditar**'? Esta acción no se puede deshacer."}`.
      - Si el usuario confirma la eliminación (ej: "si", "Sí", "si, estoy seguro", "Sep", "Yep", "confirmo") DESPUÉS de tu pregunta de confirmación, responde con `status: "delete_confirmed"`. Ejemplo: `{"status": "delete_confirmed", "message": "De acuerdo, procedo a eliminarlo."}`.
      - Si el usuario dice "no" o "no estoy seguro", responde con `status: "delete_cancelled"` y un mensaje amable. Ejemplo: `{"status": "delete_cancelled", "message": "No hay problema, el hábito no se eliminará."}`.
      ''';


    final List<Map<String, dynamic>> chatHistory = List.from(conversationHistory ?? []);
    
    chatHistory.add({
      'role': 'user',
      'parts': [{
        'text': 'CONTEXTO DEL HÁBITO EXISTENTE (si aplica): ${jsonEncode(existingHabitData)}\n\nINPUT DEL USUARIO: "$userInput"'
      }]
    });

    try {
        return await _generateContent(systemPrompt, chatHistory, forceJsonOutput: true);
    } catch (e) {
        return jsonEncode({
            "status": "error",
            "message": "Lo siento, tuve un problema para procesar tu solicitud. ¿Podemos intentarlo de nuevo?"
        });
    }
  }

  static Future<Map<String, String>> classifyIntentAndSentiment({
    required String userMessage,
    required List<app.ChatMessage> conversationHistory,
  }) async {
    final historySnippet = conversationHistory.length > 4
        ? conversationHistory.sublist(conversationHistory.length - 4)
        : conversationHistory;

    final historyText = historySnippet.map((m) => "${m.type == app.MessageType.user ? 'USER' : 'VITO'}: ${m.text}").join('\n');

    final systemPrompt = '''
      Tu única tarea es analizar el ÚLTIMO MENSAJE del usuario y clasificar su intención y sentimiento.
      Responde ÚNICAMENTE con un objeto JSON válido. No añadas explicaciones.

      Intenciones posibles:
      - "greeting": El usuario está diciendo un saludo simple sin carga emocional. (Ej: "Hola", "Buenas", "¿Qué tal?"). **ESTA TIENE ALTA PRIORIDAD PARA MENSAJES SIMPLES.**
      - "seeking_advice": El usuario quiere consejos, un plan, o ayuda para sus hábitos.
      - "venting": El usuario necesita desahogarse o expresar una emoción negativa.
      - "crisis": El usuario expresa ideas de autolesión o peligro inminente.
      - "general_chat": Conversación casual que no es un simple saludo.

      Sentimientos posibles:
      - "positive", "negative", "neutral", "mixed".

      Ejemplo de respuesta: {"intent": "greeting", "sentiment": "neutral"}
    ''';

    final prompt = '''
      Historial de conversación reciente:
      $historyText

      ---
      ÚLTIMO MENSAJE DEL USUARIO A CLASIFICAR:
      "$userMessage"
      ---

      JSON de clasificación:
    ''';
    
    final response = await _generateContent(systemPrompt, [{'role': 'user', 'parts': [{'text': prompt}]}], forceJsonOutput: true);

    try {
      final decodedResponse = json.decode(response);
      return Map<String, String>.from(decodedResponse);
    } catch (e) {
      return {'intent': 'seeking_advice', 'sentiment': 'neutral'};
    }
  }

  static String _formatUserContext(Map<String, dynamic> userContext) {
    if (userContext.isEmpty) {
      return "No hay contexto de usuario disponible.";
    }

    final habitsList = userContext['habits'] as List<dynamic>? ?? [];
    final habitsString = habitsList.isNotEmpty
      ? habitsList.map((h) {
          final streak = h['streak'] > 0 ? " (racha de ${h['streak']} días)" : "";
          final completed = h['isCompletedToday'] ? " - ¡Completado hoy! ✅" : "";
          return "- ${h['name']}${streak}${completed}";
        }).join('\n')
      : "El usuario aún no ha añadido hábitos.";

    final lastSummary = userContext['lastConversationSummary'] ?? 'Ninguna conversación previa.';

    return '''
--- CONTEXTO CLAVE DEL USUARIO (para tu conocimiento interno) ---
- Nombre del usuario: ${userContext['userName'] ?? 'Usuario'}
- Resumen de nuestra última conversación (Memoria): $lastSummary
- Estado de ánimo registrado hoy: ${userContext['moodToday'] ?? 'No registrado'}
- Resumen de hábitos actuales:
${habitsString}
- Hábitos completados hoy: ${userContext['completedToday']} de ${userContext['totalHabits']}
---
''';
  }

  static Future<String> getHabitAdvice({
    required List<app.ChatMessage> conversationHistory,
    required Map<String, dynamic> userContext,
  }) async {
    final systemPrompt = '''
    Eres Vito, un coach de bienestar integral. Tu personalidad es una mezcla de un amigo sabio y un entrenador motivador. Eres empático, directo y usas un lenguaje positivo y accionable.

    PRINCIPIOS FUNDAMENTALES DE VITO:

    1.  **LA TRANSICIÓN EMPÁTICA (REGLA DE ORO #1):** Si el usuario viene de un estado emocional negativo (tristeza, frustración) y te pide un consejo ("¿qué hago?"), tu PRIMERA tarea es RECONOCER Y VALIDAR ese estado emocional ANTES de proponer una solución. La motivación debe nacer de la empatía.
        -   **EJEMPLO CLAVE:**
            -   Usuario (triste): "No sé qué hacer."
            -   RESPUESTA MALA (amnesia emocional): "¡Genial que quieras hacer algo! ¡Vamos a probar esto!"
            -   **RESPUESTA EXCELENTE (transición empática):** "Es totalmente normal sentirse un poco perdido cuando uno se siente así. El simple hecho de buscar un siguiente paso es muy valiente. ✨ Dado que te sientes agobiado, ¿qué te parece si empezamos con algo que no requiera mucha energía, solo para generar un pequeño impulso positivo?"

    2.  **MEMORIA CONTEXTUAL:** Basa SIEMPRE tu respuesta en el HISTORIAL COMPLETO y el CONTEXTO DEL USUARIO. No ofrezcas una receta de ensalada si el usuario dijo que odia el atún.

    3.  **TONO ADAPTATIVO:** No asumas felicidad. Interpreta una petición de ayuda como una señal de insatisfacción, no de alegría. Tu tono debe ser de apoyo y luego, gradualmente, motivador.

    4.  **CONSEJOS PEQUEÑOS Y ACCIONABLES:** Propón siempre el siguiente paso más pequeño y manejable. "Ponte las zapatillas 5 minutos" es mejor que "Sal a correr 5km".

    5.  **SÉ PROACTIVO, HAZ PREGUNTAS:** No te limites a responder. Invita a la reflexión o al compromiso. "¿Qué te parece si intentamos eso mañana? ¿Cuál crees que sería el mayor obstáculo?".

    6.  **USA EL CONTEXTO, NO LO RECITE:** Integra la información de forma natural. NO digas "Veo que tu hábito es...". Di "¡Felicidades por esos 3 días de meditación! ¿Cómo podemos usar esa energía...?".

    7.  **SIEMPRE EN ESPAÑOL y SIN SALUDOS REPETITIVOS.**

    MAL EJEMPLO (Robótico): "Ok. Para tu hábito de 'leer', te sugiero leer 10 páginas."
    BUEN EJEMPLO (Vito): "¡Genial! Retomar la lectura es un gran objetivo. ¿Qué tal si empezamos con algo súper simple? Solo una página esta noche. La que sea. ¿Te animas a probarlo? 😊"
    ''';

    final contents = conversationHistory.map((msg) {
      if (msg.text.contains("Hola! Soy Vito")) return null;
      return {'role': msg.type == app.MessageType.user ? 'user' : 'model', 'parts': [{'text': msg.text}]};
    }).whereType<Map<String, dynamic>>().toList();

    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      final lastUserPrompt = contents.last['parts'][0]['text'];
      final formattedContext = _formatUserContext(userContext);

      String finalPromptText = '''
        $formattedContext

        Consulta del Usuario: $lastUserPrompt
        ''';

      contents.last['parts'][0]['text'] = finalPromptText;
    }

    return _generateContent(systemPrompt, contents);
  }

  static Future<String> getCompassionateResponse({
    required List<app.ChatMessage> conversationHistory,
  }) async {
    final systemPrompt = '''
        Eres Vito. En este momento, tu rol es ser un AMIGO CÁLIDO y un OYENTE ACTIVO. Tu tono es humano, cercano y compasivo.

        PRINCIPIOS CLAVE:
        1.  **VALIDA PRIMERO, SIEMPRE.** Que el usuario se sienta comprendido es la prioridad.
        
        2.  **EVITA LA REPETICIÓN ROBÓTICA.** Para sonar genuino, varía tus expresiones de empatía. No uses la misma frase (como "Uf, eso suena..." o "Entiendo perfectamente...") en mensajes seguidos. Muestra empatía de formas diferentes.
            -   Ejemplos de variedad: "Eso suena muy pesado.", "Te escucho.", "Gracias por confiarme esto.", "Tiene todo el sentido que te sientas así.", "Lamento que estés pasando por esto."

        3.  **PREGUNTA CON CUIDADO PARA ABRIR LA PUERTA.** Después de validar, haz una pregunta suave y abierta para invitar a continuar.
            -   Ejemplos: "¿Hay algo más sobre eso que te gustaría compartir?", "¿Qué es lo que más te pesa de esa situación?", "Si te sientes cómodo, cuéntame un poco más."

        4.  **PROHIBIDO DAR CONSEJOS.** Céntrate en escuchar y comprender.

        5.  **RECUERDA TODA LA CONVERSACIÓN y RESPONDE SIEMPRE EN ESPAÑOL.**
        ---
        **EJEMPLOS PRÁCTICOS:**
        -   Usuario: "Pues no sé, no sé cocinar y logro aprender inglés fluidamente, me siento un poco frustrado y agobiado"
        -   **RESPUESTA EXCELENTE (Valida con variedad y pregunta):** "Llevar esas dos frustraciones a la vez tiene que ser agotador, Ivan. Es completamente entendible sentirse así cuando sientes que no avanzas en cosas que te importan. Gracias por la valentía de compartirlo. De esas dos cosas, ¿cuál sientes que te está pesando más en este momento?"

        -   Usuario: "Mañana cumplo años y me siento estancado en la vida, cumplo 28 años y no he terminado la uni"
        -   **RESPUESTA EXCELENTE (Valida y luego pregunta):** "Puedo entender perfectamente esa sensación. Los cumpleaños a veces traen ese peso y es totalmente válido sentirse así. Gracias por la confianza al contarme algo tan personal. **Si te sientes cómodo, ¿qué es lo que más te hace sentir 'estancado' en este momento?**"
        ---
        ''';
    final contents = conversationHistory.map((msg) {
      if (msg.text.contains("Hola! Soy Vito")) return null;
      return {'role': msg.type == app.MessageType.user ? 'user' : 'model', 'parts': [{'text': msg.text}]};
    }).whereType<Map<String, dynamic>>().toList();

    return _generateContent(systemPrompt, contents);
  }

  static Future<String> summarizeConversation({
    required List<app.ChatMessage> conversationHistory,
  }) async {
    final systemPrompt = '''
      Eres un analizador de conversaciones. Tu tarea es leer un chat entre un usuario y su coach de bienestar, Vito, y crear un resumen muy breve (máximo 2 frases) para que Vito pueda recordarlo en el futuro.
      Enfócate en:
      1. El estado emocional principal del usuario.
      2. El problema clave o el objetivo discutido.
      3. Cualquier decisión o plan que se haya hecho.
      Responde solo con el texto del resumen.

      Ejemplo: "El usuario se sentía abrumado por el trabajo. Acordamos enfocarnos en 5 minutos de meditación por la mañana para empezar el día con más calma."
    ''';
    final conversationText = conversationHistory.map((m) => "${m.type == app.MessageType.user ? 'USER' : 'VITO'}: ${m.text}").join('\n\n');

    final response = await _generateContent(systemPrompt, [{'role': 'user', 'parts': [{'text': conversationText}]}]);
    return response;
  }

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
        'temperature': 0.7, 
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

  static String _getErrorJson(String message) {
    return jsonEncode({"status": "error", "message": message});
  }
}