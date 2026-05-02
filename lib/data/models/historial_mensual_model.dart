import 'dart:convert';

/// Historial mensual agregado a partir de múltiples resúmenes de 5 días.
///
/// La tabla [historial_mensual] almacena estos registros para proveer un
/// contexto histórico de largo plazo a la IA de Groq.
class HistorialMensualModel {
  final int? id;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int numAnomalias;
  final int numFugas;
  final double flujoPromedio;
  final double ruidoPromedio;
  final Map<String, dynamic> resumenJson;

  const HistorialMensualModel({
    this.id,
    required this.fechaInicio,
    required this.fechaFin,
    required this.numAnomalias,
    required this.numFugas,
    required this.flujoPromedio,
    required this.ruidoPromedio,
    required this.resumenJson,
  });

  factory HistorialMensualModel.fromMap(Map<String, dynamic> map) {
    return HistorialMensualModel(
      id: map['id'] as int?,
      fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
      fechaFin: DateTime.parse(map['fecha_fin'] as String),
      numAnomalias: (map['num_anomalias'] as num).toInt(),
      numFugas: (map['num_fugas'] as num).toInt(),
      flujoPromedio: (map['flujo_promedio'] as num).toDouble(),
      ruidoPromedio: (map['ruido_promedio'] as num).toDouble(),
      resumenJson: (map['resumen_json'] != null
          ? jsonDecode(map['resumen_json'] as String) as Map<String, dynamic>
          : <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin.toIso8601String(),
        'num_anomalias': numAnomalias,
        'num_fugas': numFugas,
        'flujo_promedio': flujoPromedio,
        'ruido_promedio': ruidoPromedio,
        'resumen_json': jsonEncode(resumenJson),
      };

  /// Representación compacta en texto para el contexto enviado a Groq.
  String toContextString() =>
      '[${fechaInicio.toLocal().toString().substring(0, 10)} → '
      '${fechaFin.toLocal().toString().substring(0, 10)}] '
      'Flujo prom: ${flujoPromedio.toStringAsFixed(3)} L/min | '
      'Ruido prom: ${ruidoPromedio.toStringAsFixed(0)} ADC | '
      'Anomalías: $numAnomalias | Fugas: $numFugas';
}
