import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:edgeleak/data/models/estado_sensor.dart';
import 'package:edgeleak/data/models/lectura_sensor_model.dart';
import 'package:edgeleak/data/services/groq_api_service.dart';

// =============================================================================
// HTTP Client fakes
// =============================================================================

/// Cliente HTTP que captura el body de cada POST para inspección en tests.
class _CapturingHttpClient extends http.BaseClient {
  Map<String, dynamic>? capturedBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
    }
    // Devuelve una respuesta 200 con un JSON válido de Groq
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'veredicto': 'Flujo Normal',
                    'severidad': 'Normal',
                    'mensaje': 'Sin anomalías detectadas.',
                  }),
                }
              }
            ],
          }),
        ),
      ),
      200,
    );
  }
}

/// Cliente HTTP que lanza [SocketException] para simular red offline.
class _ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('No route to host — simulación de red offline');
  }
}

// =============================================================================
// Helper para construir lecturas de test
// =============================================================================

LecturaSensorModel _lectura({
  double flujo = 1.5,
  int ruido = 900,
  int picos = 5,
}) =>
    LecturaSensorModel(
      caudalLPM: flujo,
      ruido: ruido,
      picos: picos,
      timestamp: DateTime(2025, 1, 1, 2, 0),
    );

// =============================================================================
// TESTS
// =============================================================================

