import 'package:flutter/foundation.dart';
import '../data/models/estado_sensor.dart';
import '../data/models/lectura_sensor_model.dart';
import '../data/models/alerta_fuga_model.dart';
import '../data/models/lectura_raw_model.dart';
import '../data/services/groq_api_service.dart';
import '../data/services/database_service.dart';
import '../data/services/local_api_service.dart';
import '../data/services/email_service.dart';
import '../data/services/ruido_filter_service.dart';
import '../data/services/baseline_service.dart';
import '../config/time_provider.dart';

class DashboardController extends ChangeNotifier {
  final GroqApiService _apiService;
  final DatabaseService _dbService;
  final EmailService _emailService;
  final RuidoFilterService _ruidoFilter;
  late final BaselineService _baselineService;
  late final LocalApiService _localApiService;

  /// Proveedor de tiempo inyectable para habilitar time-travelling en tests.
  final TimeProvider _clock;

  double caudalActual = 0.0;
  int ruidoActual = 0;

  /// Último valor de picos acústicos recibido del ESP32.
  int picosActual = 0;

  bool conectado = true;
  bool iaProcesando = false;

  String usuarioLogueado = 'Usuario';
  String correoUsuarioActual = '';

  AlertaFugaModel? ultimaAlerta;
  List<AlertaFugaModel> historialEventos = [];

  // --- Filtros del historial ---
  String? filtroSeveridad;
  DateTime? filtroDesde;
  DateTime? filtroHasta;
  int _historialOffset = 0;
  static const int _historialPageSize = 20;
  bool hayMasHistorial = false;

  // --- Selección múltiple en historial ---
  final Set<int> seleccionados = {};
  bool modoSeleccion = false;

  // --- Máquina de estados de 3 niveles ---
  EstadoSensor _estadoActual = EstadoSensor.normal;
  EstadoSensor get estadoActual => _estadoActual;

  final List<Map<String, dynamic>> _bufferLecturas = [];
  List<Map<String, dynamic>> get bufferLecturas =>
      List.unmodifiable(_bufferLecturas);

  // --- Regla de los 3 Strikes (anomalía/fuga basada en flujo o ruido) ---
  int strikesFuga = 0;

  // --- Strikes nocturnos (lógica nocturna v2 basada en picos acústicos) ---
  int strikesNocturnos = 0;

  // Umbrales de Sensor Fusion
  static const double _umbralFlujoAnomalia = 7.0;
  static const double _umbralFlujoFuga = 8.0;

  // ── Ventana de picos para lógica nocturna v2 ────────────────────────────────

  final List<({DateTime timestamp, int picos})> _picosVentana = [];
  static const Duration _duracionVentanaPicos = Duration(seconds: 60);

  /// Umbral de micro-picos acústicos en ventana de 60 s para activar la
  /// detección de goteo nocturno silencioso.
  ///
  /// Calibración empírica: distingue ruido ambiental (~800–900 ADC,
  /// ≤ 10 picos/60 s) de goteo real en boquilla sin caudal (≥ 12 picos/60 s
  /// a las 3:00 AM con flujo == 0.0). Ver tests 37, 38, 45, 46.
  static const int umbralPicosNocturnos = 12;

  DashboardController({
    GroqApiService? groqApiService,
    DatabaseService? dbService,
    EmailService? emailService,
    RuidoFilterService? ruidoFilter,
    BaselineService? baselineService,
    LocalApiService? localApiService,
    TimeProvider? clock,
  })  : _apiService = groqApiService ?? GroqApiService(),
        _dbService = dbService ?? DatabaseService(),
        _emailService = emailService ?? EmailService(),
        _ruidoFilter = ruidoFilter ?? RuidoFilterService(),
        _clock = clock ?? DateTime.now {
    _baselineService = baselineService ?? BaselineService(_dbService);
    _localApiService = localApiService ??
        LocalApiService(
          onProcesarLectura: procesarLecturaSensor,
          onEstadoActual: () => _estadoActual.etiqueta,
          dbService: _dbService,
        );
    _localApiService.iniciar();
    _baselineService.iniciar();
  }

