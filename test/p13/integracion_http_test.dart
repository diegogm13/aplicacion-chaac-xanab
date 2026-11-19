// Prácticas 13 y 14 — Fase 3: pruebas de INTEGRACIÓN app ↔ servicio HTTP.
//
// Se levanta un servidor HTTP real (dart:io) en 127.0.0.1 que reproduce el
// contrato de la API de CHAAC XANAB (POST /api/compras con Idempotency-Key,
// 401/409/503, historial paginado). La app usa su código REAL (TiendaService →
// ApiClient → http.Client → socket TCP); sólo se redirige el host al servidor
// local. Adaptación justificada: el backend real necesita las llaves de Supabase,
// que no deben vivir en el CI; su propio pipeline prueba los endpoints reales
// (backend-chaac-xanab › src/practica11/http.e2e.spec.ts).
//
// AUT-04  La app envía la compra y recibe una respuesta válida (y no duplica al reintentar).
// AUT-05  La API devuelve el código HTTP esperado y la app lo interpreta bien.
import 'dart:convert';
import 'dart:io';

import 'package:chaac_xanab_app/models/tienda.dart';
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/tienda_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Redirige las peticiones de la app al servidor local, conservando ruta, método, cabeceras y cuerpo.
class _HaciaLocal extends http.BaseClient {
  final int puerto;
  final _cliente = http.Client();
  _HaciaLocal(this.puerto);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) {
    final copia = http.Request(r.method, r.url.replace(scheme: 'http', host: '127.0.0.1', port: puerto))
      ..headers.addAll(r.headers);
    if (r is http.Request) copia.bodyBytes = r.bodyBytes;
    return _cliente.send(copia);
  }
}

/// Servidor que reproduce el contrato de la API.
class _ApiFalsa {
  late HttpServer servidor;
  final compras = <String, Map<String, Object?>>{}; // por Idempotency-Key
  final recibidas = <Map<String, Object?>>[];
  int stock = 5;
  int fallos503Pendientes = 0;

  Future<int> iniciar() async {
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen(_atender);
    return servidor.port;
  }

  Future<void> _atender(HttpRequest req) async {
    final cuerpo = await utf8.decoder.bind(req).join();
    final res = req.response..headers.contentType = ContentType.json;
    void responder(int status, Object datos) {
      res.statusCode = status;
      res.write(jsonEncode(datos));
      res.close();
    }

    if (req.headers.value('authorization') != 'Bearer tok-p13' && req.uri.path != '/api/productos') {
      return responder(401, {'statusCode': 401, 'message': 'Unauthorized'});
    }
    if (req.uri.path == '/api/productos') {
      if (fallos503Pendientes > 0) {
        fallos503Pendientes--;
        return responder(503, {'statusCode': 503, 'message': 'Service Unavailable'});
      }
      return responder(200, [
        {'id': 'p1', 'name': 'Tenis Chaac', 'price': 1500, 'stock': stock, 'sizes': ['26']},
      ]);
    }
    if (req.uri.path == '/api/compras/mis-compras') {
      final limite = int.tryParse(req.uri.queryParameters['limite'] ?? '') ?? compras.length;
      return responder(200, compras.values.take(limite).toList());
    }
    if (req.method == 'POST' && req.uri.path == '/api/compras') {
      final datos = jsonDecode(cuerpo) as Map<String, Object?>;
      recibidas.add({...datos, 'llave': req.headers.value('idempotency-key')});
      final llave = req.headers.value('idempotency-key') ?? 'sin-llave-${recibidas.length}';
      final previa = compras[llave];
      if (previa != null) {
        res.headers.set('Idempotent-Replayed', 'true');
        return responder(201, previa);
      }
      final item = (datos['items'] as List).first as Map<String, Object?>;
      final cantidad = item['quantity'] as int;
      if (cantidad > stock) {
        return responder(409, {'statusCode': 409, 'message': 'Stock insuficiente para "Tenis Chaac". Disponible: $stock, pedido: $cantidad'});
      }
      stock -= cantidad;
      final compra = {
        'id': 'compra-${compras.length + 1}', 'total': 1500 * cantidad, 'status': 'pendiente',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'items': [{'name': 'Tenis Chaac', 'price': 1500, 'size': item['size'], 'quantity': cantidad, 'image_url': ''}],
      };
      compras[llave] = compra;
      return responder(201, compra);
    }
    responder(404, {'statusCode': 404, 'message': 'Not Found'});
  }
}

void main() {
  final api = ApiClient.instancia;
  final tienda = TiendaService();
  final servidor = _ApiFalsa();
  final direccion = Direccion(calle: 'Calle 60', numeroExt: '1', colonia: 'Centro', ciudad: 'Mérida', estado: 'Yucatán', codigoPostal: '97000');

  setUpAll(() async {
    api.cliente = _HaciaLocal(await servidor.iniciar());
    api.esperaBase = const Duration(milliseconds: 50);
  });
  setUp(() => api.token = 'tok-p13');
  tearDownAll(() => servidor.servidor.close(force: true));

  group('AUT-04 La app envía la compra y recibe una respuesta válida', () {
    test('POST /api/compras con cuerpo, token y llave correctos → 201 y la app arma el modelo Compra', () async {
      final llave = nuevaLlaveIdempotencia();
      final compra = await tienda.comprar(
          items: [{'producto_id': 'p1', 'size': '26', 'quantity': 2}], direccion: direccion, idempotencyKey: llave);

      expect(compra.total, 3000);
      expect(compra.items.single.cantidad, 2);
      final enviada = servidor.recibidas.last;
      expect(enviada['llave'], llave);
      expect((enviada['direccion'] as Map)['codigo_postal'], '97000');
      expect(enviada.containsKey('numero_int'), isFalse);
    });

    test('reintento con la MISMA llave → misma compra y el stock se descuenta una sola vez', () async {
      final llave = nuevaLlaveIdempotencia();
      final stockAntes = servidor.stock;
      final a = await tienda.comprar(items: [{'producto_id': 'p1', 'size': '26', 'quantity': 1}], direccion: direccion, idempotencyKey: llave);
      final b = await tienda.comprar(items: [{'producto_id': 'p1', 'size': '26', 'quantity': 1}], direccion: direccion, idempotencyKey: llave);
      expect(b.id, a.id);
      expect(servidor.stock, stockAntes - 1);
    });

    test('historial paginado: la app manda ?limite=20 y recibe la lista', () async {
      final lista = await tienda.misCompras(limite: 20);
      expect(lista, isNotEmpty);
      expect(lista.length, lessThanOrEqualTo(20));
    });
  });

  group('AUT-05 La API devuelve el código HTTP esperado', () {
    test('409 Conflict (stock insuficiente) → ApiException con el mensaje del servidor', () async {
      await expectLater(
        tienda.comprar(items: [{'producto_id': 'p1', 'size': '26', 'quantity': 999}], direccion: direccion),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.mensaje, 'mensaje', contains('Stock insuficiente'))),
      );
    });

    test('401 Unauthorized (sin token) → noAutorizado = true', () async {
      api.token = null;
      await expectLater(tienda.misCompras(limite: 20),
          throwsA(isA<ApiException>().having((e) => e.noAutorizado, 'noAutorizado', isTrue)));
    });

    test('503 transitorio → el GET se reintenta con backoff y termina en 200', () async {
      servidor.fallos503Pendientes = 2;
      final productos = await tienda.productos();
      expect(productos.single.nombre, 'Tenis Chaac');
      expect(servidor.fallos503Pendientes, 0);
    });
  });
}
