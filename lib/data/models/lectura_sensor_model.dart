class LecturaSensorModel {
  final double caudalLPM;
  final int ruido;

  /// Número de micro-picos acústicos contados por el ESP32 en el intervalo de
  /// 5 s. Siempre es un entero ≥ 0; nunca nulo.
  final int picos;

  final DateTime timestamp;

  LecturaSensorModel({
    required this.caudalLPM,
    required this.ruido,
    this.picos = 0,
    required this.timestamp,
  });

  /// Construye el modelo desde un payload JSON enviado por el ESP32 vía HTTP.
  ///
  /// Lanza [FormatException] si:
  ///   - el campo `"picos"` está ausente o es nulo.
  ///   - el campo `"picos"` es negativo.
  ///   - el campo `"flujo"` no es numérico.
  factory LecturaSensorModel.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('picos') || json['picos'] == null) {
      throw const FormatException('Campo requerido ausente: picos');
    }
    final picosRaw = json['picos'];
    if (picosRaw is! num) {
      throw const FormatException('El campo "picos" debe ser numérico');
    }
    final picosVal = picosRaw.toInt();
    if (picosVal < 0) {
      throw const FormatException('El campo "picos" debe ser >= 0');
    }

    final flujoRaw = json['flujo'];
    if (flujoRaw is! num) {
      throw const FormatException('El campo "flujo" debe ser numérico');
    }

    return LecturaSensorModel(
      ruido: (json['ruido'] as num).toInt(),
      caudalLPM: flujoRaw.toDouble(),
      picos: picosVal,
      timestamp: json.containsKey('timestamp') && json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Serializa el modelo a un mapa JSON (compatible con el payload del ESP32).
  Map<String, dynamic> toJson() => {
        'ruido': ruido,
        'flujo': caudalLPM,
        'picos': picos,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Serializa el modelo para persistencia en SQLite.
  Map<String, dynamic> toMap() => {
        'ruido': ruido,
        'flujo': caudalLPM,
        'picos': picos,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Construye el modelo desde un registro de SQLite.
  ///
  /// El campo `"picos"` es opcional en la lectura (backward-compat con
  /// registros anteriores a la v6 que no tienen la columna): si está ausente
  /// o es nulo, el valor predeterminado es 0.
  factory LecturaSensorModel.fromMap(Map<String, dynamic> map) {
    return LecturaSensorModel(
      ruido: (map['ruido'] as num).toInt(),
      caudalLPM: (map['flujo'] as num).toDouble(),
      picos: (map['picos'] as num?)?.toInt() ?? 0,
      timestamp: map.containsKey('timestamp') && map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
