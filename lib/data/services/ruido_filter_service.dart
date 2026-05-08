import 'package:flutter/foundation.dart';
import '../../config/time_provider.dart';

/// Resultado del análisis del filtro digital de ruido.
enum ResultadoRuido {
  /// No hay actividad acústica relevante.
  silencio,

  /// Impacto fuerte y aislado (ej. caída de un utensilio). Debe ignorarse como fuga.
  impactoAislado,

  /// Patrón rítmico sostenido consistente con goteo de agua.
  patronGoteo,
}

/// Registro interno de una muestra de ruido con su marca temporal.
class _MuestraRuido {
  final int valor;
  final DateTime timestamp;
  _MuestraRuido(this.valor, this.timestamp);
}

/// Servicio de filtrado digital del sensor de ruido KY-037.
///
/// Implementa dos mecanismos de clasificación:
///
/// 1. **Filtro de ventana deslizante**: distingue entre un impacto fuerte
///    aislado (un único pico por encima del umbral rodeado de silencio) y un
///    patrón rítmico sostenido (múltiples muestras consecutivas sobre el umbral
///    en una ventana temporal de [_duracionVentana]).
///
/// 2. **Lógica Nocturna**: si el sensor de flujo reporta 0.0 L/min durante el
///    horario nocturno ([_horaInicioNoche]–[_horaFinNoche]) y el ruido promedio
///    de la ventana supera el nivel de silencio base ([_umbralSilencioBase]),
///    el sistema clasifica la lectura como [ResultadoRuido.patronGoteo] para
///    habilitar la detección de goteo en la boquilla sin flujo activo.
class RuidoFilterService {
  // ── Umbrales de calibración ─────────────────────────────────────────────────

  /// Valor ADC a partir del cual se considera que hay ruido significativo.
  static const int _umbralRuido = 1500;

  /// Nivel ADC base de silencio ambiental (sin actividad de agua).
  static const int _umbralSilencioBase = 800;

  /// Número mínimo de muestras por encima del umbral dentro de la ventana
  /// para clasificar el evento como patrón rítmico de goteo.
  static const int _minimoMuestrasGoteo = 3;

  /// Tamaño máximo de la ventana deslizante (muestras).
  static const int _tamanoVentana = 12;

  /// Ventana temporal máxima considerada para el análisis de patrón.
  static const Duration _duracionVentana = Duration(seconds: 60);

  // ── Lógica Nocturna ─────────────────────────────────────────────────────────

  /// Hora de inicio del período nocturno (0 = medianoche).
  static const int _horaInicioNoche = 0;

  /// Hora de fin del período nocturno (exclusive).
  static const int _horaFinNoche = 6;

  // ── Estado interno ──────────────────────────────────────────────────────────

  final List<_MuestraRuido> _ventana = [];

  /// Proveedor de tiempo inyectable para habilitar time-travelling en tests.
  final TimeProvider _clock;

  RuidoFilterService({TimeProvider? clock}) : _clock = clock ?? DateTime.now;

  // ---------------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------------

  /// Registra una nueva muestra de ruido [valorAdC] y devuelve el resultado
  /// del análisis de patrón considerando también el [flujo] actual y la hora.
  ResultadoRuido clasificar(int valorAdC, double flujo) {
    _agregarMuestra(valorAdC);

    // Comprobar lógica nocturna primero
    if (_esAnomaliaNoct(flujo)) {
      debugPrint(
          '[RuidoFilter] 🌙 Lógica nocturna activa: flujo=0, ruido constante detectado.');
      return ResultadoRuido.patronGoteo;
    }

    // Contar muestras sobre umbral en la ventana actual
    final muestrasActivas =
        _ventana.where((m) => m.valor > _umbralRuido).length;

    if (muestrasActivas == 0) {
      return ResultadoRuido.silencio;
    }

    if (muestrasActivas >= _minimoMuestrasGoteo) {
      debugPrint(
          '[RuidoFilter] 💧 Patrón de goteo detectado: $muestrasActivas/${_ventana.length} muestras activas.');
      return ResultadoRuido.patronGoteo;
    }

    // Pico único → impacto aislado
    debugPrint(
        '[RuidoFilter] 🔨 Impacto aislado ($muestrasActivas muestras): ignorado como fuga.');
    return ResultadoRuido.impactoAislado;
  }

  /// Calcula el valor promedio de las muestras en la ventana actual.
  double get promedioRuido {
    if (_ventana.isEmpty) return 0.0;
    return _ventana.map((m) => m.valor).reduce((a, b) => a + b) /
        _ventana.length;
  }

  /// Limpia la ventana deslizante (útil al reiniciar o al cambiar sesión).
  void resetear() => _ventana.clear();

  // ---------------------------------------------------------------------------
  // Métodos privados
  // ---------------------------------------------------------------------------

  void _agregarMuestra(int valor) {
    final ahora = _clock();
    _ventana.add(_MuestraRuido(valor, ahora));

    // Eliminar muestras fuera de la ventana temporal
    _ventana.removeWhere((m) => ahora.difference(m.timestamp) > _duracionVentana);

    // Mantener el límite de tamaño
    if (_ventana.length > _tamanoVentana) {
      _ventana.removeAt(0);
    }
  }

  /// Retorna [true] si se cumplen las condiciones de anomalía nocturna:
  /// - Hora entre [_horaInicioNoche] y [_horaFinNoche]
  /// - Flujo = 0.0 L/min
  /// - Ruido promedio de la ventana superior al silencio base
  /// - Ventana con suficientes muestras para ser estadísticamente válida
  bool _esAnomaliaNoct(double flujo) {
    final hora = _clock().hour;
    final esNoche = hora >= _horaInicioNoche && hora < _horaFinNoche;

    if (!esNoche || flujo > 0.0 || _ventana.length < 3) return false;

    return promedioRuido > _umbralSilencioBase;
  }
}
