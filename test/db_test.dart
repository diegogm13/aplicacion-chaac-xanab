// Práctica 11 — White Box de la BASE DE DATOS local (SQLite) y del método de
// PROCESAMIENTO/CÁLCULO CarritoService.agregar().
//
// Se ejecuta con sqflite_common_ffi: es el MISMO motor SQLite y el MISMO código
// de AppDatabase / UsuarioDao / CarritoService que corre en el teléfono.
// Las métricas (tiempos y planes EXPLAIN) se guardan en
// practica11/resultados/db_metricas.json.
import 'dart:convert';
import 'dart:io';

import 'package:chaac_xanab_app/db/app_database.dart';
import 'package:chaac_xanab_app/db/usuario_dao.dart';
import 'package:chaac_xanab_app/models/producto.dart';
import 'package:chaac_xanab_app/models/usuario.dart';
import 'package:chaac_xanab_app/services/carrito_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Producto prod({String id = 'p1', double precio = 1500, int stock = 3}) => Producto(
      id: id,
      nombre: 'Tenis $id',
      descripcion: '',
      precio: precio,
      imagenUrl: 'https://example.com/$id.jpg',
      stock: stock,
      tallas: const ['26', '27'],
    );

final metricas = <String, Object?>{};

Future<double> medirMs(Future<void> Function() f, {int repeticiones = 50}) async {
  final sw = Stopwatch()..start();
  for (var i = 0; i < repeticiones; i++) {
    await f();
  }
  sw.stop();
  return sw.elapsedMicroseconds / repeticiones / 1000;
}

