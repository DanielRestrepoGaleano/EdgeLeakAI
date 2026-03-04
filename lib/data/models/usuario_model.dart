class UsuarioModel {
  final int? id;
  final String nombre;
  final String correo;
  final String password;

  UsuarioModel({
    this.id,
    required this.nombre,
    required this.correo,
    required this.password,
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'],
      nombre: map['nombre'],
      correo: map['correo'],
      password: map['password'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'password': password,
    };
  }
}
