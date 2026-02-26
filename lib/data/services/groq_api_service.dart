import 'dart:convert';
import 'package:flutter/foundation.dart'; // Importante: Nos da acceso a debugPrint
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/alerta_fuga_model.dart';
import '../models/lectura_sensor_model.dart';

/// Servicio encargado de la comunicación con la API de Groq
class GroqApiService {
  Future<AlertaFugaModel> analizarPatronReal(LecturaSensorModel lectura) async {
    // 1. Validar la API Key
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('⚠️ ERROR: API Key no encontrada en el archivo .env');
      throw Exception('API Key no configurada');
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    // 2. Estructuramos el Payload con el NUEVO MODELO
    final bodyPayload = {
      // Usamos el ID oficial del modelo Llama 3.3 70B que viste en la documentación
      "model": "llama-3.3-70b-versatile",
      "response_format": {
        "type": "json_object",
      }, // Obligamos a la IA a devolver un JSON
      "temperature": 0.0,
      "messages": [
        {
          "role": "system",
          "content":
              "Eres el cerebro de IA para un sistema IoT (EdgeLeak). Responde ÚNICAMENTE con un JSON válido. Las claves estrictas deben ser: \"veredicto\" (Fuga Detectada o Flujo Normal), \"severidad\" (Crítica, Advertencia o Normal), \"mensaje\" (Recomendación corta en español).",
        },
        {
          "role": "user",
          "content":
              "El sensor reporta un caudal de ${lectura.caudalLPM} L/min. Parámetros de referencia: Normal es de 0.1 a 0.5 L/min. Fuga es mayor a 5.0 L/min. Genera el JSON.",
        },
      ],
    };

    // --- LOGS INFALIBLES PARA VS CODE ---
    debugPrint('=== INICIANDO PETICIÓN A GROQ ===');
    debugPrint('Payload enviado: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyPayload),
      );

      // AQUÍ VEREMOS EL RESULTADO SÍ O SÍ EN VS CODE
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String content = data['choices'][0]['message']['content'];

        final Map<String, dynamic> jsonResponse = jsonDecode(content);
        jsonResponse['fecha'] = DateTime.now().toIso8601String();

        debugPrint('✅ ÉXITO - JSON Parseado correctamente: $jsonResponse');
        return AlertaFugaModel.fromMap(jsonResponse);
      } else {
        debugPrint('❌ ERROR DEL SERVIDOR: La API rechazó la petición.');
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ EXCEPCIÓN CAPTURADA: $e');

      return AlertaFugaModel(
        veredicto: 'Error de Red / IA',
        severidad: 'Advertencia',
        mensaje: 'Detalle técnico: $e',
        fecha: DateTime.now(),
      );
    }
  }
}
