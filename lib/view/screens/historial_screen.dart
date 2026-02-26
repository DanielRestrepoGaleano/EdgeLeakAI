import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../config/themes/app_theme.dart';

class HistorialScreen extends StatelessWidget {
  final DashboardController controller;

  const HistorialScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Sqflite'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.historialEventos.isEmpty) {
            return const Center(child: Text('No hay incidencias guardadas en la base de datos.'));
          }

          return ListView.builder(
            itemCount: controller.historialEventos.length,
            itemBuilder: (context, index) {
              final evento = controller.historialEventos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(
                    evento.severidad == 'Crítica' ? Icons.error : Icons.warning,
                    color: evento.severidad == 'Crítica' ? AppTheme.criticalColor : AppTheme.warningColor,
                  ),
                  title: Text(evento.veredicto, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${evento.fecha.day}/${evento.fecha.month} ${evento.fecha.hour}:${evento.fecha.minute} - ${evento.mensaje}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
