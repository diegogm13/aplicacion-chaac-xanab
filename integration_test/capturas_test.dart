// Capturas de la app REAL en ejecución (Windows, modo profile) con tamaño de teléfono.
//
//   flutter drive --profile -d windows --dart-define=API_URL=http://localhost:3005/api \
//     --dart-define=CAPTURAS=<carpeta absoluta> --driver=test_driver/perfil_driver.dart \
//     --target=integration_test/capturas_test.dart
//
// Cada captura es la imagen que la app está pintando en ese momento (capa raíz del
// RenderView), sin elementos del escritorio alrededor.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chaac_xanab_app/main.dart' as app;
import 'package:chaac_xanab_app/screens/tienda_screen.dart';
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/carrito_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const carpeta = String.fromEnvironment('CAPTURAS', defaultValue: 'capturas_app');
const telefono = Size(412, 860); // proporción de un teléfono Android común

Future<void> esperar(WidgetTester t, Finder f, {int segundos = 40}) async {
  final fin = DateTime.now().add(Duration(seconds: segundos));
  while (DateTime.now().isBefore(fin)) {
    await t.pump(const Duration(milliseconds: 40));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció: $f');
}

Future<void> asentar(WidgetTester t, [int ms = 900]) async {
  final fin = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(fin)) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

Future<void> escribir(WidgetTester t, Finder campo, String texto) async {
  t.widget<EditableText>(find.descendant(of: campo, matching: find.byType(EditableText))).controller.text = texto;
  await t.pump();
}

final raiz = GlobalKey();

Future<void> capturar(WidgetTester t, String nombre) async {
  await asentar(t, 700);
  final limite = raiz.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final imagen = await limite.toImage(pixelRatio: 2.5);
  final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
  File('$carpeta/$nombre.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Capturas de la app en ejecución', (t) async {
    await binding.setSurfaceSize(telefono);
    (await SharedPreferences.getInstance()).clear();
    // Misma inicialización que main(), con la app envuelta en un RepaintBoundary para capturarla.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    runApp(RepaintBoundary(key: raiz, child: const app.ChaacXanabApp()));
    await esperar(t, find.text('INICIAR SESIÓN'));
    await escribir(t, find.byType(TextFormField).at(0), 'p12.carga@example.invalid');
    await escribir(t, find.byType(TextFormField).at(1), 'P12carga#2026');
    await capturar(t, '01_inicio_sesion');

    await t.tap(find.text('INICIAR SESIÓN'));
    await esperar(t, find.byType(TarjetaProducto));
    await CarritoService.instancia.vaciar();
    await asentar(t, 2500); // imágenes del catálogo
    await capturar(t, '02_tienda_catalogo');

    await escribir(t, find.byType(TextField).first, 'P12');
    await asentar(t, 1200);
    await capturar(t, '03_busqueda');

    // Producto agotado (DEF-02 corregido: no se puede agregar).
    await t.tap(find.text('P12 AGOTADO (prueba)').first);
    await esperar(t, find.text('Talla (MX)'));
    await capturar(t, '04_producto_agotado');
    await t.tap(find.byIcon(Icons.arrow_back).hitTestable().first);
    await asentar(t);

    // Producto disponible → agregar al carrito (SQLite).
    await t.tap(find.text('P12 PRUEBA DE CARGA (no comprar)').first);
    await esperar(t, find.text('Talla (MX)'));
    final talla = find.text('26').last;
    await t.ensureVisible(talla);
    await t.tap(talla);
    await asentar(t, 400);
    await capturar(t, '05_producto_detalle');
    await t.tap(find.textContaining('AGREGAR AL CARRITO').hitTestable());
    await esperar(t, find.textContaining('agregado al carrito'));
    await capturar(t, '06_agregado_al_carrito');
    t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).removeCurrentSnackBar();
    await t.tap(find.byIcon(Icons.arrow_back).hitTestable().first);
    await asentar(t);

    await t.tap(find.text('Carrito'));
    await esperar(t, find.text('CONTINUAR AL PAGO').hitTestable());
    await capturar(t, '07_carrito');

    await t.tap(find.text('CONTINUAR AL PAGO').hitTestable());
    await esperar(t, find.textContaining('CONFIRMAR COMPRA').hitTestable());
    await asentar(t, 1500); // precarga de la dirección guardada
    for (final (etiqueta, valor) in [('Calle', 'Calle 60'), ('Núm. exterior', '123'), ('Colonia', 'Centro'),
        ('Ciudad', 'Mérida'), ('Estado', 'Yucatán'), ('Código postal', '97000')]) {
      await escribir(t, campo(etiqueta), valor);
    }
    await capturar(t, '08_checkout');

    await t.tap(find.textContaining('CONFIRMAR COMPRA').hitTestable());
    await esperar(t, find.text('¡Compra realizada!'));
    await capturar(t, '09_compra_realizada');

    await t.tap(find.text('VER MIS PEDIDOS'));
    await esperar(t, find.textContaining('Pedido #').hitTestable());
    await asentar(t, 1500);
    await capturar(t, '10_mis_pedidos');

    await t.tap(find.text('Perfil'));
    await esperar(t, find.text('Cerrar sesión').hitTestable());
    await capturar(t, '11_perfil');

    // Sin conexión: el transporte HTTP falla como en modo avión → error controlado + Reintentar.
    final real = ApiClient.instancia;
    real.cliente = MockClient((_) async => throw const SocketException('Network is unreachable'));
    real.esperaBase = Duration.zero;
    await t.tap(find.text('Tienda'));
    await asentar(t, 400);
    await escribir(t, find.byType(TextField).first, '');
    final listo = t.state<RefreshIndicatorState>(find.byType(RefreshIndicator).first).show();
    var terminado = false;
    listo.whenComplete(() => terminado = true);
    while (!terminado) {
      await t.pump(const Duration(milliseconds: 30));
    }
    await esperar(t, find.text('Reintentar'));
    await capturar(t, '12_sin_conexion');
    real.cliente = http.Client();
  });
}
