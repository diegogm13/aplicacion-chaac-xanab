// Prácticas 13 y 14 — AUT-06: operación de PERSISTENCIA (SQLite real vía sqflite_common_ffi).
//
// La operación de registro almacena correctamente la información y los datos
// sobreviven a cerrar la app (se leen desde una conexión nueva e independiente).
import 'package:chaac_xanab_app/db/app_database.dart';
import 'package:chaac_xanab_app/db/usuario_dao.dart';
import 'package:chaac_xanab_app/models/producto.dart';
import 'package:chaac_xanab_app/models/usuario.dart';
import 'package:chaac_xanab_app/services/carrito_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(p.join(await getDatabasesPath(), 'chaac_xanab.db'));
    db = await AppDatabase.instancia;
  });

  Future<Database> otraConexion() =>
      databaseFactory.openDatabase(db.path, options: OpenDatabaseOptions(singleInstance: false));

  test('AUT-06a registro de usuario: INSERT → se lee igual desde otra conexión', () async {
    final id = await UsuarioDao().insertar(const Usuario(nombre: 'Ana', edad: 21, profesion: 'ISC', correo: 'ana@chaac.mx'));
    final otra = await otraConexion();
    final fila = (await otra.query('usuarios', where: 'id = ?', whereArgs: [id])).single;
    await otra.close();
    expect(Usuario.fromMap(fila).correo, 'ana@chaac.mx');
  });

  test('AUT-06b carrito: agregar → la fila persiste (sobrevive a reabrir la app)', () async {
    final carrito = CarritoService.instancia;
    await carrito.vaciar();
    await carrito.agregar(
        Producto(id: 'p1', nombre: 'Tenis', descripcion: '', precio: 1500, imagenUrl: '', stock: 5, tallas: const ['26']), '26', 2);
    final otra = await otraConexion();
    final filas = await otra.query('carrito');
    await otra.close();
    expect(filas.single['cantidad'], 2);
    expect(filas.single['producto_id'], 'p1');
  });

  test('AUT-06c integridad: datos incompletos se rechazan y no dejan filas a medias', () async {
    final antes = (await db.query('usuarios')).length;
    await expectLater(db.insert('usuarios', {'nombre': null, 'edad': 1, 'profesion': 'x'}), throwsA(isA<DatabaseException>()));
    expect((await db.query('usuarios')).length, antes);
  });
}
