import os

# Ruta a la carpeta "test" de tu proyecto
BASE_DIR = r"C:\Users\danie\OneDrive\Escritorio\edgeleak\test"

FILES = {
    # ---------------- 1. PRUEBAS DE UI (WIDGET TESTS) ----------------
    "widget_test.dart": r"""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/controllers/auth_controller.dart';
import '../lib/controllers/dashboard_controller.dart';
import '../lib/view/screens/login_screen.dart';

void main() {
  testWidgets('Prueba de UI: La pantalla de Login renderiza todos sus elementos clave', (WidgetTester tester) async {
    // 1. Arrange (Preparar) - Inyectamos los controladores vacíos
    final authController = AuthController();
    final dashboardController = DashboardController();

    // Construimos la pantalla dentro del entorno de pruebas
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(
        authController: authController,
        dashboardController: dashboardController,
      ),
    ));

    // 2. Act & Assert (Actuar y Afirmar)
    // Verificamos que el título principal exista
    expect(find.text('EdgeLeak AI'), findsOneWidget);
    
    // Verificamos que existan exactamente 2 campos de texto (Correo y Contraseña)
    expect(find.byType(TextField), findsNWidgets(2));
    
    // Verificamos que el botón de inicio de sesión esté en la pantalla
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    
    // Verificamos que el enlace al registro esté disponible
    expect(find.text('¿No tienes cuenta? Regístrate aquí'), findsOneWidget);
  });
}
""",

    # ---------------- 2. PRUEBAS UNITARIAS: AUTENTICACIÓN ----------------
    r"unit_tests\auth_controller_test.dart": r"""import 'package:flutter_test/flutter_test.dart';
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
""",

    # ---------------- 3. PRUEBAS UNITARIAS: SIMULADOR DE HARDWARE ----------------
    r"unit_tests\dashboard_controller_test.dart": r"""import 'package:flutter_test/flutter_test.dart';
import '../../lib/controllers/dashboard_controller.dart';

void main() {
  group('DashboardController - Simulación de Caudal (Sensor YF-S201)', () {
    late DashboardController dashboardController;

    setUp(() {
      dashboardController = DashboardController();
    });

    test('Al inicializar, el estado debe ser Normal y el caudal bajo', () {
      expect(dashboardController.modoSimulacion, 'Normal');
      
      // El caudal normal debe oscilar matemáticamente entre 0.1 y 0.5
      expect(dashboardController.caudalActual, greaterThanOrEqualTo(0.1));
      expect(dashboardController.caudalActual, lessThanOrEqualTo(0.5));
    });

    test('Al inyectar una Fuga Crítica, el caudal debe dispararse', () {
      // Simulamos la interacción del usuario tocando el botón "Fuga"
      dashboardController.setModoSimulacion('Fuga');
      
      expect(dashboardController.modoSimulacion, 'Fuga');
      
      // La lógica matemática dicta que una fuga debe ser mayor a 6.0 L/min
      expect(dashboardController.caudalActual, greaterThanOrEqualTo(6.0));
      expect(dashboardController.caudalActual, lessThanOrEqualTo(9.0));
    });
    
    test('Al inyectar una Anomalía, el caudal debe ser intermedio', () {
      dashboardController.setModoSimulacion('Anomalia');
      
      // El goteo/anomalía debe oscilar entre 1.2 y 2.5 L/min
      expect(dashboardController.caudalActual, greaterThanOrEqualTo(1.2));
      expect(dashboardController.caudalActual, lessThanOrEqualTo(2.5));
    });
  });
}
"""
}

def crear_tests():
    print("🧪 Generando ecosistema de Pruebas Automatizadas (TDD)...")
    
    for relative_path, content in FILES.items():
        full_path = os.path.join(BASE_DIR, relative_path)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Test creado: {relative_path}")
        
    print("\n🎉 ¡Tests listos! Para ejecutarlos, abre la terminal y corre: flutter test")

if __name__ == "__main__":
    crear_tests()