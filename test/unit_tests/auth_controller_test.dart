import 'package:flutter_test/flutter_test.dart';
import '../../lib/controllers/auth_controller.dart';

void main() {
  group('AuthController - Validaciones de Seguridad de Contraseña', () {
    late AuthController authController;

    setUp(() {
      authController = AuthController();
    });

    test('Una contraseña corta y simple debe ser rechazada', () {
      authController.validatePassword('hola123');
      
      expect(authController.isPasswordValid, false);
      expect(authController.hasMinLength, false, reason: 'Solo tiene 7 caracteres');
      expect(authController.hasUppercase, false, reason: 'No tiene mayúsculas');
      expect(authController.hasSpecialChar, false, reason: 'No tiene caracteres especiales');
    });

    test('Una contraseña segura debe activar todos los checkmarks', () {
      authController.validatePassword('EdgeLeak2024*!');
      
      expect(authController.hasMinLength, true);
      expect(authController.hasUppercase, true);
      expect(authController.hasNumber, true);
      expect(authController.hasSpecialChar, true);
      
      // La validación global debe ser verdadera
      expect(authController.isPasswordValid, true);
    });
  });
}
