import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local (equivalente en Flutter a la clase Database de Room).
class AppDatabase {
  static const _nombre = 'chaac_xanab.db';

  /// v1: usuarios (id, nombre, edad, profesion)
  /// v2: + usuarios.correo (Caso 4)
  /// v3: + tabla carrito (el carrito sobrevive al cerrar la app)
  /// v4: usuarios con CHECK de tipo y rango en edad (DEF-04 de la Práctica 11)
  static const _version = 4;

  /// Esquema vigente de usuarios: SQLite tiene afinidad de tipos y aceptaba
  /// edad = 'abc'; el CHECK la obliga a ser un entero entre 0 y 120.
  static const _sqlUsuarios = '''
          CREATE TABLE usuarios (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre    TEXT    NOT NULL CHECK (length(trim(nombre)) > 0),
            edad      INTEGER NOT NULL CHECK (typeof(edad) = 'integer' AND edad BETWEEN 0 AND 120),
            profesion TEXT    NOT NULL,
            correo    TEXT    NOT NULL DEFAULT ''
          )
        ''';

  static Database? _db;

  static Future<Database> get instancia async {
    return _db ??= await openDatabase(
      join(await getDatabasesPath(), _nombre),
      version: _version,
      onCreate: (db, version) async {
        await db.execute(_sqlUsuarios);
        await _crearCarrito(db);
      },
      onUpgrade: migrar,
    );
  }

  /// Migraciones: quien tenía una versión anterior conserva sus datos.
  /// sqflite ya ejecuta onUpgrade dentro de una transacción: si algo falla, no queda nada a medias.
  static Future<void> migrar(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE usuarios ADD COLUMN correo TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 3) {
      await _crearCarrito(db);
    }
    if (oldVersion < 4) {
      // SQLite no permite agregar un CHECK a una tabla existente: se recrea y se
      // copian sólo las filas válidas (las que el modelo Usuario sí puede leer).
      await db.execute('ALTER TABLE usuarios RENAME TO usuarios_v3');
      await db.execute(_sqlUsuarios);
      await db.execute('''
        INSERT INTO usuarios (id, nombre, edad, profesion, correo)
        SELECT id, nombre, edad, profesion, correo FROM usuarios_v3
         WHERE typeof(edad) = 'integer' AND edad BETWEEN 0 AND 120 AND length(trim(nombre)) > 0
      ''');
      await db.execute('DROP TABLE usuarios_v3');
    }
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
