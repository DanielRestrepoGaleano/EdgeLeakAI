import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'database_service.dart';

/// Clave secreta para el endpoint protegido GET /api/history.
/// Se lee primero de la variable de entorno LOCAL_API_KEY definida en .env;
/// si no está presente se usa el valor de referencia del proyecto.
/// Debe coincidir con el header x-api-key enviado por el cliente.
String get _kApiKey =>
    dotenv.env['LOCAL_API_KEY'] ?? 'edgeleak-share-2024';

/// Tipo de callback que el DashboardController expone para recibir lecturas
/// del sensor ESP32 y ejecutar la lógica de Sensor Fusion.
typedef ProcesarLecturaCallback = Future<void> Function(int ruido, double flujo);

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

  /// Recibe {"ruido": int, "flujo": double} desde el ESP32 cada 5 segundos,
  /// delega la lógica de fusión de sensores en el [DashboardController] y
  /// devuelve el estado resultante.
  Future<void> _manejarPostSensor(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;

      if (!data.containsKey('ruido') || !data.containsKey('flujo')) {
        await _responder(
          request,
          HttpStatus.badRequest,
          {'error': 'Campos requeridos: ruido (int) y flujo (double)'},
        );
        return;
      }

      final int ruido = (data['ruido'] as num).toInt();
      final double flujo = (data['flujo'] as num).toDouble();

      await _onProcesarLectura(ruido, flujo);

      await _responder(request, HttpStatus.ok, {
        'status': 'ok',
        'estado': _onEstadoActual(),
        'ruido': ruido,
        'flujo': flujo,
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
    final jsonList = historial
        .map(
          (alerta) => {
            'id': alerta.id,
            'veredicto': alerta.veredicto,
            'severidad': alerta.severidad,
            'mensaje': alerta.mensaje,
            'timestamp': alerta.fecha.toIso8601String(),
          },
        )
        .toList();

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
