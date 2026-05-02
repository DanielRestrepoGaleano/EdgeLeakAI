import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/lectura_raw_model.dart';
import '../models/lectura_resumen_model.dart';
import '../models/historial_mensual_model.dart';
import 'database_service.dart';

/// Servicio de perfilado de usuario en segundo plano.
///
/// Responsabilidades:
/// 1. Construir y mantener un **Baseline** (línea base) del comportamiento
///    normal del usuario a partir de las lecturas crudas de los últimos
///    [_diasBaseline] días, segmentado por bloque horario (día/noche).
/// 2. Detectar **desviaciones significativas** respecto al baseline que
///    justifiquen invocar a la IA de Groq.
/// 3. Ejecutar la **agregación de datos** de forma transparente:
///    - Cada [_intervaloAgregacion] consolida las lecturas crudas en un
///      resumen de 5 días ([LecturaResumenModel]).
///    - Al acumular [_resumenesPorMes] resúmenes, se genera un
///      [HistorialMensualModel] y los resúmenes individuales se eliminan
///      para optimizar la BD.
class BaselineService {
  final DatabaseService _db;

  // ── Parámetros de perfilado ─────────────────────────────────────────────────

  /// Número de días históricos usados para calcular el baseline.
  static const int _diasBaseline = 5;

  /// Número de resúmenes de 5 días que se agrupan en un historial mensual.
  static const int _resumenesPorMes = 5;

  /// Desviación mínima de flujo (L/min) para considerar una lectura anómala.
  static const double _umbralDesviacionFlujo = 0.30;

  /// Desviación mínima de ruido (ADC) para considerar una lectura anómala.
  static const double _umbralDesviacionRuido = 500.0;

  /// Período de ejecución del job de agregación en segundo plano.
  static const Duration _intervaloAgregacion = Duration(hours: 24);

  // ── Estado interno ──────────────────────────────────────────────────────────

  double? _baselineFlujoPromedioDia;
  double? _baselineFlujoPromedioNoche;
  double? _baselineRuidoPromedioDia;
  double? _baselineRuidoPromedioNoche;
  bool _baselineListo = false;

  Timer? _timerAgregacion;

  // ---------------------------------------------------------------------------
  // Ciclo de vida
  // ---------------------------------------------------------------------------

  BaselineService(this._db);

  /// Inicia el servicio: construye el baseline inicial y programa el job de
  /// agregación periódico.
  Future<void> iniciar() async {
    await _construirBaseline();
    _timerAgregacion = Timer.periodic(
      _intervaloAgregacion,
      (_) => _ejecutarAgregacion(),
    );
    debugPrint('[BaselineService] ✅ Servicio iniciado.');
  }

  /// Detiene el timer de agregación en segundo plano.
  void detener() {
    _timerAgregacion?.cancel();
    _timerAgregacion = null;
    debugPrint('[BaselineService] 🔴 Servicio detenido.');
  }

  // ---------------------------------------------------------------------------
  // Baseline
  // ---------------------------------------------------------------------------

