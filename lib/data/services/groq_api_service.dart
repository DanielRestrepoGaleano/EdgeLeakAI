import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/alerta_fuga_model.dart';
import '../models/estado_sensor.dart';
import '../models/lectura_sensor_model.dart';

/// Servicio encargado de la comunicación con la API de Groq.
///
/// La consulta a Groq es **event-driven**: solo se invoca cuando el procesamiento
/// local detecta una desviación del baseline o un cambio de estado, nunca por
/// polling periódico.
///
/// El payload incluye:
/// - La lectura anómala actual (flujo + ruido + picos).
/// - El estado clasificado localmente ([EstadoSensor]).
/// - Un resumen contextual de los últimos días (baseline + historial).
/// - Los picos acústicos y la suma de la ventana de 60 s.
///
/// La IA devuelve uno de los tres estados canónicos: Normal, Anomalía o Fuga.
class GroqApiService {
  final http.Client _client;

  GroqApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Analiza una lectura anómala con contexto histórico y devuelve el veredicto
  /// definitivo de la IA clasificado en los tres estados del sistema.
  ///
  /// [lectura] contiene el caudal, el nivel de ruido y los micro-picos actuales.
  /// [estadoLocal] es la clasificación previa realizada por el procesamiento edge.
  /// [contexto] es un mapa con el resumen histórico para que la IA tenga referencia.
  Future<AlertaFugaModel> analizarConContexto({
    required LecturaSensorModel lectura,
    required EstadoSensor estadoLocal,
    required Map<String, dynamic> contexto,
  }) async {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('⚠️ ERROR: API Key no encontrada en el archivo .env');
      throw Exception('API Key no configurada');
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final contextoTexto = _formatearContexto(contexto);

    final bodyPayload = {
      "model": "llama-3.3-70b-versatile",
      "response_format": {"type": "json_object"},
      "temperature": 0.0,
      "messages": [
        {
          "role": "system",
          "content":
              "Eres el motor de IA del sistema IoT EdgeLeak, especializado en detección de microfugas en lavaplatos manuales. "
              "Analiza la lectura anómala del sensor y el contexto histórico proporcionado para emitir un veredicto final. "
              "Responde ÚNICAMENTE con un JSON válido con las claves exactas: "
              "\"veredicto\" (valores permitidos: \"Flujo Normal\", \"Anomalía Detectada\", \"Fuga Detectada\"), "
              "\"severidad\" (valores permitidos: \"Normal\", \"Advertencia\", \"Crítica\"), "
              "\"mensaje\" (recomendación técnica corta en español, máximo 120 caracteres). "
              "Considera el historial para distinguir comportamiento normal del usuario de anomalías reales.",
        },
        {
          "role": "user",
          "content":
              "LECTURA ANÓMALA DETECTADA:\n"
              "  - Caudal actual: ${lectura.caudalLPM.toStringAsFixed(3)} L/min\n"
              "  - Ruido actual: ${lectura.ruido} ADC\n"
              "  - Picos acústicos: ${lectura.picos}\n"
              "  - Clasificación edge: ${estadoLocal.etiqueta}\n\n"
              "CONTEXTO HISTÓRICO (últimos días):\n$contextoTexto\n\n"
              "PARÁMETROS DE REFERENCIA:\n"
              "  - Flujo Normal: 0.0 – 6.9 L/min\n"
              "  - Anomalía de flujo: 7.0 – 7.9 L/min\n"
              "  - Fuga activa: >= 8.0 L/min\n"
              "  - Umbral de ruido significativo: 1500 ADC\n\n"
              "Emite el veredicto final considerando el contexto histórico del usuario. Genera el JSON.",
        },
      ],
    };

    debugPrint('=== INICIANDO PETICIÓN A GROQ (event-driven) ===');
    debugPrint(
        'Estado local: ${estadoLocal.etiqueta} | flujo: ${lectura.caudalLPM} | ruido: ${lectura.ruido} | picos: ${lectura.picos}');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyPayload),
      );

      debugPrint('Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String content = data['choices'][0]['message']['content'];
        final Map<String, dynamic> jsonResponse = jsonDecode(content);
        jsonResponse['fecha'] = DateTime.now().toIso8601String();

        // Normalizar el veredicto a los valores canónicos del sistema
        jsonResponse['veredicto'] =
            normalizarVeredicto(jsonResponse['veredicto'] as String? ?? '');
        jsonResponse['severidad'] =
            normalizarSeveridad(jsonResponse['severidad'] as String? ?? '');

        debugPrint(
            '✅ Groq → veredicto: ${jsonResponse['veredicto']} | severidad: ${jsonResponse['severidad']}');
        return AlertaFugaModel.fromMap(jsonResponse);
      } else {
        debugPrint('❌ ERROR DEL SERVIDOR: ${response.statusCode} ${response.body}');
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ EXCEPCIÓN CAPTURADA en Groq: $e');
      // Fallback: usar la clasificación local del edge para no perder el evento
      return AlertaFugaModel(
        veredicto: estadoLocal.veredicto,
        severidad: estadoLocal.severidad,
        mensaje:
            'Clasificación edge (sin conexión IA). Flujo: ${lectura.caudalLPM.toStringAsFixed(3)} L/min.',
        fecha: DateTime.now(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatearContexto(Map<String, dynamic> contexto) {
    final buffer = StringBuffer();

    final resumenes = contexto['resumenes_5d'] as List<String>? ?? [];
    if (resumenes.isNotEmpty) {
      buffer.writeln('Resúmenes de bloque (5 días):');
      for (final r in resumenes) {
        buffer.writeln('  $r');
      }
    }

    final mensual = contexto['historial_mensual'] as String?;
    if (mensual != null) {
      buffer.writeln('Historial mensual:');
      buffer.writeln('  $mensual');
    }

    final flujoBase = contexto['flujo_baseline'] as String?;
    final ruidoBase = contexto['ruido_baseline'] as String?;
    if (flujoBase != null) {
      buffer.writeln(
          'Baseline actual: flujo=$flujoBase L/min | ruido=$ruidoBase ADC');
    }

    final picos = contexto['picos'];
    final sumaPicos = contexto['suma_picos_ventana'];
    if (picos != null) {
      buffer.writeln(
          'Picos acústicos (lectura actual): $picos | Suma ventana 60 s: $sumaPicos');
    }

    final periodoActivo = contexto['periodo_activo'] as String?;
    if (periodoActivo != null) {
      buffer.writeln('Período activo: $periodoActivo');
    }

    if (buffer.isEmpty) {
      buffer.writeln('Sin historial disponible (sistema nuevo o datos insuficientes).');
    }

    return buffer.toString();
  }

  /// Normaliza el veredicto devuelto por Groq a los valores canónicos del sistema.
  @visibleForTesting
  String normalizarVeredicto(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('fuga')) return EstadoSensor.fuga.veredicto;
    if (lower.contains('anomal') || lower.contains('advertencia')) {
      return EstadoSensor.anomalia.veredicto;
    }
    return EstadoSensor.normal.veredicto;
  }

  /// Normaliza la severidad devuelta por Groq a los valores canónicos del sistema.
  @visibleForTesting
  String normalizarSeveridad(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('crít') || lower.contains('critic')) {
      return EstadoSensor.fuga.severidad;
    }
    if (lower.contains('advertencia') || lower.contains('warning')) {
      return EstadoSensor.anomalia.severidad;
    }
    return EstadoSensor.normal.severidad;
  }
}
