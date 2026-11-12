import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local (equivalente en Flutter a la clase Database de Room).
class AppDatabase {
  static const _nombre = 'chaac_xanab.db';

  /// v1: usuarios (id, nombre, edad, profesion)
  /// v2: + usuarios.correo (Caso 4)
  /// v3: + tabla carrito (el carrito sobrevive al cerrar la app)
  static const _version = 3;

  static Database? _db;

  static Future<Database> get instancia async {
    return _db ??= await openDatabase(
      join(await getDatabasesPath(), _nombre),
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE usuarios (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre    TEXT    NOT NULL,
            edad      INTEGER NOT NULL,
            profesion TEXT    NOT NULL,
            correo    TEXT    NOT NULL DEFAULT ''
          )
        ''');
        await _crearCarrito(db);
      },
      // Migraciones: quien tenía una versión anterior conserva sus datos.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE usuarios ADD COLUMN correo TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 3) {
          await _crearCarrito(db);
        }
      },
    );
  }

  static Future<void> _crearCarrito(Database db) => db.execute('''
        CREATE TABLE carrito (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          producto_id TEXT    NOT NULL,
          nombre      TEXT    NOT NULL,
          precio      REAL    NOT NULL,
          imagen_url  TEXT    NOT NULL,
          talla       TEXT    NOT NULL,
          cantidad    INTEGER NOT NULL,
          stock       INTEGER NOT NULL,
          UNIQUE (producto_id, talla)
        )
      ''');
}
