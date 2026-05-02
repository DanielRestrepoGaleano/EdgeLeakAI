/// Enumeración estricta de los tres estados de operación del sistema EdgeLeak AI.
///
/// - [normal]   : El flujo y el ruido se encuentran dentro de los parámetros de
///               referencia aprendidos. No se requiere acción.
/// - [anomalia] : Se ha detectado una desviación respecto al baseline del usuario
///               (patrón de goteo rítmico, lógica nocturna, o flujo intermedio).
///               El sistema envía una alerta preventiva.
/// - [fuga]     : El sensor de flujo reporta un caudal superior al umbral crítico
///               (> 5.0 L/min), indicando una fuga activa confirmada.
enum EstadoSensor {
  normal,
  anomalia,
  fuga;

  /// Etiqueta legible en español para mostrar en la UI y guardar en la BD.
  String get etiqueta {
    switch (this) {
      case EstadoSensor.normal:
        return 'Normal';
      case EstadoSensor.anomalia:
        return 'Anomalía';
      case EstadoSensor.fuga:
        return 'Fuga';
    }
  }

  /// Construye un [EstadoSensor] a partir de una etiqueta de texto.
  /// Útil para deserializar valores almacenados en SQLite.
  static EstadoSensor fromEtiqueta(String etiqueta) {
    switch (etiqueta.toLowerCase()) {
      case 'anomalía':
      case 'anomalia':
      case 'posible fuga':
        return EstadoSensor.anomalia;
      case 'fuga':
      case 'fuga detectada':
        return EstadoSensor.fuga;
      default:
        return EstadoSensor.normal;
    }
  }

  /// Veredicto canónico usado en el campo [AlertaFugaModel.veredicto].
  String get veredicto {
    switch (this) {
      case EstadoSensor.normal:
        return 'Flujo Normal';
      case EstadoSensor.anomalia:
        return 'Anomalía Detectada';
      case EstadoSensor.fuga:
        return 'Fuga Detectada';
    }
  }

  /// Severidad canónica usada en el campo [AlertaFugaModel.severidad].
  String get severidad {
    switch (this) {
      case EstadoSensor.normal:
        return 'Normal';
      case EstadoSensor.anomalia:
        return 'Advertencia';
      case EstadoSensor.fuga:
        return 'Crítica';
    }
  }
}
