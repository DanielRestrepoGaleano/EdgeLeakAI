import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/models/lectura_sensor_model.dart';
import '../data/models/alerta_fuga_model.dart';
import '../data/models/lectura_raw_model.dart';
import '../data/services/groq_api_service.dart';
import '../data/services/database_service.dart';
import '../data/services/local_api_service.dart';
import '../data/services/email_service.dart';

class DashboardController extends ChangeNotifier {
  final GroqApiService _apiService = GroqApiService();
  final DatabaseService _dbService = DatabaseService();
  final EmailService _emailService = EmailService();
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

  // --- Sensor Fusion ---
  String _estadoActual = 'Sin datos';
  String get estadoActual => _estadoActual;

  final List<Map<String, dynamic>> _bufferLecturas = [];
  List<Map<String, dynamic>> get bufferLecturas =>
      List.unmodifiable(_bufferLecturas);

  // --- Regla de los 3 Strikes ---
  int strikesFuga = 0;

  // Umbrales de Sensor Fusion
  static const int _umbralRuido = 1500;
  static const double _umbralFlujoFuga = 0.1;

  DashboardController() {
    _localApiService = LocalApiService(
      onProcesarLectura: procesarLecturaSensor,
      onEstadoActual: () => _estadoActual,
      dbService: _dbService,
    );
    _localApiService.iniciar();
  }

  void setUsuarioLogueado(String nombre, {String correo = ''}) {
    usuarioLogueado = nombre;
    correoUsuarioActual = correo;
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
  // Sensor Fusion con regla de 3 Strikes (lecturas del ESP32)
  // ---------------------------------------------------------------------------

  bool _esPosibleFuga(int ruido, double flujo) =>
      ruido > _umbralRuido && flujo < _umbralFlujoFuga;

  Future<void> procesarLecturaSensor(int ruido, double flujo) async {
    final DateTime timestampLectura = DateTime.now();

    ruidoActual = ruido;
    caudalActual = flujo;

    // 1. Sensor Fusion — determinar estado
    final String estado =
        _esPosibleFuga(ruido, flujo) ? 'Posible Fuga' : 'Uso Normal';
    _estadoActual = estado;

    // 2. Regla de los 3 Strikes
    if (_esPosibleFuga(ruido, flujo)) {
      strikesFuga++;
    } else {
      strikesFuga = 0;
    }

    if (strikesFuga >= 3 && !iaProcesando) {
      strikesFuga = 0;
      // Llamar a la IA en background; errores no deben bloquear la lectura
      _llamarGroqPorFuga(flujo, timestampLectura).catchError((e) {
        debugPrint('[DashboardController] Error al llamar a Groq: $e');
      });
    }

    // 3. Guardar lectura cruda en BD
    await _dbService.insertarLecturaRaw(
      LecturaRawModel(
        ruido: ruido,
        flujo: flujo,
        estado: estado,
        timestamp: timestampLectura,
      ),
    );

    // 4. Actualizar buffer en memoria (máximo 10 lecturas)
    _bufferLecturas.add({
      'ruido': ruido,
      'flujo': flujo,
      'estado': estado,
      'timestamp': timestampLectura.toIso8601String(),
    });
    if (_bufferLecturas.length > 10) {
      _bufferLecturas.removeAt(0);
    }

    notifyListeners();
  }

  Future<void> _llamarGroqPorFuga(double flujo, DateTime timestamp) async {
    iaProcesando = true;
    ultimaAlerta = null;
    notifyListeners();

    final lectura = LecturaSensorModel(caudalLPM: flujo, timestamp: timestamp);
    final respuestaIA = await _apiService.analizarPatronReal(lectura);

    if (respuestaIA.veredicto != 'Error de Red / IA') {
      await _dbService.insertarAlerta(respuestaIA);

      // Enviar correo de alerta si la IA confirma fuga crítica
      if ((respuestaIA.veredicto == 'Fuga Detectada' ||
              respuestaIA.severidad == 'Crítica') &&
          correoUsuarioActual.isNotEmpty) {
        await _emailService.enviarCorreoAlerta(correoUsuarioActual, respuestaIA);
      }
    }

    ultimaAlerta = respuestaIA;
    await inicializarHistorial();
    iaProcesando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _localApiService.detener();
    super.dispose();
  }
}

