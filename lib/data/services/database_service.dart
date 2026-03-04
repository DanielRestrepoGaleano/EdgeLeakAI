import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/alerta_fuga_model.dart';
import '../models/usuario_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    // Cambiamos el nombre a v2 para crear las tablas desde cero sin errores
    String path = join(await getDatabasesPath(), 'edgeleak_v2.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla Historial
        await db.execute('''
          CREATE TABLE historial(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            veredicto TEXT,
            severidad TEXT,
            mensaje TEXT,
            fecha TEXT
          )
        ''');
        
        // Tabla Usuarios
        await db.execute('''
          CREATE TABLE usuarios(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            correo TEXT UNIQUE,
            password TEXT
          )
        ''');
      },
    );
  }

  // ---- MÉTODOS DE HISTORIAL ----
  Future<void> insertarAlerta(AlertaFugaModel alerta) async {
    final db = await database;
    await db.insert('historial', alerta.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AlertaFugaModel>> obtenerHistorial() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('historial', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => AlertaFugaModel.fromMap(maps[i]));
  }

  // ---- MÉTODOS DE USUARIOS ----
  Future<bool> registrarUsuario(UsuarioModel usuario) async {
    final db = await database;
    try {
      await db.insert('usuarios', usuario.toMap());
      return true;
    } catch (e) {
      return false; // Error (ej. correo duplicado)
    }
  }

  Future<UsuarioModel?> loginUsuario(String correo, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'correo = ? AND password = ?',
      whereArgs:[correo, password],
    );

    if (maps.isNotEmpty) {
      return UsuarioModel.fromMap(maps.first);
    }
    return null;
  }
}
