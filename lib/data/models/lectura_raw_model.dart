/// Entidad de dominio que representa una lectura cruda del sensor
/// almacenada en la tabla [lecturas_raw] de SQLite.
class LecturaRawModel {
  final int? id;
  final int ruido;
  final double flujo;
  final String estado;
  final DateTime timestamp;

  /// Número de micro-picos acústicos contados por el ESP32 en el intervalo.
  /// Siempre ≥ 0; valor predeterminado 0 para compatibilidad con la v5.
  final int picos;

  const LecturaRawModel({
    this.id,
    required this.ruido,
    required this.flujo,
    required this.estado,
    required this.timestamp,
    this.picos = 0,
  });

  factory LecturaRawModel.fromMap(Map<String, dynamic> map) {
    return LecturaRawModel(
      id: map['id'] as int?,
      ruido: (map['ruido'] as num).toInt(),
      flujo: (map['flujo'] as num).toDouble(),
      estado: map['estado'] as String? ?? 'Sin Clasificar',
      timestamp: DateTime.parse(map['timestamp'] as String),
      picos: (map['picos'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ruido': ruido,
        'flujo': flujo,
        'estado': estado,
        'timestamp': timestamp.toIso8601String(),
        'picos': picos,
      };
}
