import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/lectura_sensor_model.dart';
import '../data/models/alerta_fuga_model.dart';
import '../data/models/lectura_raw_model.dart';
import '../data/services/groq_api_service.dart';
import '../data/services/database_service.dart';
import '../data/services/local_api_service.dart';

class DashboardController extends ChangeNotifier {
  final GroqApiService _apiService = GroqApiService();
  final DatabaseService _dbService = DatabaseService();
  late final LocalApiService _localApiService;

  double caudalActual = 0.0;
  bool conectado = true;
  bool iaProcesando = false;
  String modoSimulacion = 'Normal';

  String usuarioLogueado = 'Usuario';

  AlertaFugaModel? ultimaAlerta;
  List<AlertaFugaModel> historialEventos = [];
  Timer? _simuladorTimer;

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

  // --- Rate-limit para Groq ---
  int _contadorPosibleFuga = 0;
  DateTime? _lastGroqEvaluation;

  static const int _umbralFugasConsecutivas = 3;
  static const int _cooldownMinutos = 3;

  // Umbrales de Sensor Fusion
  static const int _umbralRuido = 1500;
  static const double _umbralFlujoNormal = 0.5;
  static const double _umbralFlujoFuga = 0.1;

  DashboardController() {
    _localApiService = LocalApiService(
      onProcesarLectura: procesarLecturaSensor,
      onEstadoActual: () => _estadoActual,
      dbService: _dbService,
    );
    _localApiService.iniciar();
    _generarCaudalInmediato();
    iniciarSimuladorDinamico();
  }

  void setUsuarioLogueado(String nombre) {
    usuarioLogueado = nombre;
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
  // Simulador
  // ---------------------------------------------------------------------------

  void setModoSimulacion(String modo) {
    modoSimulacion = modo;
    ultimaAlerta = null;
    _generarCaudalInmediato();
    iniciarSimuladorDinamico();
  }

  void _generarCaudalInmediato() {
    if (modoSimulacion == 'Normal') {
      caudalActual = (Random().nextDouble() * 0.4) + 0.1;
    } else if (modoSimulacion == 'Anomalia') {
      caudalActual = (Random().nextDouble() * 1.3) + 1.2;
    } else if (modoSimulacion == 'Fuga') {
      caudalActual = (Random().nextDouble() * 3.0) + 6.0;
    }
    notifyListeners();
  }

  void iniciarSimuladorDinamico() {
    _simuladorTimer?.cancel();
    _simuladorTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!iaProcesando) {
        _generarCaudalInmediato();
      }
    });
  }

  Future<void> enviarPayloadIA() async {
    iaProcesando = true;
    ultimaAlerta = null;
    notifyListeners();

    final lecturaActual = LecturaSensorModel(
      caudalLPM: caudalActual,
      timestamp: DateTime.now(),
    );
    final respuestaIA = await _apiService.analizarPatronReal(lecturaActual);

    if (respuestaIA.veredicto != 'Error de Red / IA') {
      await _dbService.insertarAlerta(respuestaIA);
    }

    ultimaAlerta = respuestaIA;
    await inicializarHistorial();
    iaProcesando = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sensor Fusion (lecturas del ESP32)
  // ---------------------------------------------------------------------------

  Future<void> procesarLecturaSensor(int ruido, double flujo) async {
    final DateTime timestampLectura = DateTime.now();

    // 1. Sensor Fusion
    final String estado;
    if (ruido > _umbralRuido && flujo > _umbralFlujoNormal) {
      estado = 'Uso Normal';
    } else if (ruido > _umbralRuido && flujo < _umbralFlujoFuga) {
      estado = 'Posible Fuga';
    } else {
      estado = 'Sin Clasificar';
    }

    _estadoActual = estado;
    caudalActual = flujo;

    // 2. Guardar lectura cruda en BD
    await _dbService.insertarLecturaRaw(
      LecturaRawModel(
        ruido: ruido,
        flujo: flujo,
        estado: estado,
        timestamp: timestampLectura,
      ),
    );

    // 3. Actualizar buffer en memoria (máximo 10 lecturas)
    _bufferLecturas.add({
      'ruido': ruido,
      'flujo': flujo,
      'estado': estado,
      'timestamp': timestampLectura.toIso8601String(),
    });
    if (_bufferLecturas.length > 10) {
      _bufferLecturas.removeAt(0);
    }

    // 4. Rate-limit para Groq
    if (estado == 'Posible Fuga') {
      _contadorPosibleFuga++;
    } else {
      _contadorPosibleFuga = 0;
    }

    if (_contadorPosibleFuga >= _umbralFugasConsecutivas && !iaProcesando) {
      final ahora = DateTime.now();
      final cooldownExpirado =
          _lastGroqEvaluation == null ||
          ahora.difference(_lastGroqEvaluation!).inMinutes >= _cooldownMinutos;

      if (cooldownExpirado) {
        _lastGroqEvaluation = ahora;
        _contadorPosibleFuga = 0;
        await _llamarGroqPorFuga(flujo, timestampLectura);
      }
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
    }

    ultimaAlerta = respuestaIA;
    await inicializarHistorial();
    iaProcesando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _localApiService.detener();
    _simuladorTimer?.cancel();
    super.dispose();
  }
}
