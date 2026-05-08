import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:edgeleak/data/models/lectura_raw_model.dart';
import 'package:edgeleak/data/services/database_service.dart';

// =============================================================================
// Helpers
// =============================================================================

/// Genera un path de archivo temporal único para cada test.
String _tempDbPath() =>
    '${Directory.systemTemp.path}/edgeleak_test_${DateTime.now().microsecondsSinceEpoch}.db';

// =============================================================================
// TESTS
// =============================================================================

void main() {
  setUpAll(() {
    // Inicializar sqflite_common_ffi para poder abrir SQLite en tests de Dart/
    // Flutter sin necesitar un emulador Android o dispositivo físico.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService v6 — esquema y migración', () {
    // ─────────────────────────────────────────────────────────────────────────
    // test-53
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '53: DB v6 nueva crea tabla lecturas_raw con columna '
        '"picos" INTEGER DEFAULT 0', () async {
      // ESCENARIO REAL: Primer arranque de la app en un dispositivo limpio.
      // La base de datos se crea desde cero en versión 6, por lo que la tabla
      // lecturas_raw debe incluir la columna picos desde el momento inicial.
      // ENTRADA: DatabaseService con ruta en memoria (:memory:).
      // RESULTADO ESPERADO: PRAGMA table_info incluye columna "picos".
      final service = DatabaseService(testDbPath: ':memory:');
      final db = await service.database;

      final columns =
          await db.rawQuery('PRAGMA table_info(lecturas_raw)');
      final columnNames =
          columns.map((c) => c['name'] as String).toList();

      expect(
        columnNames.contains('picos'),
        isTrue,
        reason: 'La tabla lecturas_raw debe tener la columna "picos" en v6',
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-54
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '54: migración v5 → v6 ejecuta ALTER TABLE '
        'lecturas_raw ADD COLUMN picos INTEGER DEFAULT 0', () async {
      // ESCENARIO REAL: Usuario que tenía la app en v2.x actualiza a v3.0.
      // La DB existente estaba en versión 5 (sin columna picos).
      // Al abrir con DatabaseService v6, onUpgrade añade la columna picos sin
      // perder los registros existentes.
      // ENTRADA: DB creada manualmente en versión 5 (sin picos).
      // RESULTADO ESPERADO: tras abrir con DatabaseService v6, la columna
      //   "picos" existe en lecturas_raw.
      final tempPath = _tempDbPath();
      try {
        // Paso 1: crear una DB en versión 5 sin la columna picos
        final dbV5 = await databaseFactoryFfi.openDatabase(
          tempPath,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE historial(
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  veredicto TEXT, severidad TEXT, mensaje TEXT, fecha TEXT
                )
              ''');
              await db.execute('''
                CREATE TABLE usuarios(
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  correo TEXT UNIQUE, password TEXT,
                  es_temporal INTEGER DEFAULT 0,
                  rol TEXT DEFAULT 'operador',
                  primer_nombre TEXT DEFAULT '',
                  segundo_nombre TEXT DEFAULT '',
                  primer_apellido TEXT DEFAULT '',
                  segundo_apellido TEXT DEFAULT ''
                )
              ''');
              await db.execute('''
                CREATE TABLE lecturas_raw(
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  ruido INTEGER, flujo REAL, estado TEXT, timestamp TEXT
                )
              ''');
              await db.execute('''
                CREATE TABLE lecturas_resumen_5d(
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  fecha_inicio TEXT, fecha_fin TEXT,
                  flujo_promedio REAL, ruido_promedio REAL,
                  total_lecturas INTEGER, estado_predominante TEXT
                )
              ''');
              await db.execute('''
                CREATE TABLE historial_mensual(
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  fecha_inicio TEXT, fecha_fin TEXT,
                  num_anomalias INTEGER, num_fugas INTEGER,
                  flujo_promedio REAL, ruido_promedio REAL, resumen_json TEXT
                )
              ''');
            },
          ),
        );
        // Insertar una fila de referencia sin picos para verificar integridad
        await dbV5.insert('lecturas_raw', {
          'ruido': 900,
          'flujo': 0.3,
          'estado': 'Normal',
          'timestamp': '2025-01-01T03:00:00.000',
        });
        await dbV5.close();

        // Paso 2: abrir la misma DB con DatabaseService v6 → activa onUpgrade
        final service = DatabaseService(testDbPath: tempPath);
        final dbV6 = await service.database;

        // Paso 3: verificar que la columna picos fue añadida
        final columns =
            await dbV6.rawQuery('PRAGMA table_info(lecturas_raw)');
        final columnNames =
            columns.map((c) => c['name'] as String).toList();

        expect(
          columnNames.contains('picos'),
          isTrue,
          reason: 'onUpgrade v5→v6 debe añadir columna "picos"',
        );

        // Verificar que el registro previo a la migración sigue existente
        final rows = await dbV6.query('lecturas_raw');
        expect(rows.length, 1,
            reason: 'El registro pre-migración no debe perderse');
      } finally {
        // Limpiar el archivo temporal independientemente del resultado del test
        final f = File(tempPath);
        if (await f.exists()) await f.delete();
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-55
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '55: insertarLecturaRaw con picos=5 → recuperada con '
        'picos=5 en obtenerLecturasRaw()', () async {
      // ESCENARIO REAL: ESP32 v3.0 detecta 5 micro-picos en un intervalo de
      // 5 s; Flutter persiste la lectura completa (ruido + flujo + picos).
      // Al recuperar las lecturas, el campo picos debe conservar el valor
      // original para que BaselineService pueda usarlo en el análisis.
      // ENTRADA: LecturaRawModel con picos=5.
      // RESULTADO ESPERADO: obtenerLecturasRaw() retorna la lectura con picos=5.
      final service = DatabaseService(testDbPath: ':memory:');

      final lectura = LecturaRawModel(
        ruido: 850,
        flujo: 0.0,
        estado: 'Anomalía',
        timestamp: DateTime(2025, 1, 1, 2, 30),
        picos: 5,
      );

      await service.insertarLecturaRaw(lectura);
      final lecturas = await service.obtenerLecturasRaw(limit: 10);

      expect(lecturas.length, 1,
          reason: 'Debe haber exactamente 1 lectura en la DB');
      expect(
        lecturas.first.picos,
        5,
        reason: 'El campo picos debe persistir y recuperarse con valor 5',
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // test-56
    // ─────────────────────────────────────────────────────────────────────────
    test(
        '56: lectura insertada sin campo picos (fila pre-migración) → '
        'LecturaRawModel.fromMap resuelve picos = 0 (DEFAULT)', () async {
      // ESCENARIO REAL: Registros grabados antes de la migración v5→v6 no
      // tienen valor en la columna picos. El DEFAULT 0 de SQLite garantiza
      // que el campo devuelva 0 al ser leído, asegurando compatibilidad
      // hacia atrás sin romper el análisis de BaselineService.
      // ENTRADA: INSERT directo en lecturas_raw sin el campo picos.
      // RESULTADO ESPERADO: LecturaRawModel.picos == 0.
      final service = DatabaseService(testDbPath: ':memory:');
      final db = await service.database;

      // Insertar fila sin el campo picos para simular un registro antiguo
      await db.insert('lecturas_raw', {
        'ruido': 750,
        'flujo': 0.2,
        'estado': 'Normal',
        'timestamp': '2025-01-01T14:00:00.000',
        // 'picos' ausente → SQLite usará DEFAULT 0
      });

      final lecturas = await service.obtenerLecturasRaw(limit: 10);

      expect(lecturas.length, 1,
          reason: 'Debe recuperarse el registro insertado');
      expect(
        lecturas.first.picos,
        0,
        reason: 'Registro sin picos debe resolverse a 0 por el DEFAULT',
      );
    });
  });
}
