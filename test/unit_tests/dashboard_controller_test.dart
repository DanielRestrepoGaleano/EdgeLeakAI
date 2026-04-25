import 'package:flutter_test/flutter_test.dart';
import 'package:edgeleak/controllers/dashboard_controller.dart';

void main() {
  group('DashboardController - Procesamiento de Caudal y Ruido', () {
    late DashboardController dashboardController;

    setUp(() {
      dashboardController = DashboardController();
    });

    test('Al inicializar, el estado debe ser Sin datos y el caudal 0', () {
      expect(dashboardController.estadoActual, 'Sin datos');
      expect(dashboardController.caudalActual, 0.0);
    });

    test('Al procesar lectura normal, el estado debe ser Uso Normal', () async {
      await dashboardController.procesarLecturaSensor(500, 0.5);
      
      expect(dashboardController.estadoActual, 'Uso Normal');
      expect(dashboardController.caudalActual, 0.5);
      expect(dashboardController.strikesFuga, 0);
    });
    
    test('Al procesar posible fuga (alto ruido, flujo bajo), los strikes deben subir', () async {
      await dashboardController.procesarLecturaSensor(1600, 0.05);
      
      expect(dashboardController.estadoActual, 'Posible Fuga');
      expect(dashboardController.caudalActual, 0.05);
      expect(dashboardController.strikesFuga, 1);
    });
  });
}
