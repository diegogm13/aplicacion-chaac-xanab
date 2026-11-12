import '../models/usuario.dart';
import 'app_database.dart';

/// DAO de usuarios: concentra las operaciones CRUD sobre la tabla.
class UsuarioDao {
  /// INSERT
  Future<int> insertar(Usuario u) async {
    final db = await AppDatabase.instancia;
    return db.insert('usuarios', u.toMap());
  }

  /// SELECT — lo ejecuta el botón "VER usuarios".
  Future<List<Usuario>> obtenerTodos() async {
    final db = await AppDatabase.instancia;
    final filas = await db.query('usuarios', orderBy: 'id');
    return filas.map(Usuario.fromMap).toList();
  }

  /// UPDATE
  Future<int> actualizar(Usuario u) async {
    final db = await AppDatabase.instancia;
    return db.update('usuarios', u.toMap(), where: 'id = ?', whereArgs: [u.id]);
  }

  /// DELETE
  Future<int> eliminar(int id) async {
    final db = await AppDatabase.instancia;
    return db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }
}
