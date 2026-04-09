import 'package:flutter_test/flutter_test.dart';
import 'package:edgeleak/data/models/usuario_model.dart';

void main() {
  group('Pruebas de Lógica de Usuario (TDD)', () {
    
    test('El modelo debe detectar correctamente el rol admin', () {
      final user = UsuarioModel(primerNombre: 'A', primerApellido: 'B', correo: 'a@e.com', password: '1', rol: 'admin');
      expect(user.esAdmin, true);
    });

    test('El modelo debe denegar acceso admin a un operador', () {
      final user = UsuarioModel(primerNombre: 'O', primerApellido: 'P', correo: 'o@e.com', password: '1', rol: 'operador');
      expect(user.esAdmin, false);
    });

    test('El mapeo de datos debe incluir el campo rol', () {
      final user = UsuarioModel(primerNombre: 'X', primerApellido: 'Y', correo: 'x@e.com', password: '1', rol: 'admin');
      final map = user.toMap();
      expect(map['rol'], 'admin');
    });

    test('El getter nombre debe combinar los campos de nombre correctamente', () {
      final user = UsuarioModel(
        primerNombre: 'Juan',
        segundoNombre: 'Carlos',
        primerApellido: 'García',
        segundoApellido: 'López',
        correo: 'juan@e.com',
        password: '1',
      );
      expect(user.nombre, 'Juan Carlos García López');
    });

    test('El getter nombre debe omitir campos opcionales vacíos', () {
      final user = UsuarioModel(
        primerNombre: 'Ana',
        primerApellido: 'Martínez',
        correo: 'ana@e.com',
        password: '1',
      );
      expect(user.nombre, 'Ana Martínez');
    });

    test('El mapeo debe incluir los cuatro campos de nombre', () {
      final user = UsuarioModel(
        primerNombre: 'Pedro',
        segundoNombre: 'Luis',
        primerApellido: 'Ramírez',
        segundoApellido: 'Torres',
        correo: 'pedro@e.com',
        password: '1',
      );
      final map = user.toMap();
      expect(map['primer_nombre'], 'Pedro');
      expect(map['segundo_nombre'], 'Luis');
      expect(map['primer_apellido'], 'Ramírez');
      expect(map['segundo_apellido'], 'Torres');
    });

    test('fromMap debe reconstruir el modelo correctamente desde nuevos campos', () {
      final map = {
        'id': 1,
        'primer_nombre': 'Laura',
        'segundo_nombre': '',
        'primer_apellido': 'Gómez',
        'segundo_apellido': '',
        'correo': 'laura@e.com',
        'password': 'pass',
        'es_temporal': 0,
        'rol': 'operador',
      };
      final user = UsuarioModel.fromMap(map);
      expect(user.primerNombre, 'Laura');
      expect(user.primerApellido, 'Gómez');
      expect(user.nombre, 'Laura Gómez');
    });

    test('fromMap debe usar el campo nombre legado cuando primer_nombre está vacío', () {
      final map = {
        'id': 2,
        'nombre': 'Carlos Vega',
        'primer_nombre': '',
        'segundo_nombre': '',
        'primer_apellido': '',
        'segundo_apellido': '',
        'correo': 'carlos@e.com',
        'password': 'pass',
        'es_temporal': 0,
        'rol': 'operador',
      };
      final user = UsuarioModel.fromMap(map);
      expect(user.primerNombre, 'Carlos Vega');
    });
  });
}