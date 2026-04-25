import 'package:flutter/material.dart';
import '../../view/screens/dashboard_screen.dart';
import '../../view/screens/historial_screen.dart';
import '../../view/screens/login_screen.dart';
import '../../view/screens/register_screen.dart';
import '../../view/screens/forgot_password_screen.dart';
import '../../view/screens/change_password_screen.dart';
import '../../view/screens/admin_users_screen.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/auth_controller.dart';

class AppRoutes {
  static const String loginScreen = 'login';
  static const String registerScreen = 'register';
  static const String forgotPasswordScreen = 'forgot_password';
  static const String changePasswordScreen = 'change_password';
  static const String dashboardScreen = 'dashboard';
  static const String historialScreen = 'historial';
  static const String adminUsersScreen = 'admin_users';

  static Map<String, WidgetBuilder> getRoutes(
    DashboardController dController,
    AuthController aController,
  ) {
    return {
      loginScreen: (context) => LoginScreen(
        authController: aController,
        dashboardController: dController,
      ),
      registerScreen: (context) => RegisterScreen(authController: aController),
      forgotPasswordScreen: (context) =>
          ForgotPasswordScreen(authController: aController),
      changePasswordScreen: (context) => ChangePasswordScreen(
        authController: aController,
        dashboardController: dController,
        dashboardScreen: (context) =>
            DashboardScreen(controller: dController, authController: aController),
        historialScreen: (context) => HistorialScreen(controller: dController),
        adminUsersScreen: (context) =>
          AdminUsersScreen(authController: aController),
      ),

      // 🟢 Modificación principal: Pasarle el aController al Dashboard
      dashboardScreen: (context) =>
          DashboardScreen(controller: dController, authController: aController),

      historialScreen: (context) => HistorialScreen(controller: dController),
      adminUsersScreen: (context) =>
          AdminUsersScreen(authController: aController),
    };
  }
}
