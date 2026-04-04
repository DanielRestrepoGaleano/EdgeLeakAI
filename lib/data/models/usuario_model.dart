class UsuarioModel {
  final int? id;
  final String primerNombre;
  final String segundoNombre;
  final String primerApellido;
  final String segundoApellido;
  final String correo;
  final String password;
  final int esTemporal; // 0 = Falso, 1 = Verdadero
  final String rol;      // 'admin' o 'operador'

  UsuarioModel({
    this.id,
    required this.primerNombre,
    this.segundoNombre = '',
    required this.primerApellido,
    this.segundoApellido = '',
    required this.correo,
    required this.password,
    this.esTemporal = 0,
    this.rol = 'operador',
  });

  /// Nombre completo calculado para mostrar en la UI
  String get nombre {
    final partes = <String>[primerNombre];
    if (segundoNombre.isNotEmpty) partes.add(segundoNombre);
    partes.add(primerApellido);
    if (segundoApellido.isNotEmpty) partes.add(segundoApellido);
    return partes.join(' ');
  }

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    // Si los campos nuevos existen y primer_nombre tiene valor, úsalos.
    // Si no (registros migrados), cae en el campo legado 'nombre'.
    final primerNombreLegado = map['nombre'] as String? ?? '';
    final primerNombreNuevo = map['primer_nombre'] as String? ?? '';

    return UsuarioModel(
      id: map['id'],
      primerNombre: primerNombreNuevo.isNotEmpty ? primerNombreNuevo : primerNombreLegado,
      segundoNombre: map['segundo_nombre'] as String? ?? '',
      primerApellido: map['primer_apellido'] as String? ?? '',
      segundoApellido: map['segundo_apellido'] as String? ?? '',
      correo: map['correo'],
      password: map['password'],
      esTemporal: map['es_temporal'] ?? 0,
      rol: map['rol'] ?? 'operador',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'primer_nombre': primerNombre,
      'segundo_nombre': segundoNombre,
      'primer_apellido': primerApellido,
      'segundo_apellido': segundoApellido,
      'correo': correo,
      'password': password,
      'es_temporal': esTemporal,
      'rol': rol,
    };
  }

  // Getter de utilidad para la lógica de privilegios
  bool get esAdmin => rol == 'admin';
}