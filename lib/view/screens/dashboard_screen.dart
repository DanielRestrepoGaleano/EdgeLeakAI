import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../config/themes/app_theme.dart';
import '../widgets/status_indicator_widget.dart';
import '../widgets/water_wave_widget.dart';
import '../../config/routes/app_routes.dart';

class DashboardScreen extends StatelessWidget {
  final DashboardController controller;
  final AuthController authController;

  const DashboardScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  /// Mapea el estado de Sensor Fusion al modo visual del widget de olas.
  String _waveMode(String estado) {
    switch (estado) {
      case 'Posible Fuga':
        return 'Anomalia';
      default:
        return 'Normal';
    }
  }

  /// Color del texto de caudal según el estado detectado por Sensor Fusion.
  Color _caudalColor(String estado) {
    switch (estado) {
      case 'Posible Fuga':
        return AppTheme.warningColor;
      default:
        return AppTheme.primaryColor;
    }
  }

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
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              controller.inicializarHistorial();
              Navigator.pushNamed(context, AppRoutes.historialScreen);
            },
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
          final waveMode = _waveMode(controller.estadoActual);
          final caudalColor = _caudalColor(controller.estadoActual);

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusIndicatorWidget(conectado: controller.conectado),
                const SizedBox(height: 15),

                // ── Tarjeta de caudal con animación de olas ──────────────
                Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 6,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      WaterWaveWidget(modo: waveMode),
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
                                  color: caudalColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Leyenda de umbrales ──────────────────────────────────
                const SizedBox(height: 8),
                _UmbralLegenda(),
                const SizedBox(height: 12),

                // ── Indicadores en tiempo real (ruido + estado) ──────────
                Row(
                  children: [
                    Expanded(
                      child: _SensorCard(
                        label: 'Nivel de Ruido',
                        value: '${controller.ruidoActual}',
                        unit: 'ADC',
                        icon: Icons.graphic_eq,
                        color: controller.ruidoActual > 1500
                            ? AppTheme.warningColor
                            : AppTheme.normalColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SensorCard(
                        label: 'Estado Sensor Fusion',
                        value: controller.estadoActual,
                        unit: '',
                        icon: controller.estadoActual == 'Posible Fuga'
                            ? Icons.warning_amber
                            : Icons.check_circle_outline,
                        color: controller.estadoActual == 'Posible Fuga'
                            ? AppTheme.warningColor
                            : AppTheme.normalColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Resultado de la IA ───────────────────────────────────
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
                      color:
                          controller.ultimaAlerta!.severidad == 'Crítica'
                              ? AppTheme.criticalColor
                              : (controller.ultimaAlerta!.severidad ==
                                        'Advertencia'
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
                // ── Leyenda de strikes activos ───────────────────────────
                _StrikesIndicator(strikes: controller.strikesFuga),
                const SizedBox(height: 5),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta compacta para mostrar un valor de sensor en tiempo real.
class _SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _SensorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              unit.isNotEmpty ? '$value $unit' : value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador visual de la regla de los 3 Strikes.
class _StrikesIndicator extends StatelessWidget {
  final int strikes;

  const _StrikesIndicator({required this.strikes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Strikes de Anomalía: ',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        ...List.generate(3, (i) {
          final active = i < strikes;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              Icons.bolt,
              size: 20,
              color: active ? AppTheme.warningColor : Colors.grey.shade300,
            ),
          );
        }),
        Text(
          ' ($strikes/3)',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

/// Leyenda compacta con los umbrales de referencia.
class _UmbralLegenda extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendaItem(
            color: AppTheme.normalColor,
            label: 'Normal',
            range: '≤ 0.5 L/min',
          ),
          _LegendaItem(
            color: AppTheme.warningColor,
            label: 'Anomalía',
            range: '0.5–5 L/min',
          ),
          _LegendaItem(
            color: AppTheme.criticalColor,
            label: 'Fuga',
            range: '> 5 L/min',
          ),
        ],
      ),
    );
  }
}

class _LegendaItem extends StatelessWidget {
  final Color color;
  final String label;
  final String range;

  const _LegendaItem({
    required this.color,
    required this.label,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          range,
          style: const TextStyle(color: Colors.black54, fontSize: 10),
        ),
      ],
    );
  }
}

