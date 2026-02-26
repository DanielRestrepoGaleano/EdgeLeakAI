import 'package:flutter/material.dart';
import '../../view/screens/dashboard_screen.dart';
import '../../view/screens/historial_screen.dart';
import '../../controllers/dashboard_controller.dart';

class AppRoutes {
  static const String dashboardScreen = 'dashboard';
  static const String historialScreen = 'historial';

  static Map<String, WidgetBuilder> getRoutes(DashboardController controller) {
    return {
      dashboardScreen: (context) => DashboardScreen(controller: controller),
      historialScreen: (context) => HistorialScreen(controller: controller),
    };
  }
}
