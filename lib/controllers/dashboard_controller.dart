import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/lectura_sensor_model.dart';
import '../data/models/alerta_fuga_model.dart';
import '../data/services/groq_api_service.dart';
import '../data/services/database_service.dart';

class DashboardController extends ChangeNotifier {
  final GroqApiService _apiService = GroqApiService();
  final DatabaseService _dbService = DatabaseService();
  
  double caudalActual = 0.0;
  bool conectado = true;
  bool iaProcesando = false;
  String modoSimulacion = 'Normal'; 
  
  // Novedad: Guardamos el nombre de la persona logueada
  String usuarioLogueado = 'Usuario';
  
  AlertaFugaModel? ultimaAlerta;
  List<AlertaFugaModel> historialEventos =[];
  Timer? _simuladorTimer;

  DashboardController() {
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

  @override
  void dispose() {
    _simuladorTimer?.cancel();
    super.dispose();
  }
}
