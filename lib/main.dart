import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Variables de entorno
import 'config/routes/app_routes.dart';
import 'config/themes/app_theme.dart';
import 'controllers/dashboard_controller.dart';

Future<void> main() async {
  // Aseguramos la inicialización de widgets antes de cargar el .env y Sqflite
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargamos las variables de entorno de forma segura
  await dotenv.load(fileName: ".env");

  // Inicializamos el controlador principal
  final dashboardController = DashboardController();
  await dashboardController.inicializarHistorial(); // Cargar datos de Sqflite
  
  runApp(EdgeLeakApp(controller: dashboardController));
}

class EdgeLeakApp extends StatelessWidget {
  final DashboardController controller;

  const EdgeLeakApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EdgeLeak AI MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(),
      routes: AppRoutes.getRoutes(controller),
      initialRoute: AppRoutes.dashboardScreen,
    );
  }
}