  /// Construye la línea base a partir de las lecturas crudas de los últimos
  /// [_diasBaseline] días. Segmenta día (6:00–22:00) y noche (22:00–6:00).
  Future<void> _construirBaseline() async {
    try {
      final lecturas = await _db.obtenerLecturasRawRecientes(dias: _diasBaseline);

      if (lecturas.length < 30) {
        debugPrint(
            '[BaselineService] ⚠️ Datos insuficientes para baseline (${lecturas.length} lecturas). Se requieren al menos 30.');
        return;
      }

      final lecturasDia =
          lecturas.where((l) => _esDia(l.timestamp)).toList();
      final lecturasNoche =
          lecturas.where((l) => !_esDia(l.timestamp)).toList();

      if (lecturasDia.isNotEmpty) {
        _baselineFlujoPromedioDia = _promedio(lecturasDia.map((l) => l.flujo));
        _baselineRuidoPromedioDia =
            _promedio(lecturasDia.map((l) => l.ruido.toDouble()));
      }

      if (lecturasNoche.isNotEmpty) {
        _baselineFlujoPromedioNoche =
            _promedio(lecturasNoche.map((l) => l.flujo));
        _baselineRuidoPromedioNoche =
            _promedio(lecturasNoche.map((l) => l.ruido.toDouble()));
      }

      _baselineListo = true;

      debugPrint('[BaselineService] 📊 Baseline construido con ${lecturas.length} lecturas.');
      debugPrint(
          '  Día  → flujo: ${_baselineFlujoPromedioDia?.toStringAsFixed(3)} | ruido: ${_baselineRuidoPromedioDia?.toStringAsFixed(0)}');
      debugPrint(
          '  Noche → flujo: ${_baselineFlujoPromedioNoche?.toStringAsFixed(3)} | ruido: ${_baselineRuidoPromedioNoche?.toStringAsFixed(0)}');
    } catch (e) {
      debugPrint('[BaselineService] ❌ Error al construir baseline: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Detección de desviación
  // ---------------------------------------------------------------------------

  /// Retorna [true] si la lectura actual desvía significativamente del baseline
  /// del período correspondiente (día o noche).
  bool esDesviacionSignificativa(int ruido, double flujo) {
    if (!_baselineListo) return true; // Sin baseline: conservar y escalar

    final esNoche = !_esDia(DateTime.now());

    final flujoBase = esNoche
        ? (_baselineFlujoPromedioNoche ?? flujo)
        : (_baselineFlujoPromedioDia ?? flujo);
    final ruidoBase = esNoche
        ? (_baselineRuidoPromedioNoche ?? ruido.toDouble())
        : (_baselineRuidoPromedioDia ?? ruido.toDouble());

    final devFlujo = (flujo - flujoBase).abs();
    final devRuido = (ruido - ruidoBase).abs();

    final desvia =
        devFlujo > _umbralDesviacionFlujo || devRuido > _umbralDesviacionRuido;

    if (desvia) {
      debugPrint(
          '[BaselineService] 🔔 Desviación: flujo Δ${devFlujo.toStringAsFixed(3)} | ruido Δ${devRuido.toStringAsFixed(0)}');
    }

    return desvia;
  }

  /// Retorna el flujo baseline del período actual (día/noche) o [null] si no
  /// está disponible.
  double? get flujoBaselineActual {
    if (!_baselineListo) return null;
    return _esDia(DateTime.now())
        ? _baselineFlujoPromedioDia
        : _baselineFlujoPromedioNoche;
  }

  /// Retorna el ruido baseline del período actual (día/noche) o [null] si no
  /// está disponible.
  double? get ruidoBaselineActual {
    if (!_baselineListo) return null;
    return _esDia(DateTime.now())
        ? _baselineRuidoPromedioDia
        : _baselineRuidoPromedioNoche;
  }

  bool get baselineListo => _baselineListo;

  // ---------------------------------------------------------------------------
  // Agregación en segundo plano
  // ---------------------------------------------------------------------------

  /// Consolida las lecturas crudas en resúmenes de 5 días y, si hay suficientes
  /// resúmenes, crea un historial mensual.
  Future<void> _ejecutarAgregacion() async {
    debugPrint('[BaselineService] ⚙️ Iniciando ciclo de agregación...');
    try {
      await _agregarLecturasEnResumen();
      await _construirBaseline(); // Recalcular baseline con datos actualizados
      await _consolidarHistorialMensual();
    } catch (e) {
      debugPrint('[BaselineService] ❌ Error en agregación: $e');
    }
  }

  Future<void> _agregarLecturasEnResumen() async {
    final fechaFin = DateTime.now();
    final fechaInicio = fechaFin.subtract(const Duration(days: 5));

    final lecturas = await _db.obtenerLecturasRawEnRango(
      desde: fechaInicio,
      hasta: fechaFin,
    );

    if (lecturas.isEmpty) {
      debugPrint('[BaselineService] No hay lecturas crudas para agregar.');
      return;
    }

    final flujoPromedio = _promedio(lecturas.map((l) => l.flujo));
    final ruidoPromedio = _promedio(lecturas.map((l) => l.ruido.toDouble()));

    final conteos = <String, int>{};
    for (final l in lecturas) {
      conteos[l.estado] = (conteos[l.estado] ?? 0) + 1;
    }
    final estadoPredominante =
        conteos.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final resumen = LecturaResumenModel(
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      flujoPromedio: flujoPromedio,
      ruidoPromedio: ruidoPromedio,
      totalLecturas: lecturas.length,
      estadoPredominante: estadoPredominante,
    );

    await _db.insertarResumen5d(resumen);
    debugPrint(
        '[BaselineService] 📦 Resumen 5d guardado: ${lecturas.length} lecturas → estado: $estadoPredominante');
  }

  Future<void> _consolidarHistorialMensual() async {
    final resumenes = await _db.obtenerResumenes5d(limit: _resumenesPorMes + 1);

    if (resumenes.length < _resumenesPorMes) {
      debugPrint(
          '[BaselineService] Resúmenes disponibles: ${resumenes.length}/${_resumenesPorMes}. No se consolida aún.');
      return;
    }

    final candidatos = resumenes.take(_resumenesPorMes).toList();

    final flujoPromedio =
        _promedio(candidatos.map((r) => r.flujoPromedio));
    final ruidoPromedio =
        _promedio(candidatos.map((r) => r.ruidoPromedio));

    final mensual = HistorialMensualModel(
      fechaInicio: candidatos.last.fechaInicio,
      fechaFin: candidatos.first.fechaFin,
      numAnomalias: candidatos
          .where((r) => r.estadoPredominante.toLowerCase().contains('anomal'))
          .length,
      numFugas: candidatos
          .where((r) => r.estadoPredominante.toLowerCase().contains('fuga'))
          .length,
      flujoPromedio: flujoPromedio,
      ruidoPromedio: ruidoPromedio,
      resumenJson: {
        'bloques': candidatos.map((r) => r.toMap()).toList(),
      },
    );

    await _db.insertarHistorialMensual(mensual);
    await _db.eliminarResumenes5d(candidatos.map((r) => r.id!).toList());

    debugPrint('[BaselineService] 📅 Historial mensual consolidado.');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static bool _esDia(DateTime dt) => dt.hour >= 6 && dt.hour < 22;

  static double _promedio(Iterable<double> valores) {
    final lista = valores.toList();
    if (lista.isEmpty) return 0.0;
    return lista.reduce((a, b) => a + b) / lista.length;
  }

  /// Reconstruye el baseline de forma explícita (llamar tras un cambio de usuario).
  Future<void> reconstruirBaseline() async => _construirBaseline();

  /// Devuelve los últimos resúmenes de 5 días disponibles para contexto de la IA.
  Future<List<LecturaResumenModel>> obtenerContextoIA({int limit = 3}) async {
    return _db.obtenerResumenes5d(limit: limit);
  }

  /// Devuelve el último historial mensual para contexto de la IA.
  Future<HistorialMensualModel?> obtenerUltimoMensual() async {
    final lista = await _db.obtenerHistorialesMensuales(limit: 1);
    return lista.isNotEmpty ? lista.first : null;
  }
}
