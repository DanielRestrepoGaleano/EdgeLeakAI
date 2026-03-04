import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/routes/app_routes.dart';
import 'config/themes/app_theme.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final dashboardController = DashboardController();
  final authController = AuthController();
  
  runApp(EdgeLeakApp(
    dashboardController: dashboardController,
    authController: authController,
  ));
}

class EdgeLeakApp extends StatelessWidget {
  final DashboardController dashboardController;
  final AuthController authController;

  const EdgeLeakApp({
    super.key, 
    required this.dashboardController,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EdgeLeak AI MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(),
      routes: AppRoutes.getRoutes(dashboardController, authController),
      initialRoute: AppRoutes.loginScreen, // ¡Ahora iniciamos en el Login!
    );
  }
}
