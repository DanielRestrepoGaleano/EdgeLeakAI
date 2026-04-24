import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../config/themes/app_theme.dart';

class HistorialScreen extends StatefulWidget {
  final DashboardController controller;

  const HistorialScreen({super.key, required this.controller});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  // Filtros locales
  String? _severidadFiltro;
  DateTimeRange? _rangoFechas;

  final List<String> _severidades = ['Crítica', 'Advertencia', 'Normal'];

  @override
  void initState() {
    super.initState();
    // Cargamos historial con filtros limpios al entrar
    widget.controller.limpiarFiltros();
  }

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _rangoFechas,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (rango != null) {
      setState(() => _rangoFechas = rango);
      _aplicarFiltros();
    }
  }

  void _aplicarFiltros() {
    widget.controller.aplicarFiltros(
      severidad: _severidadFiltro,
      desde: _rangoFechas?.start,
      hasta: _rangoFechas?.end.add(const Duration(hours: 23, minutes: 59)),
    );
  }

  void _limpiarFiltros() {
    setState(() {
      _severidadFiltro = null;
      _rangoFechas = null;
    });
    widget.controller.limpiarFiltros();
  }

  bool get _hayFiltrosActivos =>
      _severidadFiltro != null || _rangoFechas != null;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return Scaffold(
          appBar: AppBar(
            title: ctrl.modoSeleccion
                ? Text('${ctrl.seleccionados.length} seleccionado(s)')
                : const Text('Historial de Fugas'),
            actions: [
              if (ctrl.modoSeleccion) ...[
                // Cancelar selección
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: ctrl.cancelarSeleccion,
                  tooltip: 'Cancelar selección',
                ),
                // Eliminar seleccionados
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: ctrl.seleccionados.isEmpty
                      ? null
                      : () => _confirmarEliminacionMultiple(context),
                  tooltip: 'Eliminar seleccionados',
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              // ── Barra de filtros ───────────────────────────────────────
              _BarraFiltros(
                severidadSeleccionada: _severidadFiltro,
                severidades: _severidades,
                rangoFechas: _rangoFechas,
                hayFiltros: _hayFiltrosActivos,
                onSeveridadChanged: (v) {
                  setState(() => _severidadFiltro = v);
                  _aplicarFiltros();
                },
                onFechasTap: _seleccionarRango,
                onLimpiar: _limpiarFiltros,
              ),

              // ── Lista ──────────────────────────────────────────────────
              Expanded(
                child: ctrl.historialEventos.isEmpty
                    ? _EmptyState(hayFiltros: _hayFiltrosActivos)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: ctrl.historialEventos.length +
                            (ctrl.hayMasHistorial ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == ctrl.historialEventos.length) {
                            // Botón cargar más
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: ctrl.cargarMasHistorial,
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Cargar más'),
                              ),
                            );
                          }

                          final evento = ctrl.historialEventos[index];
                          final isSelected = ctrl.seleccionados
                              .contains(evento.id);

                          return _AlertaCard(
                            evento: evento,
                            isSelected: isSelected,
                            modoSeleccion: ctrl.modoSeleccion,
                            onLongPress: () {
                              if (evento.id != null) {
                                ctrl.activarModoSeleccion(evento.id!);
                              }
                            },
                            onTap: () {
                              if (ctrl.modoSeleccion && evento.id != null) {
                                ctrl.toggleSeleccion(evento.id!);
                              }
                            },
                            onEliminar: evento.id != null
                                ? () => _confirmarEliminacion(
                                      context,
                                      evento.id!,
                                    )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmarEliminacion(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar alerta'),
        content:
            const Text('¿Deseas eliminar esta alerta del historial local?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.controller.eliminarAlerta(id);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacionMultiple(BuildContext context) {
    final count = widget.controller.seleccionados.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar alertas'),
        content: Text(
          '¿Deseas eliminar $count alerta(s) seleccionada(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.controller.eliminarAlertasSeleccionadas();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos
// ─────────────────────────────────────────────────────────────────────────────

class _BarraFiltros extends StatelessWidget {
  final String? severidadSeleccionada;
  final List<String> severidades;
  final DateTimeRange? rangoFechas;
  final bool hayFiltros;
  final ValueChanged<String?> onSeveridadChanged;
  final VoidCallback onFechasTap;
  final VoidCallback onLimpiar;

  const _BarraFiltros({
    required this.severidadSeleccionada,
    required this.severidades,
    required this.rangoFechas,
    required this.hayFiltros,
    required this.onSeveridadChanged,
    required this.onFechasTap,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = rangoFechas != null
        ? '${_fmt(rangoFechas!.start)} – ${_fmt(rangoFechas!.end)}'
        : 'Todas las fechas';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Chip de fechas
                ActionChip(
                  avatar: Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: rangoFechas != null
                        ? AppTheme.primaryColor
                        : Colors.grey,
                  ),
                  label: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: rangoFechas != null
                          ? AppTheme.primaryColor
                          : Colors.black54,
                    ),
                  ),
                  side: BorderSide(
                    color: rangoFechas != null
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                  ),
                  onPressed: onFechasTap,
                ),
                const SizedBox(width: 8),
                // Chips de severidad
                ...['', ...severidades].map((sev) {
                  final isAll = sev.isEmpty;
                  final isSelected =
                      isAll ? severidadSeleccionada == null : severidadSeleccionada == sev;

                  Color chipColor;
                  if (isAll) {
                    chipColor = Colors.grey;
                  } else if (sev == 'Crítica') {
                    chipColor = AppTheme.criticalColor;
                  } else if (sev == 'Advertencia') {
                    chipColor = AppTheme.warningColor;
                  } else {
                    chipColor = AppTheme.normalColor;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        isAll ? 'Todas' : sev,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: chipColor,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? chipColor : Colors.grey.shade300,
                      ),
                      onSelected: (_) =>
                          onSeveridadChanged(isAll ? null : sev),
                    ),
                  );
                }),

                // Botón limpiar
                if (hayFiltros) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: onLimpiar,
                    icon: const Icon(Icons.clear_all, size: 14),
                    label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _AlertaCard extends StatelessWidget {
  final evento;
  final bool isSelected;
  final bool modoSeleccion;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final VoidCallback? onEliminar;

  const _AlertaCard({
    required this.evento,
    required this.isSelected,
    required this.modoSeleccion,
    required this.onLongPress,
    required this.onTap,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final color = evento.severidad == 'Crítica'
        ? AppTheme.criticalColor
        : evento.severidad == 'Advertencia'
            ? AppTheme.warningColor
            : AppTheme.normalColor;

    final fecha = evento.fecha;
    final fechaStr =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox o icono de severidad
              if (modoSeleccion)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? AppTheme.primaryColor : Colors.grey,
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    evento.severidad == 'Crítica'
                        ? Icons.error
                        : Icons.warning_amber,
                    color: color,
                    size: 20,
                  ),
                ),

              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            evento.severidad,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            evento.veredicto,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      evento.mensaje,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fechaStr,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Botón de eliminar individual
              if (!modoSeleccion && onEliminar != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onEliminar,
                  tooltip: 'Eliminar esta alerta',
                  iconSize: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hayFiltros;

  const _EmptyState({required this.hayFiltros});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hayFiltros ? Icons.search_off : Icons.history_toggle_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              hayFiltros
                  ? 'Sin resultados para los filtros aplicados'
                  : 'No hay incidencias guardadas',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
