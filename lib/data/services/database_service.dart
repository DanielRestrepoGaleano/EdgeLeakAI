import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/alerta_fuga_model.dart';
import '../models/lectura_raw_model.dart';
import '../models/lectura_resumen_model.dart';
import '../models/historial_mensual_model.dart';
import '../models/usuario_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'edgeleak_v5.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE historial(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            veredicto TEXT,
            severidad TEXT,
            mensaje TEXT,
            fecha TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE usuarios(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            primer_nombre TEXT DEFAULT '',
            segundo_nombre TEXT DEFAULT '',
            primer_apellido TEXT DEFAULT '',
            segundo_apellido TEXT DEFAULT '',
            correo TEXT UNIQUE,
            password TEXT,
            es_temporal INTEGER DEFAULT 0,
            rol TEXT DEFAULT 'operador'
          )
        ''');

        await db.execute('''
          CREATE TABLE lecturas_raw(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ruido INTEGER,
            flujo REAL,
            estado TEXT,
            timestamp TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE lecturas_resumen_5d(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha_inicio TEXT,
            fecha_fin TEXT,
            flujo_promedio REAL,
            ruido_promedio REAL,
            total_lecturas INTEGER,
            estado_predominante TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE historial_mensual(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha_inicio TEXT,
            fecha_fin TEXT,
            num_anomalias INTEGER,
            num_fugas INTEGER,
            flujo_promedio REAL,
            ruido_promedio REAL,
            resumen_json TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE usuarios ADD COLUMN rol TEXT DEFAULT 'operador'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE usuarios ADD COLUMN primer_nombre TEXT DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE usuarios ADD COLUMN segundo_nombre TEXT DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE usuarios ADD COLUMN primer_apellido TEXT DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE usuarios ADD COLUMN segundo_apellido TEXT DEFAULT ''",
          );
          await db.execute(
            "UPDATE usuarios SET primer_nombre = nombre WHERE nombre IS NOT NULL AND nombre != ''",
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS lecturas_raw(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ruido INTEGER,
              flujo REAL,
              estado TEXT,
              timestamp TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS lecturas_resumen_5d(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fecha_inicio TEXT,
              fecha_fin TEXT,
              flujo_promedio REAL,
              ruido_promedio REAL,
              total_lecturas INTEGER,
              estado_predominante TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS historial_mensual(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fecha_inicio TEXT,
              fecha_fin TEXT,
              num_anomalias INTEGER,
              num_fugas INTEGER,
              flujo_promedio REAL,
              ruido_promedio REAL,
              resumen_json TEXT
            )
          ''');
        }
      },
    );
  }

  // === MÉTODOS DE USUARIOS (CRUD COMPLETO) ===

  // Soluciona el error de "obtenerTodosLosUsuarios" en el controlador
  Future<List<UsuarioModel>> obtenerTodosLosUsuarios() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('usuarios');
    return maps.map((e) => UsuarioModel.fromMap(e)).toList();
  }

  // Soluciona el error de "eliminarUsuario" en el controlador
  Future<int> eliminarUsuario(int id) async {
    final db = await database;
    return await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  // Soluciona el error de "actualizarUsuario" en el controlador
  Future<int> actualizarUsuario(UsuarioModel usuario) async {
    final db = await database;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  // Tu método esencial para validación por correo
  Future<UsuarioModel?> obtenerUsuarioPorCorreo(String correo) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'correo = ?',
      whereArgs: [correo],
    );

    if (maps.isNotEmpty) return UsuarioModel.fromMap(maps.first);
    return null;
  }

  // === MÉTODOS COMPLEMENTARIOS ===

  Future<bool> registrarUsuario(UsuarioModel usuario) async {
    final db = await database;
    try {
      await db.insert('usuarios', usuario.toMap());
      return true;
    } catch (e) {
      return false; 
    }
  }

  Future<UsuarioModel?> loginUsuario(String correo, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'correo = ? AND password = ?',
      whereArgs:[correo, password],
    );

    if (maps.isNotEmpty) return UsuarioModel.fromMap(maps.first);
    return null;
  }

  Future<void> actualizarPassword(int id, String newPassword, bool esTemporal) async {
    final db = await database;
    await db.update(
      'usuarios',
      {'password': newPassword, 'es_temporal': esTemporal ? 1 : 0},
      where: 'id = ?',
      whereArgs:[id],
    );
  }

  // === MÉTODOS DE HISTORIAL ===

  Future<void> insertarAlerta(AlertaFugaModel alerta) async {
    final db = await database;
    await db.insert(
      'historial',
      alerta.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AlertaFugaModel>> obtenerHistorial() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'historial',
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => AlertaFugaModel.fromMap(maps[i]));
  }

  /// Devuelve el historial paginado con filtros opcionales de severidad y rango de fechas.
  Future<List<AlertaFugaModel>> obtenerHistorialFiltrado({
    String? severidad,
    DateTime? desde,
    DateTime? hasta,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;

    final List<String> where = [];
    final List<dynamic> args = [];

    if (severidad != null && severidad.isNotEmpty) {
      where.add('severidad = ?');
      args.add(severidad);
    }
    if (desde != null) {
      where.add("fecha >= ?");
      args.add(desde.toIso8601String());
    }
    if (hasta != null) {
      where.add("fecha <= ?");
      args.add(hasta.toIso8601String());
    }

    final maps = await db.query(
      'historial',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map(AlertaFugaModel.fromMap).toList();
  }

  Future<int> eliminarAlerta(int id) async {
    final db = await database;
    return db.delete('historial', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminarAlertas(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(', ');
    return db.delete(
      'historial',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  // === MÉTODOS DE LECTURAS RAW ===

  Future<void> insertarLecturaRaw(LecturaRawModel lectura) async {
    final db = await database;
    await db.insert(
      'lecturas_raw',
      lectura.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retorna las últimas [limit] lecturas crudas, ordenadas del más reciente al más antiguo.
  Future<List<LecturaRawModel>> obtenerLecturasRaw({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'lecturas_raw',
      orderBy: 'id DESC',
      limit: limit,
    );
    return maps.map(LecturaRawModel.fromMap).toList();
  }

  /// Retorna todas las lecturas crudas de los últimos [dias] días.
  Future<List<LecturaRawModel>> obtenerLecturasRawRecientes(
      {required int dias}) async {
    final db = await database;
    final desde = DateTime.now().subtract(Duration(days: dias)).toIso8601String();
    final maps = await db.query(
      'lecturas_raw',
      where: 'timestamp >= ?',
      whereArgs: [desde],
      orderBy: 'timestamp ASC',
    );
    return maps.map(LecturaRawModel.fromMap).toList();
  }

  /// Retorna las lecturas crudas dentro de un rango de fechas.
  Future<List<LecturaRawModel>> obtenerLecturasRawEnRango({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final db = await database;
    final maps = await db.query(
      'lecturas_raw',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [desde.toIso8601String(), hasta.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map(LecturaRawModel.fromMap).toList();
  }

  // === MÉTODOS DE RESÚMENES 5 DÍAS ===

  Future<void> insertarResumen5d(LecturaResumenModel resumen) async {
    final db = await database;
    await db.insert(
      'lecturas_resumen_5d',
      resumen.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retorna los [limit] resúmenes de 5 días más recientes.
  Future<List<LecturaResumenModel>> obtenerResumenes5d({int limit = 5}) async {
    final db = await database;
    final maps = await db.query(
      'lecturas_resumen_5d',
      orderBy: 'fecha_fin DESC',
      limit: limit,
    );
    return maps.map(LecturaResumenModel.fromMap).toList();
  }

  /// Elimina los resúmenes de 5 días cuyos IDs estén en [ids].
  Future<void> eliminarResumenes5d(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(', ');
    await db.delete(
      'lecturas_resumen_5d',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  // === MÉTODOS DE HISTORIAL MENSUAL ===

  Future<void> insertarHistorialMensual(HistorialMensualModel mensual) async {
    final db = await database;
    await db.insert(
      'historial_mensual',
      mensual.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retorna los [limit] historiales mensuales más recientes.
  Future<List<HistorialMensualModel>> obtenerHistorialesMensuales(
      {int limit = 3}) async {
    final db = await database;
    final maps = await db.query(
      'historial_mensual',
      orderBy: 'fecha_fin DESC',
      limit: limit,
    );
    return maps.map(HistorialMensualModel.fromMap).toList();
  }
}