import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/auth_controller.dart'; // 🟢 Importar AuthController
import '../../config/themes/app_theme.dart';
import '../widgets/status_indicator_widget.dart';
import '../widgets/water_wave_widget.dart';
import '../../config/routes/app_routes.dart';

class DashboardScreen extends StatelessWidget {
  final DashboardController controller;
  final AuthController authController; // 🟢 Añadirlo a la clase

  // Actualizar constructor
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Text(
            'Hola, ${controller.usuarioLogueado} 👋',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        actions: [
          // 🟢 BOTÓN DE ADMINISTRACIÓN: Solo visible si es admin
          if (authController.usuarioActual?.esAdmin == true)
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.adminUsersScreen),
              tooltip: 'Gestión de Usuarios',
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.historialScreen),
            tooltip: 'Ver Historial local',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.loginScreen),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusIndicatorWidget(conectado: controller.conectado),
                const SizedBox(height: 15),

                Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 6,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      WaterWaveWidget(modo: controller.modoSimulacion),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30.0),
                        child: Column(
                          children: [
                            const Text(
                              'Caudal del Sensor',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${controller.caudalActual.toStringAsFixed(2)} L/min',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: controller.modoSimulacion == 'Fuga'
                                      ? AppTheme.criticalColor
                                      : (controller.modoSimulacion == 'Anomalia'
                                            ? AppTheme.warningColor
                                            : AppTheme.primaryColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Inyección de Estado al Sensor:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Normal',
                      label: Text('Normal'),
                      icon: Icon(Icons.water_drop),
                    ),
                    ButtonSegment(
                      value: 'Anomalia',
                      label: Text('Anomalía'),
                      icon: Icon(Icons.warning_amber),
                    ),
                    ButtonSegment(
                      value: 'Fuga',
                      label: Text('Fuga'),
                      icon: Icon(Icons.error_outline),
                    ),
                  ],
                  selected: {controller.modoSimulacion},
                  onSelectionChanged: (Set<String> newSelection) =>
                      controller.setModoSimulacion(newSelection.first),
                  style: SegmentedButton.styleFrom(
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: controller.modoSimulacion == 'Fuga'
                        ? AppTheme.criticalColor
                        : (controller.modoSimulacion == 'Anomalia'
                              ? AppTheme.warningColor
                              : AppTheme.normalColor),
                  ),
                ),
                const SizedBox(height: 15),

                if (controller.iaProcesando)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Groq AI analizando flujo...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else if (controller.ultimaAlerta != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: controller.ultimaAlerta!.severidad == 'Crítica'
                          ? AppTheme.criticalColor
                          : (controller.ultimaAlerta!.severidad == 'Advertencia'
                                ? AppTheme.warningColor
                                : AppTheme.normalColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          controller.ultimaAlerta!.severidad == 'Crítica'
                              ? Icons.warning
                              : Icons.info,
                          color: Colors.white,
                          size: 35,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.ultimaAlerta!.veredicto,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                controller.ultimaAlerta!.mensaje,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),
                ElevatedButton.icon(
                  onPressed: controller.iaProcesando
                      ? null
                      : () => controller.enviarPayloadIA(),
                  icon: const Icon(Icons.psychology),
                  label: const Text('EVALUAR CON INTELIGENCIA ARTIFICIAL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          );
        },
      ),
    );
  }
}
