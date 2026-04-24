/// DTO que representa el payload enviado por el ESP32
/// al endpoint POST /api/sensor.
///
/// Separa la capa de transporte del modelo de dominio.
class SensorRequestDto {
  final int ruido;
  final double flujo;

  const SensorRequestDto({required this.ruido, required this.flujo});

  /// Construye el DTO desde el JSON recibido por HTTP.
  /// Lanza [FormatException] si faltan campos obligatorios.
  factory SensorRequestDto.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('ruido') || !map.containsKey('flujo')) {
      throw const FormatException(
        'Campos requeridos: ruido (int) y flujo (double)',
      );
    }
    return SensorRequestDto(
      ruido: (map['ruido'] as num).toInt(),
      flujo: (map['flujo'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {'ruido': ruido, 'flujo': flujo};
}
