import 'package:flutter_test/flutter_test.dart';
import 'package:edgeleak/data/models/lectura_raw_model.dart';
import 'package:edgeleak/data/models/lectura_resumen_model.dart';
import 'package:edgeleak/data/models/historial_mensual_model.dart';
import 'package:edgeleak/data/services/baseline_service.dart';
import 'package:edgeleak/data/services/database_service.dart';

// ---------------------------------------------------------------------------
// Fake DatabaseService para pruebas de BaselineService
// ---------------------------------------------------------------------------

class _FakeDatabaseService extends DatabaseService {
  List<LecturaRawModel> _rawReadings = [];
  List<LecturaResumenModel> _resumenes = [];

  void setRawReadings(List<LecturaRawModel> readings) =>
      _rawReadings = readings;

  void setResumenes(List<LecturaResumenModel> resumenes) =>
      _resumenes = resumenes;

  @override
  Future<List<LecturaRawModel>> obtenerLecturasRawRecientes(
          {required int dias}) async =>
      _rawReadings;

  @override
  Future<List<LecturaRawModel>> obtenerLecturasRawEnRango({
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      _rawReadings;

  @override
  Future<List<LecturaResumenModel>> obtenerResumenes5d({int limit = 5}) async =>
      _resumenes.take(limit).toList();

  @override
  Future<List<HistorialMensualModel>> obtenerHistorialesMensuales(
          {int limit = 3}) async =>
      [];

  @override
  Future<void> insertarResumen5d(LecturaResumenModel resumen) async {}

  @override
  Future<void> insertarHistorialMensual(HistorialMensualModel mensual) async {}

  @override
  Future<void> eliminarResumenes5d(List<int> ids) async {}
}

// ---------------------------------------------------------------------------
// Helper para generar lecturas con timestamp controlado
// ---------------------------------------------------------------------------

LecturaRawModel _lectura({
  required DateTime timestamp,
  double flujo = 0.3,
  int ruido = 820,
  String estado = 'Normal',
  int picos = 2,
}) =>
    LecturaRawModel(
      ruido: ruido,
      flujo: flujo,
      estado: estado,
      timestamp: timestamp,
      picos: picos,
    );

/// Genera [count] lecturas diurnas (hora 14:00) a partir de [base].
List<LecturaRawModel> _generarLecturasDiurnas(
    int count, DateTime base, double flujo, int ruido) {
  return List.generate(
    count,
    (i) => _lectura(
      timestamp: base.add(Duration(seconds: i * 5)),
      flujo: flujo,
      ruido: ruido,
    ),
  );
}

/// Genera [count] lecturas nocturnas (hora 03:00) a partir de [base].
List<LecturaRawModel> _generarLecturasNocturnas(
    int count, DateTime base, double flujo, int ruido) {
  return List.generate(
    count,
    (i) => _lectura(
      timestamp: base.add(Duration(seconds: i * 5)),
      flujo: flujo,
      ruido: ruido,
    ),
  );
}

void main() {
  group('BaselineService — perfilado y desviación', () {
    // ─────────────────────────────────────────────────────────────────────────
    // test-22
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '22: con < 30 lecturas el baseline no se construye '
        'y esDesviacionSignificativa retorna true (conservador)', () async {
      // ESCENARIO REAL: Sistema nuevo; solo hay 5 lecturas acumuladas.
      // Sin baseline suficiente, cualquier anomalía debe invocar a la IA.
      // ENTRADA: 5 lecturas en la DB.
      // RESULTADO ESPERADO: esDesviacionSignificativa = true para cualquier lectura.
      final db = _FakeDatabaseService();
      final base = DateTime(2025, 6, 1, 14, 0);
      db.setRawReadings(
          _generarLecturasDiurnas(5, base, 0.3, 820));

      final service = BaselineService(db);
      await service.iniciar();

      expect(service.baselineListo, isFalse);
      expect(service.esDesviacionSignificativa(820, 0.3), isTrue);
      service.detener();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-23
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '23: con ≥ 30 lecturas diurnas en rango normal '
        'la lectura dentro del baseline retorna false', () async {
      // ESCENARIO REAL: Usuario con 5 días de historial; lectura idéntica
      // al baseline no debe disparar la IA.
      // ENTRADA: 40 lecturas diurnas con flujo=0.3, ruido=820.
      // RESULTADO ESPERADO: esDesviacionSignificativa(820, 0.3) = false.
      final db = _FakeDatabaseService();
      final base = DateTime(2025, 6, 1, 14, 0);
      db.setRawReadings(
          _generarLecturasDiurnas(40, base, 0.3, 820));

      final service = BaselineService(
          db, clock: () => DateTime(2025, 6, 1, 14, 30));
      await service.iniciar();

      expect(service.baselineListo, isTrue);
      expect(service.esDesviacionSignificativa(820, 0.3), isFalse);
      service.detener();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-24
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '24: flujo que excede el umbral de desviación (0.30 L/min) '
        'dispara esDesviacionSignificativa = true', () async {
      // ESCENARIO REAL: Baseline en 0.3 L/min; lectura actual 0.7 L/min
      // → desviación de flujo = 0.4 > 0.30 → debe disparar la IA.
      // ENTRADA: baseline flujo=0.3; lectura flujo=0.7.
      // RESULTADO ESPERADO: true.
      final db = _FakeDatabaseService();
      final base = DateTime(2025, 6, 1, 14, 0);
      db.setRawReadings(
          _generarLecturasDiurnas(40, base, 0.3, 820));

      final service = BaselineService(
          db, clock: () => DateTime(2025, 6, 1, 14, 30));
      await service.iniciar();

      expect(service.esDesviacionSignificativa(820, 0.7), isTrue);
      service.detener();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-25
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '25: ruido que excede el umbral de desviación (500 ADC) '
        'dispara esDesviacionSignificativa = true', () async {
      // ESCENARIO REAL: Baseline en 820 ADC; lectura actual 1400 ADC
      // → desviación de ruido = 580 > 500 → debe disparar la IA.
      // ENTRADA: baseline ruido=820; lectura ruido=1400.
      // RESULTADO ESPERADO: true.
      final db = _FakeDatabaseService();
      final base = DateTime(2025, 6, 1, 14, 0);
      db.setRawReadings(
          _generarLecturasDiurnas(40, base, 0.3, 820));

      final service = BaselineService(
          db, clock: () => DateTime(2025, 6, 1, 14, 30));
      await service.iniciar();

      expect(service.esDesviacionSignificativa(1400, 0.3), isTrue);
      service.detener();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-26
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '26: lectura dentro de ambos umbrales no dispara desviación', () async {
      // ESCENARIO REAL: Lectura con pequeñas variaciones que no son anómalas.
      // ENTRADA: baseline flujo=0.3, ruido=820; lectura flujo=0.45, ruido=900
      //   → ΔFlujo = 0.15 < 0.30; ΔRuido = 80 < 500.
      // RESULTADO ESPERADO: false.
      final db = _FakeDatabaseService();
      final base = DateTime(2025, 6, 1, 14, 0);
      db.setRawReadings(
          _generarLecturasDiurnas(40, base, 0.3, 820));

      final service = BaselineService(
          db, clock: () => DateTime(2025, 6, 1, 14, 30));
      await service.iniciar();

      expect(service.esDesviacionSignificativa(900, 0.45), isFalse);
      service.detener();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-27
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '27: flujoBaselineActual retorna el promedio diurno a las 14:00 '
        'y el nocturno a las 02:00', () async {
      // ESCENARIO REAL: El baseline tiene promedios distintos para día/noche.
      // A las 14:00 se usa el promedio diurno (0.5 L/min);
      // a las 02:00 se usa el nocturno (0.05 L/min).
      // ENTRADA: 20 lecturas diurnas @ flujo=0.5; 20 lecturas nocturnas @ flujo=0.05.
      final db = _FakeDatabaseService();
      final baseDia = DateTime(2025, 6, 1, 14, 0);
      final baseNoche = DateTime(2025, 6, 1, 3, 0);

      final lecturasDia =
          _generarLecturasDiurnas(20, baseDia, 0.5, 820);
      final lecturasNoche =
          _generarLecturasNocturnas(20, baseNoche, 0.05, 400);
      db.setRawReadings([...lecturasDia, ...lecturasNoche]);

      // A las 14:00 → usa baseline diurno
      final serviceDia = BaselineService(
          db, clock: () => DateTime(2025, 6, 1, 14, 0));
      await serviceDia.iniciar();
      expect(serviceDia.flujoBaselineActual,
          isNotNull);
      expect(serviceDia.flujoBaselineActual!,
          closeTo(0.5, 0.05));
      serviceDia.detener();

      // A las 02:00 → usa baseline nocturno
      final serviceNoche = BaselineService(
          db, clock: () => DateTime(2025, 6, 1, 2, 0));
      await serviceNoche.iniciar();
      expect(serviceNoche.flujoBaselineActual,
          isNotNull);
      expect(serviceNoche.flujoBaselineActual!,
          closeTo(0.05, 0.01));
      serviceNoche.detener();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-28
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '28: reconstrucción del baseline tras cambio de usuario '
        'refleja exclusivamente las lecturas del nuevo usuario', () async {
      // ESCENARIO REAL: Usuario A usa el sistema. Luego se loguea Usuario B
      // con un patrón de uso muy diferente. El baseline debe actualizarse.
      // ENTRADA: baseline inicial con flujo=0.3; tras reconstrucción, flujo=2.0.
      // RESULTADO ESPERADO: flujoBaselineActual refleja el nuevo promedio (≈2.0).
      final db = _FakeDatabaseService();
      final base = DateTime(2025, 6, 1, 14, 0);

      // Baseline de usuario A
      db.setRawReadings(
          _generarLecturasDiurnas(40, base, 0.3, 820));
      final service = BaselineService(
          db, clock: () => DateTime(2025, 6, 1, 14, 30));
      await service.iniciar();
      final flujoA = service.flujoBaselineActual;
      expect(flujoA, closeTo(0.3, 0.05));

      // Cambio a usuario B con flujo muy diferente
      db.setRawReadings(
          _generarLecturasDiurnas(40, base, 2.0, 1200));
      await service.reconstruirBaseline();
      final flujoB = service.flujoBaselineActual;
      expect(flujoB, closeTo(2.0, 0.1));

      service.detener();
    });
  });
}
