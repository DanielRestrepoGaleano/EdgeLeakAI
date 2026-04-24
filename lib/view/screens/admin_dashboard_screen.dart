import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../config/themes/app_theme.dart';
import '../../config/routes/app_routes.dart';

/// Pantalla exclusiva para administradores.
///
/// Se enfoca en el **monitoreo del sistema** (lecturas del sensor, estado de
/// Sensor Fusion, estadísticas) y no expone el simulador de hardware, que es
/// una herramienta de desarrollo reservada para operadores.
class AdminDashboardScreen extends StatelessWidget {
  final DashboardController controller;
  final AuthController authController;

  const AdminDashboardScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        title: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Panel de Administrador',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Hola, ${controller.usuarioLogueado}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.adminUsersScreen),
            tooltip: 'Gestión de Usuarios',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              controller.inicializarHistorial();
              Navigator.pushNamed(context, AppRoutes.historialScreen);
            },
            tooltip: 'Historial de Fugas',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.loginScreen,
            ),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Estado del sistema ──────────────────────────────────────
                _SectionTitle(title: 'Estado del Sistema', icon: Icons.monitor_heart),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        label: 'Sensor Fusion',
                        value: controller.estadoActual,
                        color: _colorPorEstado(controller.estadoActual),
                        icon: Icons.sensors,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        label: 'Caudal Actual',
                        value:
                            '${controller.caudalActual.toStringAsFixed(2)} L/min',
                        color: _colorPorCaudal(controller.caudalActual),
                        icon: Icons.water_drop,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        label: 'Alertas totales',
                        value: '${controller.historialEventos.length}',
                        color: AppTheme.primaryColor,
                        icon: Icons.notifications_active,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        label: 'Última severidad',
                        value: controller.historialEventos.isNotEmpty
                            ? controller.historialEventos.first.severidad
                            : 'Sin datos',
                        color: controller.historialEventos.isNotEmpty
                            ? _colorPorSeveridad(
                                controller.historialEventos.first.severidad,
                              )
                            : Colors.grey,
                        icon: Icons.warning_amber,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Contexto UX ──────────────────────────────────────────────
                _SectionTitle(
                  title: '¿Qué significan los datos?',
                  icon: Icons.help_outline,
                ),
                const SizedBox(height: 8),
                const _ContextCard(),

                const SizedBox(height: 24),

                // ── Buffer de lecturas recientes ────────────────────────────
                _SectionTitle(
                  title: 'Lecturas Recientes del Sensor (ESP32)',
                  icon: Icons.table_rows_outlined,
                ),
                const SizedBox(height: 8),
                controller.bufferLecturas.isEmpty
                    ? _EmptyBufferCard()
                    : _BufferTable(lecturas: controller.bufferLecturas),

                const SizedBox(height: 24),

                // ── Última alerta de IA ─────────────────────────────────────
                if (controller.iaProcesando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                        SizedBox(width: 12),
                        Text(
                          'Groq AI analizando...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                else if (controller.ultimaAlerta != null) ...[
                  _SectionTitle(
                    title: 'Último Veredicto IA',
                    icon: Icons.psychology,
                  ),
                  const SizedBox(height: 8),
                  _AlertaBanner(alerta: controller.ultimaAlerta!),
                ],

                const SizedBox(height: 24),

                // ── Accesos rápidos ─────────────────────────────────────────
                _SectionTitle(title: 'Accesos Rápidos', icon: Icons.apps),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.manage_accounts,
                        label: 'Gestión de\nUsuarios',
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.adminUsersScreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.history,
                        label: 'Historial de\nFugas',
                        color: AppTheme.warningColor,
                        onTap: () {
                          controller.inicializarHistorial();
                          Navigator.pushNamed(
                            context,
                            AppRoutes.historialScreen,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _colorPorEstado(String estado) {
    switch (estado) {
      case 'Uso Normal':
        return AppTheme.normalColor;
      case 'Posible Fuga':
        return AppTheme.criticalColor;
      case 'Sin Clasificar':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  Color _colorPorCaudal(double caudal) {
    if (caudal <= 0.5) return AppTheme.normalColor;
    if (caudal <= 5.0) return AppTheme.warningColor;
    return AppTheme.criticalColor;
  }

  Color _colorPorSeveridad(String severidad) {
    switch (severidad) {
      case 'Crítica':
        return AppTheme.criticalColor;
      case 'Advertencia':
        return AppTheme.warningColor;
      default:
        return AppTheme.normalColor;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatusCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💧 L/min (Litros por minuto)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Es la unidad que mide cuántos litros de agua fluyen a través de la tubería en un minuto.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          const Text(
            '📊 Umbrales de Detección',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _ThresholdRow(
            color: AppTheme.normalColor,
            label: 'Normal',
            range: '0.1 – 0.5 L/min',
            description: 'Uso doméstico regular del lavaplatos.',
          ),
          const SizedBox(height: 6),
          _ThresholdRow(
            color: AppTheme.warningColor,
            label: 'Anomalía',
            range: '0.5 – 5.0 L/min',
            description: 'Flujo elevado, posible mal uso o pre-fuga.',
          ),
          const SizedBox(height: 6),
          _ThresholdRow(
            color: AppTheme.criticalColor,
            label: 'Fuga',
            range: '> 5.0 L/min',
            description: 'Fuga activa. Intervención inmediata requerida.',
          ),
          const SizedBox(height: 14),
          const Text(
            '🔊 Sensor de Ruido (ADC)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'El sensor KY-038 mide vibraciones acústicas en la tubería (pin D34, rango 0–4095 ADC). '
            'Un valor superior a 1500 combinado con caudal bajo indica posible fuga por grieta. '
            'La detección digital (pin D35) genera alerta instantánea ante golpes de agua (water hammer).',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          const Text(
            '⚙️ Lógica de Sensor Fusion',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '• Ruido > 1500 + Flujo > 0.5 L/min → Uso Normal\n'
            '• Ruido > 1500 + Flujo < 0.1 L/min → Posible Fuga\n'
            '• 3 lecturas consecutivas de "Posible Fuga" (~15 s) → Groq AI evalúa',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final Color color;
  final String label;
  final String range;
  final String description;

  const _ThresholdRow({
    required this.color,
    required this.label,
    required this.range,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label ($range): ',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBufferCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        children: [
          Icon(Icons.sensors_off, color: Colors.white30, size: 36),
          SizedBox(height: 8),
          Text(
            'Sin lecturas del ESP32',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Conecta el hardware y envía datos al\nendpoint POST /api/sensor',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BufferTable extends StatelessWidget {
  final List<Map<String, dynamic>> lecturas;

  const _BufferTable({required this.lecturas});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Cabecera
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF21262D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Hora',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Flujo',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Ruido',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Estado',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Filas (las más recientes primero)
          ...lecturas.reversed.take(10).map((lectura) {
            final ts = DateTime.tryParse(lectura['timestamp'] as String? ?? '');
            final horaStr = ts != null
                ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}'
                : '--:--:--';
            final estado = lectura['estado'] as String? ?? '?';
            final color = _colorPorEstado(estado);

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      horaStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${(lectura['flujo'] as num).toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${lectura['ruido']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      estado,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _colorPorEstado(String estado) {
    switch (estado) {
      case 'Uso Normal':
        return AppTheme.normalColor;
      case 'Posible Fuga':
        return AppTheme.criticalColor;
      default:
        return AppTheme.warningColor;
    }
  }
}

class _AlertaBanner extends StatelessWidget {
  final alerta;

  const _AlertaBanner({required this.alerta});

  @override
  Widget build(BuildContext context) {
    final color = alerta.severidad == 'Crítica'
        ? AppTheme.criticalColor
        : alerta.severidad == 'Advertencia'
            ? AppTheme.warningColor
            : AppTheme.normalColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            alerta.severidad == 'Crítica' ? Icons.warning : Icons.info_outline,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta.veredicto,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alerta.mensaje,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}
