import 'package:flutter/material.dart';
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
