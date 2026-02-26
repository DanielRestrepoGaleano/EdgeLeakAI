class AlertaFugaModel {
  final int? id; // Autoincremental en SQLite
  final String veredicto;
  final String severidad;
  final String mensaje;
  final DateTime fecha;

  AlertaFugaModel({
    this.id,
    required this.veredicto,
    required this.severidad,
    required this.mensaje,
    required this.fecha,
  });

  // Convertir de Map (SQLite/JSON) a Objeto
  factory AlertaFugaModel.fromMap(Map<String, dynamic> map) {
    return AlertaFugaModel(
      id: map['id'], // SQLite lo trae
      veredicto: map['veredicto'] ?? 'Desconocido',
      severidad: map['severidad'] ?? 'Normal',
      mensaje: map['mensaje'] ?? 'Sin mensaje',
      // Si viene de BD o de API, manejamos el parseo
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
    );
  }

  // Convertir de Objeto a Map (Para insertar en SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'veredicto': veredicto,
      'severidad': severidad,
      'mensaje': mensaje,
      'fecha': fecha.toIso8601String(), // Sqflite guarda las fechas como texto ISO
    };
  }
}
