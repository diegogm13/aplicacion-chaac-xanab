import '../config/validaciones.dart';
import '../models/usuario.dart';
import 'app_database.dart';

/// DAO de usuarios: concentra las operaciones CRUD sobre la tabla.
class UsuarioDao {
  /// Valida antes de tocar la base (además del CHECK de la tabla, v4).
  void _validar(Usuario u) {
    if (u.nombre.trim().isEmpty) throw ArgumentError.value(u.nombre, 'nombre', 'no puede estar vacío');
    if (!Validaciones.edadValida('${u.edad}')) throw ArgumentError.value(u.edad, 'edad', 'debe estar entre 0 y 120');
  }

  /// INSERT
  Future<int> insertar(Usuario u) async {
    _validar(u);
    final db = await AppDatabase.instancia;
    return db.insert('usuarios', u.toMap());
  }

  /// SELECT — lo ejecuta el botón "VER usuarios".
  Future<List<Usuario>> obtenerTodos() async {
    final db = await AppDatabase.instancia;
    final filas = await db.query('usuarios', orderBy: 'id');
    return filas.map(Usuario.fromMap).toList();
  }

  /// UPDATE — OBS-03 (P11): antes un usuario sin id mandaba `whereArgs: [null]`.
  Future<int> actualizar(Usuario u) async {
    if (u.id == null) throw ArgumentError.notNull('id');
    _validar(u);
    final db = await AppDatabase.instancia;
    return db.update('usuarios', u.toMap(), where: 'id = ?', whereArgs: [u.id]);
  }

  /// DELETE
  Future<int> eliminar(int id) async {
    final db = await AppDatabase.instancia;
    return db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }
}
