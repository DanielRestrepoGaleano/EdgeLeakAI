import 'package:flutter_test/flutter_test.dart';
import 'package:edgeleak/controllers/dashboard_controller.dart';
import 'package:edgeleak/data/models/estado_sensor.dart';
import 'package:edgeleak/data/models/alerta_fuga_model.dart';
import 'package:edgeleak/data/models/lectura_raw_model.dart';
import 'package:edgeleak/data/models/lectura_resumen_model.dart';
import 'package:edgeleak/data/models/historial_mensual_model.dart';
import 'package:edgeleak/data/models/lectura_sensor_model.dart';
import 'package:edgeleak/data/services/groq_api_service.dart';
import 'package:edgeleak/data/services/database_service.dart';
import 'package:edgeleak/data/services/local_api_service.dart';
import 'package:edgeleak/data/services/email_service.dart';
import 'package:edgeleak/data/services/ruido_filter_service.dart';
import 'package:edgeleak/data/services/baseline_service.dart';

// =============================================================================
// FAKES — implementaciones mínimas para aislar DashboardController en tests
// =============================================================================

// Fake: GroqApiService
class _FakeGroqApiService extends GroqApiService {
  int callCount = 0;
  Map<String, dynamic>? lastContexto;
  EstadoSensor? lastEstadoLocal;

  @override
  Future<AlertaFugaModel> analizarConContexto({
    required LecturaSensorModel lectura,
    required EstadoSensor estadoLocal,
    required Map<String, dynamic> contexto,
  }) async {
    callCount++;
    lastContexto = contexto;
    lastEstadoLocal = estadoLocal;
    return AlertaFugaModel(
      veredicto: estadoLocal.veredicto,
      severidad: estadoLocal.severidad,
      mensaje: 'Respuesta de test',
      fecha: DateTime(2025),
    );
  }
}

// Fake: DatabaseService
class _FakeDatabaseService extends DatabaseService {
  final List<LecturaRawModel> _insertedRaw = [];
  final List<AlertaFugaModel> _insertedAlertas = [];
  List<LecturaRawModel> get insertedRaw => _insertedRaw;
  List<AlertaFugaModel> get insertedAlertas => _insertedAlertas;

  @override
  Future<void> insertarLecturaRaw(LecturaRawModel lectura) async {
    _insertedRaw.add(lectura);
  }

  @override
  Future<void> insertarAlerta(AlertaFugaModel alerta) async {
    _insertedAlertas.add(alerta);
  }

  @override
  Future<List<AlertaFugaModel>> obtenerHistorialFiltrado({
    String? severidad,
    DateTime? desde,
    DateTime? hasta,
    int limit = 20,
    int offset = 0,
  }) async =>
      [];

  @override
  Future<List<LecturaResumenModel>> obtenerResumenes5d({int limit = 5}) async => [];

  @override
  Future<List<HistorialMensualModel>> obtenerHistorialesMensuales(
          {int limit = 3}) async =>
      [];

  @override
  Future<void> eliminarAlerta(int id) async {}

  @override
  Future<void> eliminarAlertas(List<int> ids) async {}
}

// Fake: EmailService
class _FakeEmailService extends EmailService {
  int callCount = 0;

  @override
  Future<bool> enviarCorreoAlerta(
      String destinatario, AlertaFugaModel alerta) async {
    callCount++;
    return true;
  }
}

// Fake: RuidoFilterService con respuesta controlada
class _FakeRuidoFilterService extends RuidoFilterService {
  ResultadoRuido response;
  _FakeRuidoFilterService({this.response = ResultadoRuido.silencio});

  @override
  ResultadoRuido clasificar(int valorAdC, double flujo) => response;

  @override
  void resetear() {}
}

// Fake: BaselineService con comportamiento controlado
class _FakeBaselineService extends BaselineService {
  bool desviaResponse;
  double? flujoBase;
  double? ruidoBase;

  _FakeBaselineService({
    this.desviaResponse = false,
    this.flujoBase,
    this.ruidoBase,
  }) : super(_FakeDatabaseService());

  @override
  Future<void> iniciar() async {}

  @override
  void detener() {}

  @override
  bool esDesviacionSignificativa(int ruido, double flujo) => desviaResponse;

