import 'package:flutter_test/flutter_test.dart';
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
