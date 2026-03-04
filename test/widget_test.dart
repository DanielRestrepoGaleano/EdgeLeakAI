import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/controllers/auth_controller.dart';
import '../lib/controllers/dashboard_controller.dart';
import '../lib/view/screens/login_screen.dart';

void main() {
  testWidgets('Prueba de UI: La pantalla de Login renderiza todos sus elementos clave', (WidgetTester tester) async {
    final authController = AuthController();
    final dashboardController = DashboardController();

    // 🛠️ LA SOLUCIÓN AL ERROR: 
    // Aseguramos que los "Timers" del dashboard se apaguen al terminar el test.
    addTearDown(() {
      dashboardController.dispose();
      authController.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(
        authController: authController,
        dashboardController: dashboardController,
      ),
    ));

    expect(find.text('EdgeLeak AI'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate aquí'), findsOneWidget);
  });
}
