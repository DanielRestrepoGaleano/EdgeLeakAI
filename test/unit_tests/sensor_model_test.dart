import 'package:flutter_test/flutter_test.dart';
import 'package:edgeleak/data/models/lectura_sensor_model.dart';

void main() {
  group('LecturaSensorModel — serialización y defaults', () {
    // ─────────────────────────────────────────────────────────────────────────
    // test-01
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '01: fromJson con los tres campos presentes asigna correctamente '
        'ruido, flujo y picos', () {
      // ESCENARIO REAL: Lectura normal del ESP32 cada 5 s en ciclo estable.
      // ENTRADA: payload { ruido:820, flujo:0.3, picos:2 }
      // RESULTADO ESPERADO: Modelo construido con los tres valores exactos.
      final json = <String, dynamic>{'ruido': 820, 'flujo': 0.3, 'picos': 2};
      final model = LecturaSensorModel.fromJson(json);

      expect(model.ruido, 820);
      expect(model.caudalLPM, closeTo(0.3, 0.001));
      expect(model.picos, 2);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-02
    // ─────────────────────────────────────────────────────────────────────────
    test('02: fromJson sin campo "picos" lanza FormatException', () {
      // ESCENARIO REAL: Firmware v2 sin actualizar no incluye el campo picos.
      // ENTRADA: { ruido:500, flujo:0.5 } — campo picos ausente.
      // RESULTADO ESPERADO: FormatException (campo requerido ausente).
      final json = <String, dynamic>{'ruido': 500, 'flujo': 0.5};
      expect(
        () => LecturaSensorModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-03
    // ─────────────────────────────────────────────────────────────────────────
    test('03: fromJson con picos = -1 lanza FormatException', () {
      // ESCENARIO REAL: Bug de firmware: el contador de picos retorna -1 por
      // desbordamiento aritmético del entero en el ESP32.
      // ENTRADA: { ruido:500, flujo:0.5, picos:-1 }
      // RESULTADO ESPERADO: FormatException (picos debe ser >= 0).
      final json = <String, dynamic>{'ruido': 500, 'flujo': 0.5, 'picos': -1};
      expect(
        () => LecturaSensorModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-04
    // ─────────────────────────────────────────────────────────────────────────
    test('04: toJson incluye los tres campos con tipos correctos', () {
      // ESCENARIO REAL: Serializar una lectura para incluirla en el payload
      // enviado a Groq como contexto de la lectura actual.
      // ENTRADA: modelo con ruido=1200, caudalLPM=1.5, picos=5
      // RESULTADO ESPERADO: mapa con claves ruido(int), flujo(double), picos(int).
      final model = LecturaSensorModel(
        ruido: 1200,
        caudalLPM: 1.5,
        picos: 5,
        timestamp: DateTime(2025, 6, 1, 14, 0),
      );
      final json = model.toJson();

      expect(json['ruido'], isA<int>());
      expect(json['flujo'], isA<double>());
      expect(json['picos'], isA<int>());
      expect(json['ruido'], 1200);
      expect(json['flujo'], closeTo(1.5, 0.001));
      expect(json['picos'], 5);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-05
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '05: fromJson con flujo como string numérico lanza FormatException', () {
      // ESCENARIO REAL: Firmware con bug de serialización JSON envía "1.5"
      // (cadena) en lugar de 1.5 (número). El sistema debe rechazarlo.
      // ENTRADA: { ruido:500, flujo:"1.5", picos:2 }
      // RESULTADO ESPERADO: FormatException (flujo debe ser numérico).
      final json = <String, dynamic>{
        'ruido': 500,
        'flujo': '1.5',
        'picos': 2
      };
      expect(
        () => LecturaSensorModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-06
    // ─────────────────────────────────────────────────────────────────────────
    test('06: toMap / fromMap ida y vuelta sin pérdida de datos (incl. picos)',
        () {
      // ESCENARIO REAL: Lectura guardada en SQLite (toMap) y posteriormente
      // recuperada del cursor (fromMap) para el cálculo del baseline.
      // ENTRADA: modelo completo con picos=7 y timestamp fijo.
      // RESULTADO ESPERADO: Reconstrucción exacta sin pérdida de ningún campo.
      final original = LecturaSensorModel(
        ruido: 950,
        caudalLPM: 0.8,
        picos: 7,
        timestamp: DateTime(2025, 6, 1, 3, 15),
      );
      final map = original.toMap();
      final recovered = LecturaSensorModel.fromMap(map);

      expect(recovered.ruido, original.ruido);
      expect(recovered.caudalLPM, closeTo(original.caudalLPM, 0.001));
      expect(recovered.picos, original.picos);
    });
  });
}
