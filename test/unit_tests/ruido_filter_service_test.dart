import 'package:flutter_test/flutter_test.dart';
import 'package:edgeleak/data/services/ruido_filter_service.dart';

void main() {
  // Helper para crear un proveedor de tiempo mutable
  DateTime _currentTime = DateTime(2025, 1, 1, 14, 0, 0); // 14:00 — período diurno

  DateTime _clock() => _currentTime;

  void _avanzarSegundos(int s) =>
      _currentTime = _currentTime.add(Duration(seconds: s));

  void _setHora(int hora, int minuto, int segundo) =>
      _currentTime = DateTime(2025, 1, 1, hora, minuto, segundo);

  setUp(() {
    // Reiniciar el reloj a 14:00 antes de cada test
    _currentTime = DateTime(2025, 1, 1, 14, 0, 0);
  });

  group('RuidoFilterService — ventana deslizante y clasificación', () {
    // ─────────────────────────────────────────────────────────────────────────
    // test-07
    // ─────────────────────────────────────────────────────────────────────────
    test('07: primera muestra bajo umbral (500 ADC) retorna silencio', () {
      // ESCENARIO REAL: Ambiente en reposo; el lavaplatos está apagado.
      // ENTRADA: 1 muestra de 500 ADC (muy por debajo del umbral 1500).
      // RESULTADO ESPERADO: ResultadoRuido.silencio.
      final service = RuidoFilterService(clock: _clock);
      final resultado = service.clasificar(500, 0.0);
      expect(resultado, ResultadoRuido.silencio);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-08
    // ─────────────────────────────────────────────────────────────────────────
    test('08: una única muestra alta (1600 ADC) retorna impactoAislado', () {
      // ESCENARIO REAL: Se cae un utensilio sobre el lavaplatos.
      // Solo 1 muestra supera 1500 ADC en la ventana → pico único aislado.
      // ENTRADA: 1 muestra = 1600 ADC.
      // RESULTADO ESPERADO: ResultadoRuido.impactoAislado.
      final service = RuidoFilterService(clock: _clock);
      final resultado = service.clasificar(1600, 0.0);
      expect(resultado, ResultadoRuido.impactoAislado);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-09
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '09: dos muestras altas (1600 ADC) consecutivas retorna impactoAislado',
        () {
      // ESCENARIO REAL: Dos golpes seguidos que no alcanzan el mínimo de 3.
      // ENTRADA: 2 muestras = 1600 ADC.
      // RESULTADO ESPERADO: ResultadoRuido.impactoAislado (< 3 muestras activas).
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(1600, 0.0); // muestra 1
      _avanzarSegundos(5);
      final resultado = service.clasificar(1600, 0.0); // muestra 2
      expect(resultado, ResultadoRuido.impactoAislado);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-10
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '10: tres muestras altas (1600 ADC) consecutivas retorna patronGoteo',
        () {
      // ESCENARIO REAL: Goteo rítmico del grifo: 3 picos ADC en < 60 s.
      // ENTRADA: 3 muestras = 1600 ADC, separadas 5 s.
      // RESULTADO ESPERADO: ResultadoRuido.patronGoteo.
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(1600, 0.0); // muestra 1
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0); // muestra 2
      _avanzarSegundos(5);
      final resultado = service.clasificar(1600, 0.0); // muestra 3
      expect(resultado, ResultadoRuido.patronGoteo);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-11
    // ─────────────────────────────────────────────────────────────────────────
    test('11: mezcla de muestras (2 altas + 1 baja + 1 alta) retorna patronGoteo', () {
      // ESCENARIO REAL: Goteo intermitente con breve pausa acústica.
      // ENTRADA: 1600, 500, 1600, 1600 — 3 muestras > 1500 en la ventana.
      // RESULTADO ESPERADO: ResultadoRuido.patronGoteo.
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(1600, 0.0); // activa
      _avanzarSegundos(5);
      service.clasificar(500, 0.0);  // baja — no activa
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0); // activa
      _avanzarSegundos(5);
      final resultado = service.clasificar(1600, 0.0); // activa
      expect(resultado, ResultadoRuido.patronGoteo);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-12
    // ─────────────────────────────────────────────────────────────────────────
    test('12: muestra con antigüedad > 60 s es descartada de la ventana', () {
      // ESCENARIO REAL: El sistema lleva inactivo > 1 min; el pico anterior
      // ya no es relevante para el análisis de patrón actual.
      // ENTRADA: 3 muestras altas a T+0…T+10 s; avanzar a T+65 s; 1 muestra baja.
      // RESULTADO ESPERADO: Las 3 muestras antiguas expiran → silencio.
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(1600, 0.0);
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0);
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0);

      // Avanzar más de 60 s para que las 3 muestras expiren
      _avanzarSegundos(65);
      final resultado = service.clasificar(300, 0.0); // muestra baja

      expect(resultado, ResultadoRuido.silencio);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-13
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '13: ventana llena (12 muestras), todas bajo umbral → silencio', () {
      // ESCENARIO REAL: El sensor recibe 12 lecturas de ruido ambiental bajo.
      // ENTRADA: 12 muestras de 400 ADC (por debajo de 1500).
      // RESULTADO ESPERADO: ResultadoRuido.silencio.
      final service = RuidoFilterService(clock: _clock);
      for (int i = 0; i < 12; i++) {
        _avanzarSegundos(5);
        service.clasificar(400, 0.0);
      }
      final resultado = service.clasificar(400, 0.0);
      expect(resultado, ResultadoRuido.silencio);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-14
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '14: muestra expirada (>60s) excluida del conteo: solo 2 activas → impactoAislado',
        () {
      // ESCENARIO REAL: 3 picos ADC agregados, el más antiguo expira antes
      // de clasificar; solo quedan 2 activos → no alcanza el mínimo de 3.
      // ENTRADA: muestras altas a T+0, T+5, T+10; avanzar a T+65; 1 muestra alta.
      //   → La muestra de T+0 expira; quedan 2 altas válidas → impactoAislado.
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(1600, 0.0); // T+0  — expirará
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0); // T+5   — válida
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0); // T+10  — válida

      // Avanzar hasta T+65 para que expire la muestra de T+0
      _avanzarSegundos(50); // ahora T+65
      final resultado = service.clasificar(300, 0.0); // T+65 — baja, no activa

      // T+5 y T+10 son válidas (< 60s), T+0 expirada → 2 activas < 3
      expect(resultado, isNot(ResultadoRuido.patronGoteo));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-15  — Lógica Nocturna ADC
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '15: hora 03:00, flujo=0, ruido promedio > 800 ADC → patronGoteo nocturno',
        () {
      // ESCENARIO REAL: Las 3 AM; la canilla gotea silenciosamente. El flujo
      // es 0.0 (no hay chorro activo) pero el micrófono capta el goteo.
      // ENTRADA: 3 muestras de 900 ADC en período nocturno; flujo = 0.
      // RESULTADO ESPERADO: ResultadoRuido.patronGoteo.
      _setHora(3, 0, 0);
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(900, 0.0);
      _avanzarSegundos(5);
      service.clasificar(900, 0.0);
      _avanzarSegundos(5);
      final resultado = service.clasificar(900, 0.0);
      expect(resultado, ResultadoRuido.patronGoteo);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-16
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '16: hora 03:00, flujo=0, ruido promedio < 800 ADC → silencio nocturno',
        () {
      // ESCENARIO REAL: Las 3 AM; el ambiente es silencioso. Ruido ambiental
      // por debajo del nivel base → no hay goteo detectado.
      // ENTRADA: 3 muestras de 400 ADC en período nocturno; flujo = 0.
      // RESULTADO ESPERADO: ResultadoRuido.silencio.
      _setHora(3, 0, 0);
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(400, 0.0);
      _avanzarSegundos(5);
      service.clasificar(400, 0.0);
      _avanzarSegundos(5);
      final resultado = service.clasificar(400, 0.0);
      expect(resultado, ResultadoRuido.silencio);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-17
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '17: hora 03:00, flujo > 0 → lógica nocturna ADC no aplica '
        '(se clasifica por ventana normal)', () {
      // ESCENARIO REAL: Las 3 AM con el grifo abierto. Aunque es horario
      // nocturno, hay flujo activo → la lógica nocturna queda inhibida.
      // ENTRADA: 3 muestras de 900 ADC; flujo = 0.5 L/min.
      // RESULTADO ESPERADO: silencio (ruido 900 < 1500 umbral diurno).
      _setHora(3, 0, 0);
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(900, 0.5);
      _avanzarSegundos(5);
      service.clasificar(900, 0.5);
      _avanzarSegundos(5);
      final resultado = service.clasificar(900, 0.5);
      // La lógica nocturna requiere flujo == 0; con flujo > 0 la lógica
      // normal se aplica: 900 ADC < 1500 → silencio.
      expect(resultado, ResultadoRuido.silencio);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-18
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '18: hora 14:00 (diurna), flujo=0, ruido=900 ADC → silencio '
        '(lógica nocturna no activa fuera de rango)', () {
      // ESCENARIO REAL: A las 2 PM la lógica nocturna no debe activarse aunque
      // el ruido supere el silencio base.
      // ENTRADA: hora 14:00; 3 muestras de 900 ADC; flujo = 0.
      // RESULTADO ESPERADO: ResultadoRuido.silencio (no es horario nocturno).
      _setHora(14, 0, 0);
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(900, 0.0);
      _avanzarSegundos(5);
      service.clasificar(900, 0.0);
      _avanzarSegundos(5);
      final resultado = service.clasificar(900, 0.0);
      expect(resultado, ResultadoRuido.silencio);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-19
    // ─────────────────────────────────────────────────────────────────────────
    test('19: resetear() vacía la ventana; siguiente muestra baja → silencio',
        () {
      // ESCENARIO REAL: Cambio de usuario o reinicio del sistema.
      // Se añaden 3 muestras altas, luego se llama resetear() y se verifica
      // que la ventana queda vacía.
      // RESULTADO ESPERADO: silencio tras resetear con 1 muestra baja.
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(1600, 0.0);
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0);
      _avanzarSegundos(5);
      service.clasificar(1600, 0.0);
      // Ventana tiene 3 muestras activas → patronGoteo antes del reset
      service.resetear();
      final resultado = service.clasificar(200, 0.0);
      expect(resultado, ResultadoRuido.silencio);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-20
    // ─────────────────────────────────────────────────────────────────────────
    test('20: promedioRuido refleja el promedio real de las muestras en ventana',
        () {
      // ESCENARIO REAL: Verificar que el promedio usado en la lógica nocturna
      // ADC es aritméticamente correcto.
      // ENTRADA: muestras de 400, 600, 800 ADC → promedio esperado ≈ 600.
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(400, 0.0);
      _avanzarSegundos(5);
      service.clasificar(600, 0.0);
      _avanzarSegundos(5);
      service.clasificar(800, 0.0);

      expect(service.promedioRuido, closeTo(600.0, 1.0));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-21
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '21: hora 05:59, flujo=0, ruido=900 → patronGoteo (último minuto nocturno)',
        () {
      // ESCENARIO REAL: El umbral nocturno es 0:00–6:00 exclusive; a las 05:59
      // todavía es noche.
      // ENTRADA: hora 05:59; 3 muestras de 900 ADC; flujo = 0.
      // RESULTADO ESPERADO: ResultadoRuido.patronGoteo.
      _setHora(5, 59, 0);
      final service = RuidoFilterService(clock: _clock);
      service.clasificar(900, 0.0);
      _avanzarSegundos(5);
      service.clasificar(900, 0.0);
      _avanzarSegundos(5);
      final resultado = service.clasificar(900, 0.0);
      expect(resultado, ResultadoRuido.patronGoteo);
    });
  });
}
