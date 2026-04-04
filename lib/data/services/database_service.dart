import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/alerta_fuga_model.dart';
import '../models/usuario_model.dart'; // Importación única corregida

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'edgeleak_v3.db');
    
    return await openDatabase(
      path,
      version: 3,
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
            primer_nombre TEXT NOT NULL DEFAULT '',
            segundo_nombre TEXT DEFAULT '',
            primer_apellido TEXT NOT NULL DEFAULT '',
            segundo_apellido TEXT DEFAULT '',
            correo TEXT UNIQUE,
            password TEXT,
            es_temporal INTEGER DEFAULT 0,
            rol TEXT DEFAULT 'operador'
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
          // Migración: añadir los campos de nombre separados
          await db.execute("ALTER TABLE usuarios ADD COLUMN primer_nombre TEXT DEFAULT ''");
          await db.execute("ALTER TABLE usuarios ADD COLUMN segundo_nombre TEXT DEFAULT ''");
          await db.execute("ALTER TABLE usuarios ADD COLUMN primer_apellido TEXT DEFAULT ''");
          await db.execute("ALTER TABLE usuarios ADD COLUMN segundo_apellido TEXT DEFAULT ''");
          // Migrar nombre legado al primer_nombre para no perder datos existentes
          await db.execute(
            "UPDATE usuarios SET primer_nombre = nombre WHERE nombre IS NOT NULL AND nombre != ''",
          );
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
    await db.insert('historial', alerta.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AlertaFugaModel>> obtenerHistorial() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('historial', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => AlertaFugaModel.fromMap(maps[i]));
  }
}