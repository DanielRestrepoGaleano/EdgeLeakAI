/// Resumen agregado de lecturas crudas correspondiente a un bloque de 5 días.
///
/// La tabla [lecturas_resumen_5d] almacena estos objetos como resultado del
/// proceso de agregación en segundo plano ejecutado por [BaselineService].
class LecturaResumenModel {
  final int? id;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final double flujoPromedio;
  final double ruidoPromedio;
  final int totalLecturas;
  final String estadoPredominante;

  const LecturaResumenModel({
    this.id,
    required this.fechaInicio,
    required this.fechaFin,
    required this.flujoPromedio,
    required this.ruidoPromedio,
    required this.totalLecturas,
    required this.estadoPredominante,
  });

  factory LecturaResumenModel.fromMap(Map<String, dynamic> map) {
    return LecturaResumenModel(
      id: map['id'] as int?,
      fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
      fechaFin: DateTime.parse(map['fecha_fin'] as String),
      flujoPromedio: (map['flujo_promedio'] as num).toDouble(),
      ruidoPromedio: (map['ruido_promedio'] as num).toDouble(),
      totalLecturas: (map['total_lecturas'] as num).toInt(),
      estadoPredominante: map['estado_predominante'] as String? ?? 'Normal',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin.toIso8601String(),
        'flujo_promedio': flujoPromedio,
        'ruido_promedio': ruidoPromedio,
        'total_lecturas': totalLecturas,
        'estado_predominante': estadoPredominante,
      };

  /// Representación compacta en texto para incluir como contexto en el payload de Groq.
  String toContextString() =>
      '[${fechaInicio.toLocal().toString().substring(0, 10)} → '
      '${fechaFin.toLocal().toString().substring(0, 10)}] '
      'Flujo prom: ${flujoPromedio.toStringAsFixed(3)} L/min | '
      'Ruido prom: ${ruidoPromedio.toStringAsFixed(0)} ADC | '
      'Estado: $estadoPredominante | '
      'Lecturas: $totalLecturas';
}