  void setUsuarioLogueado(String nombre, {String correo = ''}) {
    usuarioLogueado = nombre;
    correoUsuarioActual = correo;
    _baselineService.reconstruirBaseline();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Historial con filtros y paginación
  // ---------------------------------------------------------------------------

  Future<void> inicializarHistorial() async {
    _historialOffset = 0;
    historialEventos = await _dbService.obtenerHistorialFiltrado(
      severidad: filtroSeveridad,
      desde: filtroDesde,
      hasta: filtroHasta,
      limit: _historialPageSize + 1,
      offset: 0,
    );

    if (historialEventos.length > _historialPageSize) {
      historialEventos = historialEventos.sublist(0, _historialPageSize);
      hayMasHistorial = true;
    } else {
      hayMasHistorial = false;
    }

    _historialOffset = historialEventos.length;
    seleccionados.clear();
    modoSeleccion = false;
    notifyListeners();
  }

  Future<void> cargarMasHistorial() async {
    final mas = await _dbService.obtenerHistorialFiltrado(
      severidad: filtroSeveridad,
      desde: filtroDesde,
      hasta: filtroHasta,
      limit: _historialPageSize + 1,
      offset: _historialOffset,
    );

    if (mas.length > _historialPageSize) {
      historialEventos.addAll(mas.sublist(0, _historialPageSize));
      hayMasHistorial = true;
    } else {
      historialEventos.addAll(mas);
      hayMasHistorial = false;
    }

    _historialOffset = historialEventos.length;
    notifyListeners();
  }

  void aplicarFiltros({
    String? severidad,
    DateTime? desde,
    DateTime? hasta,
  }) {
    filtroSeveridad = severidad;
    filtroDesde = desde;
    filtroHasta = hasta;
    inicializarHistorial();
  }

  void limpiarFiltros() {
    filtroSeveridad = null;
    filtroDesde = null;
    filtroHasta = null;
    inicializarHistorial();
  }

  // ---------------------------------------------------------------------------
  // Eliminación de alertas
  // ---------------------------------------------------------------------------

  Future<void> eliminarAlerta(int id) async {
    await _dbService.eliminarAlerta(id);
    seleccionados.remove(id);
    await inicializarHistorial();
  }

  Future<void> eliminarAlertasSeleccionadas() async {
    await _dbService.eliminarAlertas(seleccionados.toList());
    seleccionados.clear();
    modoSeleccion = false;
    await inicializarHistorial();
  }

  void toggleSeleccion(int id) {
    if (seleccionados.contains(id)) {
      seleccionados.remove(id);
    } else {
      seleccionados.add(id);
    }
    if (seleccionados.isEmpty) modoSeleccion = false;
    notifyListeners();
  }

  void activarModoSeleccion(int idInicial) {
    modoSeleccion = true;
    seleccionados.add(idInicial);
    notifyListeners();
  }

  void cancelarSeleccion() {
    seleccionados.clear();
    modoSeleccion = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Ventana de picos (lógica nocturna v2)
  // ---------------------------------------------------------------------------

  void _actualizarVentanaPicos(int picos, DateTime ahora) {
    _picosVentana.add((timestamp: ahora, picos: picos));
    _picosVentana.removeWhere(
        (e) => ahora.difference(e.timestamp) > _duracionVentanaPicos);
  }

  int _sumaPicosVentana() =>
      _picosVentana.fold(0, (sum, e) => sum + e.picos);

  /// Retorna [true] si se cumplen las condiciones de la Lógica Nocturna v2:
  /// - Hora nocturna (0:00–6:00 exclusive).
  /// - Flujo == 0.0 (el sensor de flujo no reacciona al goteo silencioso).
  /// - Suma de picos en la ventana de 60 s supera [umbralPicosNocturnos].
  bool _esAnomaliaNoct_v2(double flujo, DateTime ahora) {
    final hora = ahora.hour;
    final esNoche = hora >= 0 && hora < 6;
    if (!esNoche || flujo != 0.0) return false;
    return _sumaPicosVentana() > umbralPicosNocturnos;
  }

  // ---------------------------------------------------------------------------
  // Máquina de estados de 3 niveles + filtro de ruido + baseline
  // ---------------------------------------------------------------------------

  /// Clasifica el estado del sensor aplicando la jerarquía de 3 niveles,
  /// el filtro de ruido digital y la lógica nocturna v2 basada en picos.
  EstadoSensor _clasificarEstado(
      int ruido, double flujo, bool anomaliaNoctV2) {
    // Nivel 3: Fuga activa — caudal crítico, sin importar el ruido
    if (flujo >= _umbralFlujoFuga) return EstadoSensor.fuga;

    // Análisis de patrón de ruido
    final resultadoRuido = _ruidoFilter.clasificar(ruido, flujo);

    // Nivel 2: Anomalía — flujo intermedio, patrón de goteo ADC, o lógica nocturna
    if (flujo >= _umbralFlujoAnomalia ||
        resultadoRuido == ResultadoRuido.patronGoteo ||
        anomaliaNoctV2) {
      return EstadoSensor.anomalia;
    }

    // Nivel 1: Normal
    return EstadoSensor.normal;
  }

  Future<void> procesarLecturaSensor(int ruido, double flujo, int picos) async {
    final DateTime timestampLectura = _clock();

    ruidoActual = ruido;
    caudalActual = flujo;
    picosActual = picos;
    conectado = true;

    // Actualizar ventana de picos antes de clasificar
    _actualizarVentanaPicos(picos, timestampLectura);
    final bool anomaliaNoctV2 = _esAnomaliaNoct_v2(flujo, timestampLectura);

    // 1. Clasificar estado con la máquina de 3 niveles
    final EstadoSensor nuevoEstado =
        _clasificarEstado(ruido, flujo, anomaliaNoctV2);
    final bool cambioDeEstado = nuevoEstado != _estadoActual;

    _estadoActual = nuevoEstado;

    // 2. Actualizar contadores de strikes
    if (nuevoEstado != EstadoSensor.normal) {
      if (anomaliaNoctV2) {
        // Ruta nocturna por picos: usa su propio contador
        strikesNocturnos++;
      } else {
        // Ruta regular (flujo/ruido/ADC): incrementa el contador general
        strikesFuga++;
        strikesNocturnos = 0;
      }
    } else {
      strikesFuga = 0;
      strikesNocturnos = 0;
    }

    // ⚡ Notificar INMEDIATAMENTE para que la UI refleje el estado en tiempo real
    notifyListeners();

    // 3. Enviar correo inmediato al detectar cambio a Anomalía o Fuga
    if (cambioDeEstado &&
        nuevoEstado != EstadoSensor.normal &&
        correoUsuarioActual.isNotEmpty) {
      _enviarCorreoEstadoCambiado(nuevoEstado, flujo, ruido, timestampLectura)
          .catchError((e) {
        debugPrint('[DashboardController] Error al enviar correo de estado: $e');
      });
    }

    // 4a. Invocar IA — Ruta regular (desviación del baseline o Fuga directa)
    final bool desviaBaseline =
        _baselineService.esDesviacionSignificativa(ruido, flujo);

    if ((strikesFuga >= 3 ||
            (cambioDeEstado && nuevoEstado == EstadoSensor.fuga)) &&
        !iaProcesando &&
        desviaBaseline) {
      if (nuevoEstado != EstadoSensor.normal) {
        strikesFuga = 0;
        _invocarGroqPorEvento(ruido, flujo, picos, nuevoEstado,
                timestampLectura, esNocturno: false)
            .catchError((e) {
          debugPrint('[DashboardController] Error al llamar a Groq: $e');
        });
      }
    }

    // 4b. Invocar IA — Ruta nocturna por picos (3 strikes nocturnos)
    if (strikesNocturnos >= 3 && !iaProcesando) {
      strikesNocturnos = 0;
      _invocarGroqPorEvento(ruido, flujo, picos, EstadoSensor.anomalia,
              timestampLectura, esNocturno: true)
          .catchError((e) {
        debugPrint('[DashboardController] Error al llamar a Groq nocturno: $e');
      });
    }

    // 5. Guardar lectura cruda en BD con el estado real y picos
    await _dbService.insertarLecturaRaw(
      LecturaRawModel(
        ruido: ruido,
        flujo: flujo,
        estado: nuevoEstado.etiqueta,
        timestamp: timestampLectura,
        picos: picos,
      ),
    );

    // 6. Actualizar buffer en memoria (máximo 10 lecturas)
    _bufferLecturas.add({
      'ruido': ruido,
      'flujo': flujo,
      'picos': picos,
      'estado': nuevoEstado.etiqueta,
      'timestamp': timestampLectura.toIso8601String(),
    });
    if (_bufferLecturas.length > 10) {
      _bufferLecturas.removeAt(0);
    }
  }

  // ---------------------------------------------------------------------------
  // Invocación event-driven a Groq
  // ---------------------------------------------------------------------------

  Future<void> _invocarGroqPorEvento(
    int ruido,
    double flujo,
    int picos,
    EstadoSensor estadoLocal,
    DateTime timestamp, {
    bool esNocturno = false,
  }) async {
    iaProcesando = true;
    ultimaAlerta = null;
    notifyListeners();

    try {
      // Construir contexto histórico
      final resumenes = await _baselineService.obtenerContextoIA(limit: 3);
      final mensual = await _baselineService.obtenerUltimoMensual();

      final contexto = <String, dynamic>{
        'resumenes_5d': resumenes.map((r) => r.toContextString()).toList(),
        if (mensual != null) 'historial_mensual': mensual.toContextString(),
        if (_baselineService.flujoBaselineActual != null)
          'flujo_baseline':
              _baselineService.flujoBaselineActual!.toStringAsFixed(3),
        if (_baselineService.ruidoBaselineActual != null)
          'ruido_baseline':
              _baselineService.ruidoBaselineActual!.toStringAsFixed(0),
        'picos': picos,
        'suma_picos_ventana': _sumaPicosVentana(),
        'periodo_activo': esNocturno ? 'nocturno' : 'diurno',
      };

      final lectura = LecturaSensorModel(
        caudalLPM: flujo,
        ruido: ruido,
        picos: picos,
        timestamp: timestamp,
      );

      final respuestaIA = await _apiService.analizarConContexto(
        lectura: lectura,
        estadoLocal: estadoLocal,
        contexto: contexto,
      );

      // Persistir en historial con estado real
      await _dbService.insertarAlerta(respuestaIA);

      // Enviar correo si la IA confirma anomalía o fuga
      final estadoIA = EstadoSensor.fromEtiqueta(respuestaIA.veredicto);
      if (estadoIA != EstadoSensor.normal && correoUsuarioActual.isNotEmpty) {
        final enviado = await _emailService.enviarCorreoAlerta(
            correoUsuarioActual, respuestaIA);
        if (!enviado) {
          debugPrint(
              '[DashboardController] ⚠️ Correo de alerta no pudo enviarse a $correoUsuarioActual');
        }
      }

      ultimaAlerta = respuestaIA;
      await inicializarHistorial();
    } catch (e) {
      debugPrint('[DashboardController] Error al llamar a Groq: $e');
    } finally {
      iaProcesando = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Envío de correo inmediato por cambio de estado (antes de confirmar con IA)
  // ---------------------------------------------------------------------------

  Future<void> _enviarCorreoEstadoCambiado(
    EstadoSensor estado,
    double flujo,
    int ruido,
    DateTime timestamp,
  ) async {
    // Crear una alerta preliminar basada en la clasificación local (edge)
    final alertaPrevia = AlertaFugaModel(
      veredicto: estado.veredicto,
      severidad: estado.severidad,
      mensaje:
          'Clasificación preliminar edge. Flujo: ${flujo.toStringAsFixed(3)} L/min | '
          'Ruido: $ruido ADC. Análisis IA en curso.',
      fecha: timestamp,
    );

    await _emailService.enviarCorreoAlerta(correoUsuarioActual, alertaPrevia);
  }

  @override
  void dispose() {
    _localApiService.detener();
    _baselineService.detener();
    super.dispose();
  }
}
