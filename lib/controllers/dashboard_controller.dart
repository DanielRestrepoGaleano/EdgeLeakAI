import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/lectura_sensor_model.dart';
import '../data/models/alerta_fuga_model.dart';
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

  // Guardamos el nombre de la persona logueada
  String usuarioLogueado = 'Usuario';

  AlertaFugaModel? ultimaAlerta;
  List<AlertaFugaModel> historialEventos = [];
  Timer? _simuladorTimer;

  // --- Sensor Fusion ---

  /// Estado derivado de la fusión de los sensores de ruido y flujo.
  /// Posibles valores: 'Sin datos', 'Uso Normal', 'Posible Fuga', 'Sin Clasificar'.
  String _estadoActual = 'Sin datos';
  String get estadoActual => _estadoActual;

  /// Buffer de las últimas 10 lecturas recibidas desde el ESP32.
  /// Cada entrada contiene: ruido (int), flujo (double), estado (String), timestamp (String).
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

  Future<void> inicializarHistorial() async {
    historialEventos = await _dbService.obtenerHistorial();
    notifyListeners();
  }

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

    final lecturaActual = LecturaSensorModel(caudalLPM: caudalActual, timestamp: DateTime.now());
    final respuestaIA = await _apiService.analizarPatronReal(lecturaActual);

    if (respuestaIA.veredicto != 'Error de Red / IA') {
      await _dbService.insertarAlerta(respuestaIA);
    }

    ultimaAlerta = respuestaIA;
    await inicializarHistorial(); 
    iaProcesando = false;
    notifyListeners();
  }

  /// Procesa una lectura del ESP32 aplicando lógica de Sensor Fusion.
  ///
  /// Reglas:
  /// - 'Uso Normal'    : ruido > 1500 Y flujo > 0.5
  /// - 'Posible Fuga'  : ruido > 1500 Y flujo < 0.1
  /// - 'Sin Clasificar': resto de combinaciones
  ///
  /// Si el estado 'Posible Fuga' persiste 3 lecturas consecutivas (≈ 15 s),
  /// se llama a [GroqApiService] siempre que no exista un cooldown activo de 3 min.
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

    // 2. Actualizar buffer (máximo 10 lecturas)
    _bufferLecturas.add({
      'ruido': ruido,
      'flujo': flujo,
      'estado': estado,
      'timestamp': timestampLectura.toIso8601String(),
    });
    if (_bufferLecturas.length > 10) {
      _bufferLecturas.removeAt(0);
    }

    // 3. Rate-limit para Groq
    if (estado == 'Posible Fuga') {
      _contadorPosibleFuga++;
    } else {
      _contadorPosibleFuga = 0;
    }

    if (_contadorPosibleFuga >= _umbralFugasConsecutivas && !iaProcesando) {
      final ahora = DateTime.now();
      final cooldownExpirado = _lastGroqEvaluation == null ||
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
