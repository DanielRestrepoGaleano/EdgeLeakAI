import 'package:flutter/material.dart';
import '../../view/screens/dashboard_screen.dart';
import '../../view/screens/historial_screen.dart';
import '../../view/screens/login_screen.dart';
import '../../view/screens/register_screen.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/auth_controller.dart';

class AppRoutes {
  static const String loginScreen = 'login';
  static const String registerScreen = 'register';
  static const String dashboardScreen = 'dashboard';
  static const String historialScreen = 'historial';

  static Map<String, WidgetBuilder> getRoutes(DashboardController dController, AuthController aController) {
    return {
      loginScreen: (context) => LoginScreen(authController: aController, dashboardController: dController),
      registerScreen: (context) => RegisterScreen(authController: aController),
      dashboardScreen: (context) => DashboardScreen(controller: dController),
      historialScreen: (context) => HistorialScreen(controller: dController),
    };
  }
}
