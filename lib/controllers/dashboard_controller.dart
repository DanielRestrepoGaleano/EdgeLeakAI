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

class DashboardController extends ChangeNotifier {
  final GroqApiService _apiService = GroqApiService();
  final DatabaseService _dbService = DatabaseService();
  final EmailService _emailService = EmailService();
  final RuidoFilterService _ruidoFilter = RuidoFilterService();
  late final BaselineService _baselineService;
  late final LocalApiService _localApiService;

  double caudalActual = 0.0;
  int ruidoActual = 0;
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

  // --- Regla de los 3 Strikes ---
  int strikesFuga = 0;

  // Umbrales de Sensor Fusion
  static const double _umbralFlujoAnomalia = 0.5;
  static const double _umbralFlujoFuga = 5.0;

  DashboardController() {
    _baselineService = BaselineService(_dbService);
    _localApiService = LocalApiService(
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
  // Máquina de estados de 3 niveles + filtro de ruido + baseline
  // ---------------------------------------------------------------------------

  /// Clasifica el estado del sensor aplicando la jerarquía de 3 niveles y el
  /// filtro de ruido digital. La lógica nocturna se delega en [RuidoFilterService].
  EstadoSensor _clasificarEstado(int ruido, double flujo) {
    // Nivel 3: Fuga activa — caudal crítico, sin importar el ruido
    if (flujo > _umbralFlujoFuga) return EstadoSensor.fuga;

    // Análisis de patrón de ruido
    final resultadoRuido = _ruidoFilter.clasificar(ruido, flujo);

    // Nivel 2: Anomalía — flujo intermedio O patrón de goteo
    if (flujo > _umbralFlujoAnomalia ||
        resultadoRuido == ResultadoRuido.patronGoteo) {
      return EstadoSensor.anomalia;
    }

    // Nivel 1: Normal
    return EstadoSensor.normal;
  }

  Future<void> procesarLecturaSensor(int ruido, double flujo) async {
    final DateTime timestampLectura = DateTime.now();

    ruidoActual = ruido;
    caudalActual = flujo;
    conectado = true;

    // 1. Clasificar estado con la máquina de 3 niveles
    final EstadoSensor nuevoEstado = _clasificarEstado(ruido, flujo);
    final bool cambioDeEstado = nuevoEstado != _estadoActual;

    _estadoActual = nuevoEstado;

    // 2. Regla de los 3 Strikes (para Anomalía y Fuga)
    if (nuevoEstado != EstadoSensor.normal) {
      strikesFuga++;
    } else {
      strikesFuga = 0;
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

    // 4. Invocar IA solo por evento (desviación del baseline O 3 strikes), no por polling
    final bool desviaBaseline =
        _baselineService.esDesviacionSignificativa(ruido, flujo);

    if ((strikesFuga >= 3 || (cambioDeEstado && nuevoEstado == EstadoSensor.fuga)) &&
        !iaProcesando &&
        desviaBaseline) {
      if (nuevoEstado != EstadoSensor.normal) {
        strikesFuga = 0;
        _invocarGroqPorEvento(ruido, flujo, nuevoEstado, timestampLectura)
            .catchError((e) {
          debugPrint('[DashboardController] Error al llamar a Groq: $e');
        });
      }
    }

    // 5. Guardar lectura cruda en BD con el estado real (no siempre 'Normal')
    await _dbService.insertarLecturaRaw(
      LecturaRawModel(
        ruido: ruido,
        flujo: flujo,
        estado: nuevoEstado.etiqueta,
        timestamp: timestampLectura,
      ),
    );

    // 6. Actualizar buffer en memoria (máximo 10 lecturas)
    _bufferLecturas.add({
      'ruido': ruido,
      'flujo': flujo,
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
    EstadoSensor estadoLocal,
    DateTime timestamp,
  ) async {
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
      };

      final lectura = LecturaSensorModel(
        caudalLPM: flujo,
        ruido: ruido,
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