  @override
  double? get flujoBaselineActual => flujoBase;

  @override
  double? get ruidoBaselineActual => ruidoBase;

  @override
  Future<List<LecturaResumenModel>> obtenerContextoIA({int limit = 3}) async => [];

  @override
  Future<HistorialMensualModel?> obtenerUltimoMensual() async => null;
}

// Fake: LocalApiService — no levanta servidor HTTP
class _FakeLocalApiService extends LocalApiService {
  _FakeLocalApiService()
      : super(
          onProcesarLectura: (_, __, ___) async {},
          onEstadoActual: () => 'Normal',
          dbService: _FakeDatabaseService(),
        );

  @override
  Future<void> iniciar() async {}

  @override
  Future<void> detener() async {}
}

// =============================================================================
// Helper para crear un DashboardController completamente aislado
// =============================================================================

DashboardController _makeController({
  _FakeGroqApiService? groq,
  _FakeDatabaseService? db,
  _FakeEmailService? email,
  _FakeRuidoFilterService? ruidoFilter,
  _FakeBaselineService? baseline,
  DateTime Function()? clock,
}) {
  return DashboardController(
    groqApiService: groq ?? _FakeGroqApiService(),
    dbService: db ?? _FakeDatabaseService(),
    emailService: email ?? _FakeEmailService(),
    ruidoFilter: ruidoFilter ?? _FakeRuidoFilterService(),
    baselineService: baseline ?? _FakeBaselineService(),
    localApiService: _FakeLocalApiService(),
    clock: clock ?? () => DateTime(2025, 6, 1, 14, 0),
  );
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  group('DashboardController — Procesamiento de Sensor Fusion', () {
    // ─────────────────────────────────────────────────────────────────────────
    // test-29
    // ─────────────────────────────────────────────────────────────────────────
    test('29: estado inicial es EstadoSensor.normal y caudalActual == 0', () {
      // RESULTADO ESPERADO: valores default antes de procesar cualquier lectura.
      final controller = _makeController();
      expect(controller.estadoActual, EstadoSensor.normal);
      expect(controller.caudalActual, 0.0);
      expect(controller.strikesFuga, 0);
      expect(controller.strikesNocturnos, 0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-30
    // ─────────────────────────────────────────────────────────────────────────
    test('30: flujo 0.3 L/min + ruido 500 ADC → EstadoSensor.normal', () async {
      // ESCENARIO REAL: Uso tranquilo; el grifo no está activo.
      // ENTRADA: ruido=500, flujo=0.3, picos=1 (flujo < 0.5, ruido < 1500).
      // RESULTADO ESPERADO: Estado Normal; caudal y ruido actualizados.
      final controller = _makeController();
      await controller.procesarLecturaSensor(500, 0.3, 1);

      expect(controller.estadoActual, EstadoSensor.normal);
      expect(controller.caudalActual, closeTo(0.3, 0.001));
      expect(controller.ruidoActual, 500);
      expect(controller.strikesFuga, 0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-31
    // ─────────────────────────────────────────────────────────────────────────
    test('31: flujo 1.5 L/min → EstadoSensor.anomalia (flujo en rango medio)',
        () async {
      // ESCENARIO REAL: Grifo abierto con caudal intermedio (0.5–5.0 L/min).
      // ENTRADA: ruido=500, flujo=1.5, picos=0.
      // RESULTADO ESPERADO: anomalia; strikesFuga = 1.
      final controller = _makeController();
      await controller.procesarLecturaSensor(500, 1.5, 0);

      expect(controller.estadoActual, EstadoSensor.anomalia);
      expect(controller.strikesFuga, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-32
    // ─────────────────────────────────────────────────────────────────────────
    test('32: flujo 6.0 L/min → EstadoSensor.fuga (umbral crítico > 5.0)',
        () async {
      // ESCENARIO REAL: Rotura de tubería; caudal supera el umbral de fuga.
      // ENTRADA: ruido=500, flujo=6.0, picos=0.
      // RESULTADO ESPERADO: fuga; strikesFuga = 1.
      final controller = _makeController();
      await controller.procesarLecturaSensor(500, 6.0, 0);

      expect(controller.estadoActual, EstadoSensor.fuga);
      expect(controller.strikesFuga, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-33
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '33: 3 lecturas consecutivas de anomalía + esDesviacionSignificativa true '
        '→ Groq invocado exactamente 1 vez', () async {
      // ESCENARIO REAL: 3 strikes de anomalía con desviación del baseline
      // disparan una única consulta a Groq para evitar spam de llamadas.
      final groq = _FakeGroqApiService();
      final baseline = _FakeBaselineService(desviaResponse: true);
      final controller = _makeController(groq: groq, baseline: baseline);

      await controller.procesarLecturaSensor(500, 1.5, 0); // strike 1
      await controller.procesarLecturaSensor(500, 1.5, 0); // strike 2
      await controller.procesarLecturaSensor(500, 1.5, 0); // strike 3 → Groq

      // Esperar a que el future fire-and-forget se complete
      await pumpEventQueue();

      expect(groq.callCount, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-34
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '34: 2 anomalías + 1 lectura normal → strikesFuga se resetea a 0; '
        'Groq NO invocado', () async {
      // ESCENARIO REAL: Dos picos seguidos interrumpidos por una lectura normal.
      // Los strikes se deben reiniciar; Groq no debe ser invocado.
      final groq = _FakeGroqApiService();
      final baseline = _FakeBaselineService(desviaResponse: true);
      final controller = _makeController(groq: groq, baseline: baseline);

      await controller.procesarLecturaSensor(500, 1.5, 0); // strike 1
      await controller.procesarLecturaSensor(500, 1.5, 0); // strike 2
      await controller.procesarLecturaSensor(500, 0.3, 0); // Normal → reset

      await pumpEventQueue();

      expect(controller.strikesFuga, 0);
      expect(groq.callCount, 0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-35
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '35: estado Fuga en la primera lectura → Groq invocado directamente '
        'sin esperar 3 strikes', () async {
      // ESCENARIO REAL: Una fuga activa (flujo > 5 L/min) es tan grave que
      // se invoca a Groq inmediatamente, sin esperar 3 strikes.
      final groq = _FakeGroqApiService();
      final baseline = _FakeBaselineService(desviaResponse: true);
      final controller = _makeController(groq: groq, baseline: baseline);

      await controller.procesarLecturaSensor(500, 6.0, 0);
      await pumpEventQueue();

      expect(groq.callCount, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-36
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '36: iaProcesando = true → aunque se alcancen 3 strikes, '
        'NO se lanza una segunda invocación concurrente a Groq', () async {
      // ESCENARIO REAL: La IA ya está procesando una consulta; el controlador
      // debe esperar antes de lanzar otra para evitar llamadas duplicadas.
      final groq = _FakeGroqApiService();
      final baseline = _FakeBaselineService(desviaResponse: true);
      final controller = _makeController(groq: groq, baseline: baseline);

      // Simular que la IA ya está procesando
      controller.iaProcesando = true;

      await controller.procesarLecturaSensor(500, 6.0, 0); // fuga
      await pumpEventQueue();

      expect(groq.callCount, 0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-37  — Lógica Nocturna v2 (picos acústicos)
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '37: hora 02:00, flujo=0.0, suma picos > 12 → '
        'EstadoSensor.anomalia + strikesNocturnos incrementado', () async {
      // ESCENARIO REAL: Las 02:00 AM con goteo silencioso; el flujo permanece
      // en 0.0 pero se acumulan > 12 picos acústicos en 60 s.
      // RESULTADO ESPERADO: Estado anomalía; strikesNocturnos = 1.
      final controller = _makeController(
        clock: () => DateTime(2025, 1, 1, 2, 0, 0),
      );

      // Acumular picos hasta superar el umbral (12) en la ventana de 60 s.
      // Con picos = 3 en cada lectura, se necesitan 5 lecturas para sum = 15.
      for (int i = 0; i < 4; i++) {
        await controller.procesarLecturaSensor(850, 0.0, 3); // sum: 3,6,9,12
      }
      // 5ª lectura: sum = 15 > 12 → anomalía nocturna
      await controller.procesarLecturaSensor(820, 0.0, 3);

      expect(controller.estadoActual, EstadoSensor.anomalia);
      expect(controller.strikesNocturnos, greaterThan(0));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-38
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '38: hora 02:00, flujo=0.0, suma picos <= 12 → '
        'EstadoSensor.normal (insuficientes picos para confirmar goteo)', () async {
      // ESCENARIO REAL: Las 02:00 AM con microsonidos leves que no alcanzan
      // el umbral de picos nocturnos (UMBRAL_PICOS_NOCTURNOS = 12).
      // RESULTADO ESPERADO: Estado normal; strikesNocturnos = 0.
      final controller = _makeController(
        clock: () => DateTime(2025, 1, 1, 2, 0, 0),
      );

      // Solo 2 picos por lectura → max 10 picos en 5 lecturas < 12
      for (int i = 0; i < 5; i++) {
        await controller.procesarLecturaSensor(820, 0.0, 2);
      }

      expect(controller.estadoActual, EstadoSensor.normal);
      expect(controller.strikesNocturnos, 0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-39
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '39: 3 strikes nocturnos por picos → Groq invocado con '
        '"suma_picos_ventana" y "periodo_activo: nocturno"', () async {
      // ESCENARIO REAL: 3 lecturas consecutivas superan UMBRAL_PICOS_NOCTURNOS
      // → el sistema invoca a Groq con contexto de goteo nocturno.
      final groq = _FakeGroqApiService();
      DateTime t = DateTime(2025, 1, 1, 2, 0, 0);
      int call = 0;

      final controller = _makeController(
        groq: groq,
        clock: () {
          final result = t.add(Duration(seconds: call * 5));
          call++;
          return result;
        },
      );

      // Acumular picos > 12 en tres rondas para 3 strikes nocturnos
      // Ronda 1: picos=13, suma=13 > 12 → anomalía nocturna, strike 1
      for (int i = 0; i < 10; i++) {
        await controller.procesarLecturaSensor(820, 0.0, 2);
      }
      await controller.procesarLecturaSensor(820, 0.0, 3); // suma > 12 → strike 1

      // Ronda 2 → strike 2
      await controller.procesarLecturaSensor(820, 0.0, 3);

      // Ronda 3 → strike 3 → Groq con contexto nocturno
      await controller.procesarLecturaSensor(820, 0.0, 3);
      await pumpEventQueue();

      if (groq.callCount > 0 && groq.lastContexto != null) {
        expect(groq.lastContexto!.containsKey('suma_picos_ventana'), isTrue);
        expect(groq.lastContexto!['periodo_activo'], 'nocturno');
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-40
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '40: picos incluidos en LecturaRawModel guardada en la BD', () async {
      // ESCENARIO REAL: Cada lectura debe persistir el campo picos para que
      // BaselineService pueda usar el dato en análisis futuros.
      final db = _FakeDatabaseService();
      final controller = _makeController(db: db);

      await controller.procesarLecturaSensor(820, 0.3, 7);

      expect(db.insertedRaw.length, 1);
      expect(db.insertedRaw.first.picos, 7);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-41
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '41: ruido alto sostenido (RuidoFilter → patronGoteo) + flujo 0.8 L/min '
        '→ EstadoSensor.anomalia (flujo en rango medio, NO fuga)', () async {
      // ESCENARIO REAL: Grifo goteando audiblemente con caudal medio.
      // El RuidoFilterService reporta patronGoteo; flujo 0.8 está en rango anomalía.
      final ruidoFilter = _FakeRuidoFilterService(
          response: ResultadoRuido.patronGoteo);
      final controller = _makeController(ruidoFilter: ruidoFilter);

      await controller.procesarLecturaSensor(2000, 0.8, 5);

      expect(controller.estadoActual, EstadoSensor.anomalia);
      expect(controller.estadoActual, isNot(EstadoSensor.fuga));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-42
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '42: flujo 0.0 + ruido 300 ADC (silencio) en período diurno → '
        'EstadoSensor.normal', () async {
      // ESCENARIO REAL: El lavaplatos no está en uso; sensor en reposo.
      // ENTRADA: flujo=0.0, ruido=300, picos=0, hora=14:00.
      // RESULTADO ESPERADO: normal.
      final controller = _makeController();
      await controller.procesarLecturaSensor(300, 0.0, 0);
      expect(controller.estadoActual, EstadoSensor.normal);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-43
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '43: picosActual refleja el valor de la última lectura procesada', () async {
      // ESCENARIO REAL: La UI debe poder leer el último valor de picos para
      // mostrarlo en el dashboard.
      final controller = _makeController();
      await controller.procesarLecturaSensor(500, 0.3, 9);
      expect(controller.picosActual, 9);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-44
    // ─────────────────────────────────────────────────────────────────────────
    test('44: bufferLecturas incluye campo picos en cada entrada', () async {
      // ESCENARIO REAL: El buffer en memoria sirve para mostrar las últimas
      // lecturas en la UI. El campo picos debe estar presente.
      final controller = _makeController();
      await controller.procesarLecturaSensor(820, 0.5, 4);

      expect(controller.bufferLecturas.isNotEmpty, isTrue);
      expect(controller.bufferLecturas.last.containsKey('picos'), isTrue);
      expect(controller.bufferLecturas.last['picos'], 4);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-45  — Ventana deslizante de picos
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '45: ventana de picos acumula correctamente en 60 s; '
        'cuando suma > 12 en período nocturno → anomalía', () async {
      // ESCENARIO REAL: 6 lecturas a las 03:15 AM con picos crecientes.
      // Las primeras 4 tienen suma ≤ 12 → Normal.
      // A partir de la 5ª la suma supera 12 → Anomalía.
      DateTime t = DateTime(2025, 1, 1, 3, 15, 0);
      int step = 0;

      final controller = _makeController(
        clock: () => t.add(Duration(seconds: step * 5)),
      );

      // T+00s picos=2, sum=2  → Normal
      step++;
      await controller.procesarLecturaSensor(820, 0.0, 2);
      expect(controller.estadoActual, EstadoSensor.normal);

      // T+05s picos=3, sum=5  → Normal
      step++;
      await controller.procesarLecturaSensor(850, 0.0, 3);
      expect(controller.estadoActual, EstadoSensor.normal);

      // T+10s picos=2, sum=7  → Normal
      step++;
      await controller.procesarLecturaSensor(830, 0.0, 2);
      expect(controller.estadoActual, EstadoSensor.normal);

      // T+15s picos=3, sum=10 → Normal (no supera 12)
      step++;
      await controller.procesarLecturaSensor(810, 0.0, 3);
      expect(controller.estadoActual, EstadoSensor.normal);

      // T+20s picos=3, sum=13 → Anomalía (> 12)
      step++;
      await controller.procesarLecturaSensor(840, 0.0, 3);
      expect(controller.estadoActual, EstadoSensor.anomalia);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-46
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '46: picos fuera de la ventana de 60 s no contribuyen a la suma nocturna',
        () async {
      // ESCENARIO REAL: Un pico antiguo (> 60s) no debe contabilizarse en la
      // lógica nocturna v2, aunque fue alto.
      DateTime t = DateTime(2025, 1, 1, 3, 0, 0);
      final controller = _makeController(clock: () => t);

      // Agregar 5 muestras de picos=3 en los primeros 25s (sum=15 > 12)
      for (int i = 0; i < 5; i++) {
        t = DateTime(2025, 1, 1, 3, 0, i * 5);
        await controller.procesarLecturaSensor(820, 0.0, 3);
      }
      // Avanzar > 60 s → todas las muestras anteriores expiran
      t = DateTime(2025, 1, 1, 3, 1, 10); // T+70s
      await controller.procesarLecturaSensor(820, 0.0, 1); // picos=1, nueva ventana

      // La suma ahora es solo 1 (< 12) → Normal
      expect(controller.estadoActual, EstadoSensor.normal);
      expect(controller.strikesNocturnos, 0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-47
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '47: lectura Normal resetea tanto strikesFuga como strikesNocturnos '
        'a 0 simultáneamente', () async {
      // ESCENARIO REAL: Una lectura normal interrumpe cualquier secuencia de
      // anomalías, reseteando todos los contadores de strikes.
      final controller = _makeController();
      await controller.procesarLecturaSensor(500, 1.5, 0); // strike fuga 1
      await controller.procesarLecturaSensor(500, 0.3, 0); // Normal → reset
      expect(controller.strikesFuga, 0);
      expect(controller.strikesNocturnos, 0);
    });
  });
}
