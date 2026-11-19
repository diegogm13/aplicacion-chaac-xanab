// Prácticas 13 y 14 — Fase 2: pruebas UNITARIAS de la lógica de negocio.
//
// AUT-01  Validaciones de registro y checkout (entrada válida, vacía/nula, fuera de rango).
// AUT-02  Cálculo del carrito (CarritoService) y manejo de excepción con stock 0 (DEF-02).
// AUT-03  Comunicación: llave de idempotencia, traducción de errores y política de reintentos.
//
// Se ejecutan en CI en cada push y pull request (.github/workflows/ci.yml).
import 'dart:io';

import 'package:chaac_xanab_app/config/validaciones.dart';
import 'package:chaac_xanab_app/db/app_database.dart';
import 'package:chaac_xanab_app/models/producto.dart';
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/carrito_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Producto tenis({int stock = 5, double precio = 1500}) => Producto(
    id: 'p13-tenis', nombre: 'Tenis P13', descripcion: '', precio: precio, imagenUrl: '', stock: stock, tallas: const ['26']);

void main() {
  // ── AUT-01 ───────────────────────────────────────────────────────────────
  group('AUT-01 Validaciones', () {
    test('entrada válida → sin error', () {
      expect(Validaciones.email('ana@chaac.mx'), isNull);
      expect(Validaciones.password('Chaac#2026'), isNull);
      expect(Validaciones.codigoPostal('97000'), isNull);
      expect(Validaciones.edad('30'), isNull);
    });

    test('entrada vacía o nula → mensaje de error', () {
      expect(Validaciones.requerido(null), 'Obligatorio');
      expect(Validaciones.requerido('   '), 'Obligatorio');
      expect(Validaciones.email(null), isNotNull);
      expect(Validaciones.codigoPostal(''), '5 dígitos');
      expect(Validaciones.password(''), isNotNull);
    });

    test('valores fuera de rango → rechazados (límites incluidos)', () {
      expect(Validaciones.edadValida('-1'), isFalse);
      expect(Validaciones.edadValida('0'), isTrue);
      expect(Validaciones.edadValida('120'), isTrue);
      expect(Validaciones.edadValida('121'), isFalse);
      expect(Validaciones.codigoPostalValido('9700'), isFalse);
      expect(Validaciones.codigoPostalValido('970001'), isFalse);
      expect(Validaciones.passwordFuerte('Ab#4567'), isFalse, reason: '7 caracteres');
      expect(Validaciones.passwordFuerte('Ab#45678'), isTrue, reason: '8 caracteres');
    });
  });

  // ── AUT-02 ───────────────────────────────────────────────────────────────
  group('AUT-02 Carrito: cálculo y excepciones', () {
    final carrito = CarritoService.instancia;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.deleteDatabase(p.join(await getDatabasesPath(), 'chaac_xanab.db'));
      await AppDatabase.instancia;
    });
    setUp(() => carrito.vaciar());

    test('resultado esperado: total y piezas', () async {
      await carrito.agregar(tenis(), '26', 2);
      await carrito.agregar(tenis(precio: 999.5, stock: 3).copiaCon(id: 'p13-otro'), '27', 1);
      expect(carrito.piezas, 3);
      expect(carrito.total, 1500 * 2 + 999.5);
      expect(carrito.paraCompra().first, {'producto_id': 'p13-tenis', 'size': '26', 'quantity': 2});
    });

    test('valores fuera de rango: cantidad 0 → 1; cantidad > stock → stock', () async {
      await carrito.agregar(tenis(stock: 3), '26', 0);
      expect(carrito.items.single.cantidad, 1);
      await carrito.agregar(tenis(stock: 3), '26', 50);
      expect(carrito.items.single.cantidad, 3);
    });

    test('excepción controlada: producto agotado (stock 0) → CarritoException, el carrito no cambia (DEF-02)', () async {
      await expectLater(
        carrito.agregar(tenis(stock: 0), '26', 1),
        throwsA(isA<CarritoException>().having((e) => e.mensaje, 'mensaje', contains('agotado'))),
      );
      expect(carrito.vacio, isTrue);
    });
  });

  // ── AUT-03 ───────────────────────────────────────────────────────────────
  group('AUT-03 Comunicación (ApiClient)', () {
    test('llave de idempotencia: 32 hex, distinta en cada compra', () {
      final llaves = List.generate(200, (_) => nuevaLlaveIdempotencia()).toSet();
      expect(llaves, hasLength(200));
      expect(llaves.every((k) => RegExp(r'^[0-9a-f]{32}$').hasMatch(k)), isTrue);
    });

    test('respuesta 409 → ApiException con el mensaje del servidor', () async {
      final api = ApiClient.conCliente(MockClient((_) async =>
          http.Response('{"message":"Stock insuficiente","statusCode":409}', 409, headers: {'content-type': 'application/json'})));
      await expectLater(api.post('/compras', {}),
          throwsA(isA<ApiException>().having((e) => (e.status, e.mensaje), 'status/mensaje', (409, 'Stock insuficiente'))));
    });

    test('reintento: GET se repite ante 503 y POST sin llave NO se repite', () async {
      var getIntentos = 0;
      final api = ApiClient.conCliente(MockClient((req) async {
        if (req.method == 'GET') {
          getIntentos++;
          return http.Response(getIntentos < 3 ? '' : '[]', getIntentos < 3 ? 503 : 200);
        }
        throw const SocketException('reset');
      }));
      expect(await api.get('/productos'), isEmpty);
      expect(getIntentos, 3, reason: '1 intento + 2 reintentos');
      await expectLater(api.post('/compras', {}), throwsA(isA<ApiException>()));
      expect(api.reintentosRealizados, 2, reason: 'el POST sin llave no sumó reintentos');
    });
  });
}

extension on Producto {
  Producto copiaCon({required String id}) => Producto(
      id: id, nombre: nombre, descripcion: descripcion, precio: precio, imagenUrl: imagenUrl, stock: stock, tallas: tallas);
}