void main() {
  setUpAll(() {
    // Cargar dotenv con clave falsa para que GroqApiService no aborte
    // antes de llegar a la llamada HTTP en los tests de integración.
    dotenv.testLoad(fileInput: 'GROQ_API_KEY=test-key-unit-tests\n');
  });

  group('GroqApiService — normalización de respuestas', () {
    // ─────────────────────────────────────────────────────────────────────────
    // test-48
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '48: veredicto "Fuga Detectada" (mayúsculas y tildes) → '
        'normalizado a EstadoSensor.fuga.veredicto', () {
      // ESCENARIO REAL: La IA devuelve exactamente el veredicto canónico de
      // fuga con mayúsculas iniciales tal como el sistema lo define.
      // ENTRADA: string "Fuga Detectada"
      // RESULTADO ESPERADO: normalizarVeredicto retorna EstadoSensor.fuga.veredicto.
      final service = GroqApiService();
      expect(
        service.normalizarVeredicto('Fuga Detectada'),
        EstadoSensor.fuga.veredicto,
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-49
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '49: variantes tipográficas del veredicto de fuga → '
        'normalizadas consistentemente a EstadoSensor.fuga.veredicto', () {
      // ESCENARIO REAL: Diferentes versiones del modelo LLM (o variaciones de
      // temperatura) devuelven el veredicto en distintas combinaciones de
      // mayúsculas/minúsculas. La normalización debe ser robusta.
      // ENTRADA: "fuga detectada", "FUGA DETECTADA", "hay una Fuga en la tubería"
      // RESULTADO ESPERADO: todos mapean a EstadoSensor.fuga.veredicto.
      final service = GroqApiService();
      expect(
        service.normalizarVeredicto('fuga detectada'),
        EstadoSensor.fuga.veredicto,
        reason: 'Lowercase debe mapear a fuga',
      );
      expect(
        service.normalizarVeredicto('FUGA DETECTADA'),
        EstadoSensor.fuga.veredicto,
        reason: 'Uppercase debe mapear a fuga',
      );
      expect(
        service.normalizarVeredicto('hay una Fuga en la tubería'),
        EstadoSensor.fuga.veredicto,
        reason: 'Veredicto con contexto adicional debe mapear a fuga',
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-50
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '50: severidad "crítica" (y variantes) → normalizada a '
        'EstadoSensor.fuga.severidad ("Crítica")', () {
      // ESCENARIO REAL: La IA puede devolver "crítica" en minúsculas (español)
      // o "critical" (inglés); ambas deben mapearse a la severidad de Fuga.
      // ENTRADA: "crítica", "CRÍTICA", "critical"
      // RESULTADO ESPERADO: EstadoSensor.fuga.severidad == "Crítica".
      final service = GroqApiService();
      expect(
        service.normalizarSeveridad('crítica'),
        EstadoSensor.fuga.severidad,
        reason: 'Español minúsculas debe mapear a Crítica',
      );
      expect(
        service.normalizarSeveridad('CRÍTICA'),
        EstadoSensor.fuga.severidad,
        reason: 'Español mayúsculas debe mapear a Crítica',
      );
      expect(
        service.normalizarSeveridad('critical'),
        EstadoSensor.fuga.severidad,
        reason: 'Inglés debe mapear a Crítica',
      );
    });
  });

  group('GroqApiService — construcción y envío del payload HTTP', () {
    // ─────────────────────────────────────────────────────────────────────────
    // test-51
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '51: payload HTTP enviado a Groq incluye picos acústicos, '
        'suma_picos_ventana y periodo_activo en el prompt del usuario', () async {
      // ESCENARIO REAL: El controlador envía a Groq el contexto con picos
      // acústicos del ESP32 y el período activo (nocturno/diurno) para que
      // la IA distinga goteo silencioso de ruido ambiental.
      // ENTRADA: contexto con picos=5, suma_picos_ventana=13,
      //          periodo_activo="nocturno", resúmenes de 5 días y baseline.
      // RESULTADO ESPERADO: el cuerpo HTTP contiene esos valores en el
      //   mensaje del usuario enviado a Groq.
      final capturing = _CapturingHttpClient();
      final service = GroqApiService(client: capturing);

      final contexto = <String, dynamic>{
        'picos': 5,
        'suma_picos_ventana': 13,
        'periodo_activo': 'nocturno',
        'resumenes_5d': <String>[
          '[2025-01-01 al 2025-01-05] flujo_prom=0.30 L/min, ruido_prom=820 ADC'
        ],
        'flujo_baseline': '0.300',
        'ruido_baseline': '820',
      };

      await service.analizarConContexto(
        lectura: _lectura(picos: 5),
        estadoLocal: EstadoSensor.anomalia,
        contexto: contexto,
      );

      expect(capturing.capturedBody, isNotNull,
          reason: 'El cliente HTTP debe haber capturado el body del POST');

      final messages =
          capturing.capturedBody!['messages'] as List<dynamic>;
      final userContent = messages[1]['content'] as String;

      // El prompt de usuario debe mencionar los picos actuales
      expect(userContent.contains('5'), isTrue,
          reason: 'El prompt debe incluir el conteo de picos actuales (5)');
      // La suma de la ventana de 60 s debe aparecer en el contexto formateado
      expect(userContent.contains('13'), isTrue,
          reason: 'El prompt debe incluir la suma de picos en ventana (13)');
      // El período activo nocturno debe ser visible
      expect(userContent.contains('nocturno'), isTrue,
          reason: 'El prompt debe indicar el período activo nocturno');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-52
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '52: fallo de red (SocketException) → fallback edge; '
        'mensaje contiene "Clasificación edge (sin conexión IA)"', () async {
      // ESCENARIO REAL: El servidor de Groq es inaccesible (sin WiFi, timeout
      // o fallo DNS). El sistema no debe perder el evento de anomalía; en su
      // lugar usa la clasificación edge local y guarda un registro de
      // diagnóstico para revisión posterior.
      // ENTRADA: http.Client que lanza SocketException en cada petición.
      // RESULTADO ESPERADO:
      //   · alerta.mensaje contiene "Clasificación edge (sin conexión IA)".
      //   · alerta.veredicto refleja el estado local (anomalia.veredicto).
      final service = GroqApiService(client: _ThrowingHttpClient());
      final lectura = _lectura(flujo: 2.5, picos: 8);

      final alerta = await service.analizarConContexto(
        lectura: lectura,
        estadoLocal: EstadoSensor.anomalia,
        contexto: {},
      );

      expect(
        alerta.mensaje,
        contains('Clasificación edge (sin conexión IA)'),
        reason: 'El mensaje de fallback debe identificar el origen edge',
      );
      // El veredicto debe reflejar la clasificación local, no un estado genérico
      expect(
        alerta.veredicto,
        EstadoSensor.anomalia.veredicto,
        reason: 'El veredicto de fallback debe ser el del estadoLocal',
      );
    });
  });
}