void main() {
  late Database db;
  final dao = UsuarioDao();
  final carrito = CarritoService.instancia;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(p.join(await getDatabasesPath(), 'chaac_xanab.db'));
    db = await AppDatabase.instancia;
  });

  setUp(() async {
    await db.delete('usuarios');
    await carrito.vaciar();
  });

  tearDownAll(() async {
    // Evidencia de la Práctica 11: sólo se reescribe con GUARDAR_METRICAS=1.
    if (Platform.environment['GUARDAR_METRICAS'] != '1') return;
    final dir = Directory('practica11/resultados')..createSync(recursive: true);
    File(p.join(dir.path, 'db_metricas.json'))
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metricas));
  });

  // ───────────────────────── CarritoService.agregar() ─────────────────────────
  // D1: existente.isEmpty   D2 (clamp): cantidad < 1   D3 (clamp): cantidad > stock
  group('CarritoService.agregar() — caminos y valores límite', () {
    test('P1 D1=V  producto nuevo -> INSERT con cantidad pedida', () async {
      await carrito.agregar(prod(), '26', 2);
      expect(carrito.items.single.cantidad, 2);
      expect(carrito.total, 3000);
      expect(carrito.piezas, 2);
    });

    test('P1 + límite inferior: cantidad 0 -> se ajusta a 1', () async {
      await carrito.agregar(prod(), '26', 0);
      expect(carrito.items.single.cantidad, 1);
    });

    test('P1 + límite superior: cantidad = stock (3) -> 3', () async {
      await carrito.agregar(prod(stock: 3), '26', 3);
      expect(carrito.items.single.cantidad, 3);
    });

    test('P1 + límite superior + 1: cantidad 4 con stock 3 -> 3', () async {
      await carrito.agregar(prod(stock: 3), '26', 4);
      expect(carrito.items.single.cantidad, 3);
    });

    test('P2 D1=F  mismo producto y talla -> UPDATE acumulando', () async {
      await carrito.agregar(prod(stock: 10), '26', 2);
      await carrito.agregar(prod(stock: 10), '26', 3);
      expect(carrito.items.single.cantidad, 5);
    });

    test('P2 + límite: acumulado supera stock -> se recorta al stock', () async {
      await carrito.agregar(prod(stock: 3), '26', 2);
      await carrito.agregar(prod(stock: 3), '26', 2);
      expect(carrito.items.single.cantidad, 3);
    });

    test('misma talla distinta / otro producto -> filas separadas y total correcto', () async {
      await carrito.agregar(prod(), '26', 1);
      await carrito.agregar(prod(), '27', 1);
      await carrito.agregar(prod(id: 'p2', precio: 999.5, stock: 5), '26', 2);
      expect(carrito.items.length, 3);
      expect(carrito.piezas, 4);
      expect(carrito.total, 1500 + 1500 + 999.5 * 2);
      expect(carrito.paraCompra().last, {'producto_id': 'p2', 'size': '26', 'quantity': 2});
    });

    test('CORREGIDO P13 (DEF-02): stock 0 -> CarritoException controlada, sin ArgumentError', () async {
      // Antes: clamp(1, 0) lanzaba ArgumentError no controlado. Ahora el servicio se protege.
      await expectLater(carrito.agregar(prod(stock: 0), '26', 1), throwsA(isA<CarritoException>()));
      expect(carrito.vacio, isTrue);
    });
  });

  group('CarritoService.cambiarCantidad() / quitar()', () {
    test('cantidad < 1 -> elimina el renglón', () async {
      await carrito.agregar(prod(), '26', 2);
      await carrito.cambiarCantidad(carrito.items.single, 0);
      expect(carrito.vacio, isTrue);
    });

    test('cantidad > stock -> se recorta', () async {
      await carrito.agregar(prod(stock: 3), '26', 1);
      await carrito.cambiarCantidad(carrito.items.single, 9);
      expect(carrito.items.single.cantidad, 3);
    });

    test('cantidad válida -> UPDATE', () async {
      await carrito.agregar(prod(stock: 3), '26', 1);
      await carrito.cambiarCantidad(carrito.items.single, 2);
      expect(carrito.items.single.cantidad, 2);
    });
  });

  // ───────────────────────────── DB-01 … DB-06 ───────────────────────────────
  group('UsuarioDao — CRUD (DB-01 … DB-05)', () {
    test('DB-01 inserción válida y consulta por id existente', () async {
      final id = await dao.insertar(const Usuario(nombre: 'Ana', edad: 21, profesion: 'ISC', correo: 'ana@chaac.mx'));
      expect(id, greaterThan(0));
      final fila = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
      expect(Usuario.fromMap(fila.single).correo, 'ana@chaac.mx');
    });

    test('DB-02 inserción incompleta: NOT NULL rechaza nombre nulo', () async {
      await expectLater(
        db.insert('usuarios', {'nombre': null, 'edad': 20, 'profesion': 'x'}),
        throwsA(isA<DatabaseException>().having((e) => e.isNotNullConstraintError(), 'NOT NULL', isTrue)),
      );
      expect(await db.query('usuarios'), isEmpty, reason: 'no quedó registro parcial');
    });

    test('DB-02 UNIQUE(producto_id, talla) en carrito rechaza duplicado', () async {
      final fila = {
        'producto_id': 'p1', 'nombre': 'x', 'precio': 1.0, 'imagen_url': '',
        'talla': '26', 'cantidad': 1, 'stock': 1,
      };
      await db.insert('carrito', fila);
      await expectLater(
        db.insert('carrito', fila),
        throwsA(isA<DatabaseException>().having((e) => e.isUniqueConstraintError(), 'UNIQUE', isTrue)),
      );
    });

    test('DEFECTO DEF-04: la tabla acepta edad no numérica / fuera de rango (sin CHECK)', () async {
      final id = await db.insert('usuarios', {'nombre': 'X', 'edad': 'abc', 'profesion': 'Y'});
      await db.insert('usuarios', {'nombre': 'Z', 'edad': -5, 'profesion': 'Y'});
      final fila = (await db.query('usuarios', where: 'id = ?', whereArgs: [id])).single;
      // SQLite guarda el texto por afinidad de tipo; al leerlo, el modelo truena.
      expect(fila['edad'], 'abc');
      expect(() => Usuario.fromMap(fila), throwsA(isA<TypeError>()));
    });

    test('DB-03 consulta por id inexistente -> lista vacía (no excepción)', () async {
      expect(await db.query('usuarios', where: 'id = ?', whereArgs: [999999]), isEmpty);
    });

    test('DB-04 actualización: 1 fila afectada y persistida; id inexistente -> 0', () async {
      final id = await dao.insertar(const Usuario(nombre: 'Ana', edad: 21, profesion: 'ISC'));
      final u = (await dao.obtenerTodos()).single;
      expect(await dao.actualizar(u.copyWith(edad: 22, correo: 'nuevo@chaac.mx')), 1);
      expect(await dao.actualizar(const Usuario(nombre: 'N', edad: 1, profesion: 'N').copyWith()), 0);

      // Persistencia: se lee desde una SEGUNDA conexión independiente.
      final otra = await databaseFactory.openDatabase(db.path, options: OpenDatabaseOptions(singleInstance: false));
      final leida = Usuario.fromMap((await otra.query('usuarios', where: 'id = ?', whereArgs: [id])).single);
      await otra.close();
      expect((leida.edad, leida.correo), (22, 'nuevo@chaac.mx'));
    });

    test('DB-05 eliminación: 1 fila, luego consulta vacía; repetir -> 0', () async {
      final id = await dao.insertar(const Usuario(nombre: 'Ana', edad: 21, profesion: 'ISC'));
      expect(await dao.eliminar(id), 1);
      expect(await db.query('usuarios', where: 'id = ?', whereArgs: [id]), isEmpty);
      expect(await dao.eliminar(id), 0);
    });

    test('Transacción: si falla un paso, no queda nada a medias', () async {
      await expectLater(
        db.transaction((txn) async {
          await txn.insert('usuarios', {'nombre': 'A', 'edad': 1, 'profesion': 'p'});
          await txn.insert('usuarios', {'nombre': null, 'edad': 1, 'profesion': 'p'});
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('usuarios'), isEmpty);
    });

    test('Inyección SQL: el valor viaja como parámetro (?), no se concatena', () async {
      await dao.insertar(const Usuario(nombre: 'Ana', edad: 21, profesion: 'ISC'));
      const ataque = "1 OR 1=1; DROP TABLE usuarios; --";
      expect(await dao.eliminar(int.tryParse(ataque) ?? -1), 0);
      expect(await db.query('usuarios', where: 'nombre = ?', whereArgs: [ataque]), isEmpty);
      expect((await dao.obtenerTodos()).length, 1, reason: 'la tabla sigue intacta');
    });
  });

  group('DB-06 concurrencia sobre el mismo registro', () {
    test('DEFECTO DEF-03: dos agregar() simultáneos del mismo producto/talla', () async {
      Object? error;
      try {
        await Future.wait([
          carrito.agregar(prod(stock: 10), '26', 1),
          carrito.agregar(prod(stock: 10), '26', 1),
        ]);
      } catch (e) {
        error = e;
      }
      await carrito.cargar();
      metricas['concurrencia_agregar'] = {
        'excepcion': error?.runtimeType.toString(),
        'detalle': error?.toString().split('\n').first,
        'filas_resultantes': carrito.items.length,
        'cantidad_final': carrito.items.isEmpty ? null : carrito.items.single.cantidad,
        'cantidad_esperada': 2,
      };
      // Integridad física: UNIQUE impide la fila duplicada…
      expect(carrito.items.length, 1);
      // …pero el usuario pidió 2 piezas y una de las operaciones se pierde/falla.
      expect(error is DatabaseException || carrito.items.single.cantidad != 2, isTrue,
          reason: 'check-then-act sin transacción: la segunda operación no ve la primera');
    });

    test('dos UPDATE simultáneos del mismo renglón -> gana la última escritura', () async {
      await carrito.agregar(prod(stock: 10), '26', 1);
      final it = carrito.items.single;
      await Future.wait([carrito.cambiarCantidad(it, 4), carrito.cambiarCantidad(it, 7)]);
      expect(carrito.items.single.cantidad, anyOf(4, 7));
      metricas['concurrencia_update'] = {'cantidad_final': carrito.items.single.cantidad};
    });
  });

  group('Medición de consultas + EXPLAIN QUERY PLAN', () {
    test('3 consultas con 1,000 usuarios y 200 renglones de carrito', () async {
      await db.transaction((txn) async {
        final b = txn.batch();
        for (var i = 0; i < 1000; i++) {
          b.insert('usuarios', {'nombre': 'U$i', 'edad': i % 100, 'profesion': 'P', 'correo': 'u$i@chaac.mx'});
        }
        for (var i = 0; i < 200; i++) {
          b.insert('carrito', {
            'producto_id': 'prod$i', 'nombre': 'N', 'precio': 10.0, 'imagen_url': '',
            'talla': '26', 'cantidad': 1, 'stock': 5,
          });
        }
        await b.commit(noResult: true);
      });
      final idMedio = (await db.rawQuery('SELECT id FROM usuarios LIMIT 1 OFFSET 500')).single['id'];

      final consultas = <String, (String, List<Object?>)>{
        'usuario_por_id (PK)': ('SELECT * FROM usuarios WHERE id = ?', [idMedio]),
        'usuario_por_correo (sin índice)': ('SELECT * FROM usuarios WHERE correo = ?', ['u900@chaac.mx']),
        'carrito_por_producto_talla (UNIQUE)': ('SELECT * FROM carrito WHERE producto_id = ? AND talla = ? LIMIT 1', ['prod150', '26']),
        'usuarios_todos (obtenerTodos)': ('SELECT * FROM usuarios ORDER BY id', []),
      };

      final res = <String, Object?>{};
      for (final MapEntry(key: nombre, value: (sql, args)) in consultas.entries) {
        final plan = await db.rawQuery('EXPLAIN QUERY PLAN $sql', args);
        final ms = await medirMs(() => db.rawQuery(sql, args));
        res[nombre] = {
          'sql': sql,
          'plan': plan.map((r) => r['detail']).toList(),
          'promedio_ms_50_ejecuciones': double.parse(ms.toStringAsFixed(3)),
        };
      }
      metricas['consultas'] = res;
      metricas['motor'] = (await db.rawQuery('SELECT sqlite_version() AS v')).single['v'];

      final planCorreo = (res['usuario_por_correo (sin índice)'] as Map)['plan'].toString();
      final planCarrito = (res['carrito_por_producto_talla (UNIQUE)'] as Map)['plan'].toString();
      expect(planCorreo, contains('SCAN'), reason: 'búsqueda por correo recorre toda la tabla');
      expect(planCarrito, contains('sqlite_autoindex_carrito_1'));
    });
  });
}
