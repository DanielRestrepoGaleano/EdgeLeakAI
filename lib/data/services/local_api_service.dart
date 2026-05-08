import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../dto/sensor_request_dto.dart';
import '../dto/alerta_fuga_dto.dart';
import 'database_service.dart';

/// Clave secreta para los endpoints protegidos.
/// - GET  /api/history  → x-api-key obligatorio.
/// - POST /api/sensor   → x-api-key obligatorio (seguridad mínima).
/// Se lee de LOCAL_API_KEY en .env; si no está se usa el valor de referencia.
String get _kApiKey => dotenv.env['LOCAL_API_KEY'] ?? 'edgeleak-share-2024';

/// Tipo de callback que el DashboardController expone para recibir lecturas
/// del sensor ESP32 y ejecutar la lógica de Sensor Fusion.
typedef ProcesarLecturaCallback = Future<void> Function(
    int ruido, double flujo, int picos);

/// Tipo de callback para obtener el estado actual de fusión del sensor,
/// utilizado en la respuesta del endpoint POST /api/sensor.
typedef EstadoActualCallback = String Function();

/// Servidor HTTP local (puerto 8080) que expone dos endpoints:
///
/// - POST /api/sensor  → Recibe lecturas del ESP32 y delega en el
///   [DashboardController] para la lógica de Sensor Fusion.
/// - GET  /api/history → Devuelve el historial de fugas detectadas en JSON,
///   protegido mediante el header x-api-key.
class LocalApiService {
  final ProcesarLecturaCallback _onProcesarLectura;
  final EstadoActualCallback _onEstadoActual;
  final DatabaseService _dbService;

  HttpServer? _server;

  LocalApiService({
    required ProcesarLecturaCallback onProcesarLectura,
    required EstadoActualCallback onEstadoActual,
    required DatabaseService dbService,
  })  : _onProcesarLectura = onProcesarLectura,
        _onEstadoActual = onEstadoActual,
        _dbService = dbService;

  /// Inicia el servidor HTTP en el puerto 8080.
  Future<void> iniciar() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      debugPrint('🌐 LocalApiService iniciado en http://0.0.0.0:8080');
      _server!.listen(_manejarPeticion, onError: (Object error) {
        debugPrint('❌ LocalApiService error en listener: $error');
      });
    } on SocketException catch (e) {
      debugPrint(
        '❌ LocalApiService no pudo iniciar (puerto 8080 en uso o sin permisos): $e',
      );
    } catch (e) {
      debugPrint('❌ LocalApiService no pudo iniciar: $e');
    }
  }

  /// Detiene el servidor HTTP liberando el puerto.
  Future<void> detener() async {
    await _server?.close(force: true);
    _server = null;
    debugPrint('🔴 LocalApiService detenido');
  }

  // ---------------------------------------------------------------------------
  // Router principal
  // ---------------------------------------------------------------------------

  Future<void> _manejarPeticion(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    request.response.headers.contentType = ContentType.json;
    // Allow requests from Postman / local browser dev tools.
    // The ESP32 does not send CORS pre-flight requests; these headers are
    // only useful for manual testing and are scoped to localhost.
    request.response.headers.set('Access-Control-Allow-Origin', 'http://localhost');
    request.response.headers.set(
        'Access-Control-Allow-Headers', 'Content-Type, x-api-key');

    // Handle CORS pre-flight
    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      if (method == 'POST' && path == '/api/sensor') {
        await _manejarPostSensor(request);
      } else if (method == 'GET' && path == '/api/history') {
        await _manejarGetHistory(request);
      } else {
        await _responder(
          request,
          HttpStatus.notFound,
          {'error': 'Endpoint no encontrado: $method $path'},
        );
      }
    } catch (e) {
      debugPrint('❌ LocalApiService excepción no controlada: $e');
      try {
        await _responder(
          request,
          HttpStatus.internalServerError,
          {'error': 'Error interno del servidor'},
        );
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // POST /api/sensor
  // ---------------------------------------------------------------------------

  /// Recibe {"ruido": int, "flujo": double} desde el ESP32 cada 5 segundos.
  /// Requiere header x-api-key válido; si no, responde 401 Unauthorized.
  /// Delega la lógica de fusión de sensores en el [DashboardController] y
  /// devuelve el estado resultante.
  Future<void> _manejarPostSensor(HttpRequest request) async {
    // Seguridad mínima: validar x-api-key en el endpoint de entrada del hardware
    final apiKeyHeader = request.headers.value('x-api-key');
    if (apiKeyHeader != _kApiKey) {
      await _responder(
        request,
        HttpStatus.unauthorized,
        {'error': 'No autorizado. Header x-api-key inválido o ausente.'},
      );
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;

      final SensorRequestDto dto;
      try {
        dto = SensorRequestDto.fromMap(data);
      } on FormatException catch (e) {
        await _responder(
          request,
          HttpStatus.badRequest,
          {'error': e.message},
        );
        return;
      }

      debugPrint(
          '📡 LocalApiService → ruido=${dto.ruido}, flujo=${dto.flujo.toStringAsFixed(3)} L/min, picos=${dto.picos}');

      try {
        await _onProcesarLectura(dto.ruido, dto.flujo, dto.picos);
      } catch (e) {
        debugPrint('❌ LocalApiService error en callback del controlador: $e');
      }

      await _responder(request, HttpStatus.ok, {
        'status': 'ok',
        'estado': _onEstadoActual(),
        'ruido': dto.ruido,
        'flujo': dto.flujo,
        'picos': dto.picos,
      });
    } on FormatException {
      await _responder(
        request,
        HttpStatus.badRequest,
        {'error': 'JSON inválido'},
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET /api/history
  // ---------------------------------------------------------------------------

  /// Devuelve el historial de fugas almacenado en la base de datos local.
  /// Requiere el header x-api-key con el valor correcto; de lo contrario
  /// responde 401 Unauthorized.
  Future<void> _manejarGetHistory(HttpRequest request) async {
    final apiKeyHeader = request.headers.value('x-api-key');
    if (apiKeyHeader != _kApiKey) {
      await _responder(
        request,
        HttpStatus.unauthorized,
        {'error': 'No autorizado. Header x-api-key inválido o ausente.'},
      );
      return;
    }

    final historial = await _dbService.obtenerHistorial();
    final jsonList =
        historial.map((alerta) => AlertaFugaDto.fromModel(alerta).toMap()).toList();

    await _responder(request, HttpStatus.ok, jsonList);
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  Future<void> _responder(
    HttpRequest request,
    int statusCode,
    Object body,
  ) async {
    request.response
      ..statusCode = statusCode
      ..write(jsonEncode(body));
    await request.response.close();
  }
}
