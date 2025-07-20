const functions = require('firebase-functions');
const { GoogleAuth } = require('google-auth-library');

const PROJECT_ID = 'vito-app-463903';
const LOCATION = 'us-central1';
const MODEL_ID = 'gemini-2.0-flash-lite';

const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

// --- MODIFICACIÓN CLAVE: Aumentamos el timeout y añadimos logs ---
exports.vertexAIProxy = functions
  // 1. Aumentamos el tiempo de espera a 300 segundos (5 minutos)
  .runWith({ timeoutSeconds: 300 })
  .https.onCall(async (data, context) => {
    
    console.log("Función iniciada. Payload recibido:", JSON.stringify(data, null, 2));

    if (!context.auth) {
       console.error("Llamada no autenticada.");
       throw new functions.https.HttpsError(
         'unauthenticated',
         'La función debe ser llamada por un usuario autenticado.'
       );
    }
    
    console.log(`Usuario autenticado: ${context.auth.uid}`);

    const { systemInstruction, contents } = data;
    if (!systemInstruction || !Array.isArray(contents) || contents.length === 0) {
      console.error("Payload inválido: Faltan systemInstruction o contents.");
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Payload inválido.'
      );
    }

    try {
      const url = `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/${MODEL_ID}:generateContent`;

      // 2. LOGS paso a paso para encontrar el punto de fallo
      console.log("Paso 1: Obteniendo cliente de autenticación...");
      const client = await auth.getClient();
      console.log("Paso 2: Cliente obtenido. Realizando la llamada a Vertex AI en:", url);

      const response = await client.request({
        url,
        method: 'POST',
        data: data,
      });

      console.log("Paso 3: Llamada a Vertex AI exitosa. Devolviendo datos.");
      return response.data;

    } catch (error) {
      console.error(
        "Error DETALLADO en el bloque catch:",
        error.response ? JSON.stringify(error.response.data, null, 2) : error
      );
      throw new functions.https.HttpsError(
        'internal',
        'Ocurrió un error al procesar la solicitud con el servicio de IA.',
        error.message
      );
    }
  });