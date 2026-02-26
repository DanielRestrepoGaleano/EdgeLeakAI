import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/alerta_fuga_model.dart';

/// Servicio de persistencia local usando Sqflite
class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    // Obtiene la ruta del sistema para guardar la base de datos
    String path = join(await getDatabasesPath(), 'edgeleak_history.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Creación de la tabla SQL al iniciar por primera vez
        await db.execute('''
          CREATE TABLE historial(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            veredicto TEXT,
            severidad TEXT,
            mensaje TEXT,
            fecha TEXT
          )
        ''');
      },
    );
  }

  /// Inserta una nueva alerta generada por Groq en la base de datos
  Future<void> insertarAlerta(AlertaFugaModel alerta) async {
    final db = await database;
    await db.insert(
      'historial', 
      alerta.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene todo el historial ordenado desde el más reciente
  Future<List<AlertaFugaModel>> obtenerHistorial() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('historial', orderBy: 'id DESC');
    
    // Convierte el listado de Maps SQL a una Lista de Objetos Dart
    return List.generate(maps.length, (i) => AlertaFugaModel.fromMap(maps[i]));
  }
}
