// Práctica 11 — WB-06: costo en el hilo de UI de procesar la respuesta real de
// GET /api/productos (guardada por practica11/scripts/medir_red.ps1 en
// practica11/resultados/productos_real.json).
//
// jsonDecode + Producto.fromJson corren en el isolate principal (el mismo que
// pinta los frames). Si el costo se acerca a 16 ms (1 frame a 60 Hz) conviene
// moverlo a compute()/Isolate.run.
import 'dart:convert';
import 'dart:io';

import 'package:chaac_xanab_app/models/producto.dart';
import 'package:chaac_xanab_app/screens/tienda_screen.dart';
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/tienda_service.dart';
import 'package:chaac_xanab_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

double _promedioMs(void Function() f, int n) {
  for (var i = 0; i < 20; i++) {
    f(); // calentamiento del JIT
  }
  final sw = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    f();
  }
  return sw.elapsedMicroseconds / n / 1000;
}

void main() {
  final archivo = File('practica11/resultados/productos_real.json');
  final metricas = <String, Object?>{};

  tearDownAll(() {
    File('practica11/resultados/rendimiento_app.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metricas));
  });

  test('parseo del catálogo real: 1x y escalado a 10x / 100x', () {
    final bytes = archivo.readAsBytesSync();
    final lista = jsonDecode(utf8.decode(bytes)) as List<dynamic>;
    List<Producto> parsear(List<dynamic> l) => l.map((e) => Producto.fromJson(e as Map<String, dynamic>)).toList();

    for (final factor in [1, 10, 100]) {
      final grande = utf8.encode(jsonEncode([for (var i = 0; i < factor; i++) ...lista]));
      final ms = _promedioMs(() => parsear(jsonDecode(utf8.decode(grande)) as List<dynamic>), factor == 100 ? 20 : 200);
      metricas['parseo_x$factor'] = {
        'productos': lista.length * factor,
        'bytes': grande.length,
        'ms_promedio': double.parse(ms.toStringAsFixed(3)),
        'frames_60hz': double.parse((ms / 16.67).toStringAsFixed(2)),
      };
    }
    expect(parsear(lista).length, lista.length);
    expect((metricas['parseo_x1'] as Map)['ms_promedio'] as double, lessThan(16.67),
        reason: 'el catálogo actual se procesa en menos de un frame');
  });

  testWidgets('TiendaScreen: primer frame con el catálogo real (servidor simulado)', (tester) async {
    final cuerpo = archivo.readAsBytesSync();
    ApiClient.instancia.cliente = MockClient((req) async => req.url.path.endsWith('/categorias')
        ? http.Response('[]', 200, headers: {'content-type': 'application/json'})
        : http.Response.bytes(cuerpo, 200, headers: {'content-type': 'application/json; charset=utf-8'}));

    await tester.pumpWidget(MaterialApp(theme: chaacTheme(), home: const Scaffold(body: TiendaScreen())));
    final sw = Stopwatch()..start();
    await tester.pumpAndSettle();
    sw.stop();
    metricas['tienda_pump_and_settle_ms'] = sw.elapsedMilliseconds;
    expect(find.byType(TarjetaProducto), findsWidgets);
  });

  test('DEFECTO DEF-10: 200 con forma inesperada -> TypeError (no ApiException) que TiendaScreen no atrapa', () async {
    // TiendaScreen._cargar() sólo tiene `on ApiException catch`. Al ejecutarlo
    // como widget, este mismo TypeError se reporta como excepción NO capturada
    // y la pantalla queda sin productos y sin botón "Reintentar".
    ApiClient.instancia.cliente = MockClient((_) async =>
        http.Response('{"message":"mantenimiento"}', 200, headers: {'content-type': 'application/json'}));
    final error = await TiendaService().productos().then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, isA<TypeError>());
    expect(error, isNot(isA<ApiException>()));
  });
}
