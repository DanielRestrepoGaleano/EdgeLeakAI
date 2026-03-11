class UsuarioModel {
  final int? id;
  final String nombre;
  final String correo;
  final String password;
  final int esTemporal; // 0 = Falso, 1 = Verdadero
  final String rol;      // 'admin' o 'operador'

  UsuarioModel({
    this.id,
    required this.nombre,
    required this.correo,
    required this.password,
    this.esTemporal = 0,
    this.rol = 'operador', // Valor por defecto para evitar errores de compilación
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'],
      nombre: map['nombre'],
      correo: map['correo'],
      password: map['password'],
      esTemporal: map['es_temporal'] ?? 0,
      rol: map['rol'] ?? 'operador',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'password': password,
      'es_temporal': esTemporal,
      'rol': rol,
    };
  }

  // Método de utilidad para la lógica de privilegios
  bool esAdmin() => rol == 'admin';
}