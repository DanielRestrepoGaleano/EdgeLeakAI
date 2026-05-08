/// DTO que representa el payload enviado por el ESP32
/// al endpoint POST /api/sensor.
///
/// Separa la capa de transporte del modelo de dominio.
class SensorRequestDto {
  final int ruido;
  final double flujo;

  /// Número de micro-picos acústicos contados por el ESP32 en el intervalo
  /// de 5 s. Debe ser un entero ≥ 0.
  final int picos;

  const SensorRequestDto({
    required this.ruido,
    required this.flujo,
    required this.picos,
  });

  /// Construye el DTO desde el JSON recibido por HTTP.
  ///
  /// Lanza [FormatException] si:
  ///   - faltan los campos obligatorios `ruido` o `flujo`.
  ///   - falta el campo `picos` o es nulo.
  ///   - el campo `picos` es negativo.
  factory SensorRequestDto.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('ruido') || !map.containsKey('flujo')) {
      throw const FormatException(
        'Campos requeridos: ruido (int) y flujo (double)',
      );
    }
    if (!map.containsKey('picos') || map['picos'] == null) {
      throw const FormatException(
        'Campo requerido ausente: picos (int >= 0)',
      );
    }
    final picosVal = (map['picos'] as num).toInt();
    if (picosVal < 0) {
      throw const FormatException(
        'El campo "picos" debe ser un entero >= 0',
      );
    }
    return SensorRequestDto(
      ruido: (map['ruido'] as num).toInt(),
      flujo: (map['flujo'] as num).toDouble(),
      picos: picosVal,
    );
  }

  Map<String, dynamic> toMap() => {
        'ruido': ruido,
        'flujo': flujo,
        'picos': picos,
      };
}
