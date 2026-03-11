import 'package:flutter_test/flutter_test.dart';
import 'package:edgeleak/data/models/usuario_model.dart';

void main() {
  group('Pruebas de Lógica de Usuario (TDD)', () {
    
    test('El modelo debe detectar correctamente el rol admin', () {
      final user = UsuarioModel(nombre: 'A', correo: 'a@e.com', password: '1', rol: 'admin');
      expect(user.esAdmin, true);
    });

    test('El modelo debe denegar acceso admin a un operador', () {
      final user = UsuarioModel(nombre: 'O', correo: 'o@e.com', password: '1', rol: 'operador');
      expect(user.esAdmin, false);
    });

    test('El mapeo de datos debe incluir el campo rol', () {
      final user = UsuarioModel(nombre: 'X', correo: 'x@e.com', password: '1', rol: 'admin');
      final map = user.toMap();
      expect(map['rol'], 'admin');
    });
  });
}