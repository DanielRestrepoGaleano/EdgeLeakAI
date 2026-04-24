/// Entidad de dominio que representa una lectura cruda del sensor
/// almacenada en la tabla [lecturas_raw] de SQLite.
class LecturaRawModel {
  final int? id;
  final int ruido;
  final double flujo;
  final String estado;
  final DateTime timestamp;

  const LecturaRawModel({
    this.id,
    required this.ruido,
    required this.flujo,
    required this.estado,
    required this.timestamp,
  });

  factory LecturaRawModel.fromMap(Map<String, dynamic> map) {
    return LecturaRawModel(
      id: map['id'] as int?,
      ruido: (map['ruido'] as num).toInt(),
      flujo: (map['flujo'] as num).toDouble(),
      estado: map['estado'] as String? ?? 'Sin Clasificar',
      timestamp: DateTime.parse(map['timestamp'] as String),
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
