import '../models/lectura_raw_model.dart';

/// DTO de presentación para una lectura cruda del sensor.
///
/// Utilizado para mostrar el buffer de lecturas en la UI del
/// administrador y para futuras exportaciones.
class LecturaRawDto {
  final int? id;
  final int ruido;
  final double flujo;
  final String estado;
  final DateTime timestamp;

  const LecturaRawDto({
    this.id,
    required this.ruido,
    required this.flujo,
    required this.estado,
    required this.timestamp,
  });

  factory LecturaRawDto.fromModel(LecturaRawModel model) {
    return LecturaRawDto(
      id: model.id,
      ruido: model.ruido,
      flujo: model.flujo,
      estado: model.estado,
      timestamp: model.timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ruido': ruido,
    'flujo': flujo,
    'estado': estado,
    'timestamp': timestamp.toIso8601String(),
  };
}
