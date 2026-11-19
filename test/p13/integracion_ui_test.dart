// Prácticas 13 y 14 — Fase 3: integración pantalla ↔ servicio ↔ carrito.
//
// AUT-05 (UI)  La aplicación muestra un mensaje adecuado cuando el servidor no responde
//              y no confirma falsamente la compra.
import 'dart:async';
import 'dart:convert';

import 'package:chaac_xanab_app/screens/checkout_screen.dart';
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/carrito_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('servidor sin respuesta (timeout) → mensaje claro, sin éxito falso, carrito intacto', (tester) async {
    final api = ApiClient.instancia;
    var posts = 0;
    api.cliente = MockClient((req) async {
      if (req.method == 'GET') {
        return http.Response.bytes(
            utf8.encode('{"calle":"Calle 60","numero_ext":"1","colonia":"Centro","ciudad":"Mérida","estado":"Yucatán","codigo_postal":"97000"}'),
            200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      posts++;
      throw TimeoutException('el servidor no respondió'); // igual que .timeout(ApiConfig.timeout)
    });
    CarritoService.instancia.items = [
      ItemCarrito.fromMap({
        'id': 1, 'producto_id': 'p1', 'nombre': 'Tenis Chaac', 'precio': 1500.0,
        'imagen_url': 'https://example.invalid/x.jpg', 'talla': '26', 'cantidad': 1, 'stock': 5,
      }),
    ];

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CONFIRMAR COMPRA'));
    await tester.pumpAndSettle();

    expect(posts, 1, reason: 'un timeout no se reintenta solo: el servidor pudo haberla procesado');
    expect(find.textContaining('El servidor tardó demasiado en responder'), findsOneWidget);
    expect(find.text('¡Compra realizada!'), findsNothing);
    expect(CarritoService.instancia.items, hasLength(1));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull,
        reason: 'el usuario puede reintentar (con la misma llave)');
  });
}
