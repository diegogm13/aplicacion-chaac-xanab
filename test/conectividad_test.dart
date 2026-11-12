// Práctica 11 — NET-05 / NET-06: pérdida de conectividad y recuperación.
//
// Se monta la pantalla real CheckoutScreen y se sustituye SOLO el transporte
// HTTP (ApiClient.cliente) por uno que simula la caída de red. En el camino
// de fallo el carrito no se vacía, así que no se toca SQLite.
import 'dart:io';

import 'package:chaac_xanab_app/models/producto.dart';
import 'package:chaac_xanab_app/models/tienda.dart';
import 'package:chaac_xanab_app/screens/checkout_screen.dart';
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/carrito_service.dart';
import 'package:chaac_xanab_app/services/tienda_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:chaac_xanab_app/screens/home_shell.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _direccion = {
  'calle': 'Calle 60', 'numero_ext': '123', 'colonia': 'Centro',
  'ciudad': 'Mérida', 'estado': 'Yucatán', 'codigo_postal': '97000',
};

http.Response _json(String s, int status) =>
    http.Response.bytes(s.codeUnits, status, headers: {'content-type': 'application/json'});

void main() {
  final carrito = CarritoService.instancia;
  final api = ApiClient.instancia;

  testWidgets('NET-05: sin red al confirmar -> error visible, NO muestra éxito, carrito intacto',
      (tester) async {
    var postsCompra = 0;
    api.cliente = MockClient((req) async {
      if (req.method == 'GET') return _json('{"calle":"Calle 60","numero_ext":"123","colonia":"Centro","ciudad":"Merida","estado":"Yucatan","codigo_postal":"97000"}', 200);
      postsCompra++;
      throw const SocketException('Network is unreachable'); // modo avión
    });
    carrito.items = [
      ItemCarrito.fromMap({
        'id': 1, 'producto_id': 'p1', 'nombre': 'Tenis Chaac', 'precio': 1500.0,
        'imagen_url': 'https://example.invalid/x.jpg', 'talla': '26', 'cantidad': 2, 'stock': 5,
      }),
    ];

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();

    // La dirección se precargó desde GET /auth/me/direccion.
    expect(find.widgetWithText(TextFormField, 'Calle 60'), findsOneWidget);

    await tester.tap(find.textContaining('CONFIRMAR COMPRA'));
    await tester.pumpAndSettle();

    expect(postsCompra, 1);
    expect(find.textContaining('No fue posible conectar'), findsOneWidget, reason: 'detecta el error');
    expect(find.text('¡Compra realizada!'), findsNothing, reason: 'no reporta éxito falso');
    expect(carrito.items.length, 1, reason: 'el carrito se conserva para reintentar');
    expect(carrito.items.single.cantidad, 2);
    // El botón vuelve a estar habilitado (reintento manual controlado).
    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('NET-06: recupera la red -> compra 201, diálogo de éxito y carrito vaciado en SQLite',
      (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await tester.runAsync(() async {
      await CarritoService.instancia.vaciar();
      await CarritoService.instancia.agregar(
          Producto(id: 'p1', nombre: 'Tenis Chaac', descripcion: '', precio: 1500, imagenUrl: 'https://example.invalid/x.jpg', stock: 5, tallas: const ['26']),
          '26', 2);
    });
    final cuerpos = <String>[];
    api.cliente = MockClient((req) async {
      if (req.method == 'GET') return _json('{"calle":"Calle 60","numero_ext":"123","colonia":"Centro","ciudad":"Merida","estado":"Yucatan","codigo_postal":"97000"}', 200);
      cuerpos.add(req.body);
      return _json('{"id":"c-1","total":3000,"status":"pendiente","created_at":"2026-11-11T00:00:00Z","items":[]}', 201);
    });

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CONFIRMAR COMPRA'));
    // El DELETE en SQLite es E/S real: se alterna reloj falso (pump) y tiempo real.
    for (var i = 0; i < 40 && find.text('¡Compra realizada!').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(cuerpos.single, contains('"quantity":2'));
    expect(find.text('¡Compra realizada!'), findsOneWidget);
    expect(CarritoService.instancia.vacio, isTrue);
    await tester.tap(find.text('VER MIS PEDIDOS'));
    await tester.pumpAndSettle();
    expect(HomeShell.tab.value, HomeShell.pedidos);
  });

  testWidgets('Token vencido en checkout: 401 -> cierra sesión y avisa', (tester) async {
    SharedPreferences.setMockInitialValues({'jwt': 'vencido'});
    api.token = 'vencido';
    api.cliente = MockClient((req) async => req.method == 'GET'
        ? _json('null', 200)
        : _json('{"message":"Unauthorized","statusCode":401}', 401));
    carrito.items = [
      ItemCarrito.fromMap({
        'id': 1, 'producto_id': 'p1', 'nombre': 'Tenis', 'precio': 10.0,
        'imagen_url': 'https://example.invalid/x.jpg', 'talla': '26', 'cantidad': 1, 'stock': 5,
      }),
    ];
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();
    for (final (campo, valor) in [('Calle', 'A'), ('Núm. exterior', '1'), ('Colonia', 'B'), ('Ciudad', 'C'), ('Estado', 'D'), ('Código postal', '97000')]) {
      await tester.enterText(find.widgetWithText(TextFormField, campo), valor);
    }
    await tester.tap(find.textContaining('CONFIRMAR COMPRA'));
    await tester.pumpAndSettle();
    expect(find.text('Unauthorized'), findsOneWidget);
    expect(api.token, isNull, reason: 'sesionExpirada() limpió el token');
    expect(carrito.items, isNotEmpty);
  });

  testWidgets('Validación del formulario: CP inválido bloquea la petición', (tester) async {
    var posts = 0;
    api.cliente = MockClient((req) async {
      if (req.method == 'GET') return _json('null', 200);
      posts++;
      return _json('{}', 201);
    });
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CONFIRMAR COMPRA'));
    await tester.pumpAndSettle();
    expect(find.text('Obligatorio'), findsNWidgets(5));
    expect(find.text('5 dígitos'), findsOneWidget);
    expect(posts, 0, reason: 'no se envía nada al servidor con datos inválidos');
  });

  test('DEFECTO DEF-01: respuesta perdida + reintento = compra DUPLICADA en el servidor', () async {
    // El servidor SÍ procesa la compra, pero la conexión se corta antes de que
    // llegue la respuesta (el cliente sólo ve un error de red).
    final registradas = <String>[];
    var cortarRespuesta = true;
    api.cliente = MockClient((req) async {
      registradas.add(req.body); // el backend ya insertó en `compras`
      if (cortarRespuesta) {
        cortarRespuesta = false;
        throw const SocketException('Connection reset by peer');
      }
      return _json('{"id":"c-${registradas.length}","total":3000,"status":"pendiente","created_at":"2026-11-11T00:00:00Z","items":[]}', 201);
    });

    final servicio = TiendaService();
    final items = [{'producto_id': 'p1', 'size': '26', 'quantity': 2}];
    final dir = Direccion.fromJson(_direccion);

    await expectLater(servicio.comprar(items: items, direccion: dir), throwsA(isA<ApiException>()));
    // El usuario ve "Revisa tu conexión" y vuelve a pulsar CONFIRMAR:
    final compra = await servicio.comprar(items: items, direccion: dir);

    expect(compra.id, 'c-2');
    expect(registradas.length, 2, reason: 'no hay Idempotency-Key: el backend no puede detectar el reintento');
    expect(registradas[0], registradas[1], reason: 'mismo cuerpo, misma intención -> 2 registros');
  });

  test('Producto.agotado y enOferta (lógica usada para bloquear la compra)', () {
    Producto mk({int stock = 1, double? orig}) => Producto(
        id: 'x', nombre: 'n', descripcion: '', precio: 100, imagenUrl: '', stock: stock, tallas: const [], precioOriginal: orig);
    expect(mk(stock: 0).agotado, isTrue);
    expect(mk(stock: 1).agotado, isFalse);
    expect(mk(orig: 150).enOferta, isTrue);
    expect(mk(orig: 100).enOferta, isFalse);
    expect(mk().enOferta, isFalse);
  });
}
