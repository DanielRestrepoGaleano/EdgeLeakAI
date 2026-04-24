import '../models/alerta_fuga_model.dart';

/// DTO de presentación para una alerta de fuga.
///
/// Se usa en las capas de UI y en las respuestas JSON del endpoint
/// GET /api/history, manteniendo separada la entidad de dominio.
class AlertaFugaDto {
  final int? id;
  final String veredicto;
  final String severidad;
  final String mensaje;
  final DateTime fecha;

  const AlertaFugaDto({
    this.id,
    required this.veredicto,
    required this.severidad,
    required this.mensaje,
    required this.fecha,
  });

  /// Construye el DTO desde la entidad de dominio.
  factory AlertaFugaDto.fromModel(AlertaFugaModel model) {
    return AlertaFugaDto(
      id: model.id,
      veredicto: model.veredicto,
      severidad: model.severidad,
      mensaje: model.mensaje,
      fecha: model.fecha,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'veredicto': veredicto,
    'severidad': severidad,
    'mensaje': mensaje,
    'timestamp': fecha.toIso8601String(),
  };
}
