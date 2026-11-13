// Práctica 12 — Fase 2: profiling de la app REAL (modo profile, Windows).
//
//   flutter drive --profile -d windows --dart-define=API_URL=http://localhost:3001/api \
//     --driver=test_driver/perfil_driver.dart --target=integration_test/perfil_test.dart
//
// Recorre las 6 pruebas obligatorias con el usuario de prueba P12 y reporta:
//   - tiempo de cada operación (ms) medido con Stopwatch
//   - estadísticas de frames por fase (watchPerformance: build/raster, p90/p99, frames perdidos)
// El CPU y la RAM del proceso los registra en paralelo practica12/scripts/muestrear.ps1.
import 'dart:convert';
import 'dart:io';

import 'package:chaac_xanab_app/main.dart' as app;
import 'package:chaac_xanab_app/screens/mis_compras_screen.dart';
import 'package:chaac_xanab_app/screens/tienda_screen.dart';
import 'package:chaac_xanab_app/services/carrito_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const correo = 'p12.carga@example.invalid';
const password = 'P12carga#2026';

final operaciones = <String, List<int>>{};
final marcas = <Map<String, Object>>[];
final t0 = DateTime.now();

Future<void> esperar(WidgetTester t, Finder f, {int segundos = 40}) async {
  final fin = DateTime.now().add(Duration(seconds: segundos));
  while (DateTime.now().isBefore(fin)) {
    await t.pump(const Duration(milliseconds: 30));
    if (f.evaluate().isNotEmpty) return;
  }
  final visibles = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
  throw TestFailure('No apareció: $f\nTextos en pantalla: $visibles');
}

Future<void> esperarAusencia(WidgetTester t, Finder f, {int segundos = 40}) async {
  final fin = DateTime.now().add(Duration(seconds: segundos));
  while (DateTime.now().isBefore(fin)) {
    await t.pump(const Duration(milliseconds: 30));
    if (f.evaluate().isEmpty) return;
  }
  throw TestFailure('No desapareció: $f');
}

/// Escribe en un campo a través de su controlador (en escritorio enterText no
/// siempre llega al TextInput del sistema).
Future<void> escribir(WidgetTester t, Finder campo, String texto) async {
  final editable = find.descendant(of: campo, matching: find.byType(EditableText));
  t.widget<EditableText>(editable).controller.text = texto;
  await t.pump();
}

/// Bombea frames mientras corre una animación o carga real (en vivo).
Future<void> animar(WidgetTester t, Future<void> trabajo) async {
  var listo = false;
  trabajo.whenComplete(() => listo = true);
  while (!listo) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> op(String nombre, Future<void> Function() accion) async {
  final sw = Stopwatch()..start();
  await accion();
  sw.stop();
  operaciones.putIfAbsent(nombre, () => []).add(sw.elapsedMilliseconds);
}

void marca(String fase) => marcas.add({'fase': fase, 't_ms': DateTime.now().difference(t0).inMilliseconds});

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Perfil de la app — 6 pruebas obligatorias', (t) async {
    (await SharedPreferences.getInstance()).clear();
    marca('arranque');
    app.main();
    await esperar(t, find.text('INICIAR SESIÓN'));

    // ── Inicio de sesión ────────────────────────────────────────────────────
    marca('login');
    await escribir(t, find.byType(TextFormField).at(0), correo);
    await escribir(t, find.byType(TextFormField).at(1), password);
    await op('login', () async {
      await t.tap(find.text('INICIAR SESIÓN'));
      await esperar(t, find.byType(TarjetaProducto));
    });
    await CarritoService.instancia.vaciar();

    // ── 1. Consulta repetida (pull-to-refresh del catálogo ×10) ─────────────
    marca('consulta');
    await binding.watchPerformance(() async {
      for (var i = 0; i < 10; i++) {
        await op('consulta_catalogo', () async {
          // Mismo efecto que "jalar para recargar": dispara onRefresh (GET categorías + productos).
          final listo = t.state<RefreshIndicatorState>(find.byType(RefreshIndicator).first).show();
          var terminado = false;
          listo.whenComplete(() => terminado = true);
          while (!terminado) {
            await t.pump(const Duration(milliseconds: 20));
          }
          await esperar(t, find.byType(TarjetaProducto));
        });
      }
    }, reportKey: 'frames_consulta');

    // ── 4. Procesamiento de datos (filtro de búsqueda tecla por tecla) ──────
    marca('procesamiento');
    final buscador = find.byType(TextField).first;
    await binding.watchPerformance(() async {
      for (var r = 0; r < 3; r++) {
        for (final texto in ['t', 'te', 'ten', 'teni', 'tenis', 'P', 'P1', 'P12', '']) {
          await op('filtro_busqueda', () async {
            await escribir(t, buscador, texto);
            await t.pump();
          });
          await t.pump(const Duration(milliseconds: 60));
        }
      }
    }, reportKey: 'frames_procesamiento');

    // ── 3. Navegación entre pantallas principales ×3 ────────────────────────
    marca('navegacion');
    await binding.watchPerformance(() async {
      for (var r = 0; r < 3; r++) {
        await op('ir_carrito', () async {
          await t.tap(find.text('Carrito'));
          await esperar(t, find.text('Mi carrito').hitTestable());
        });
        // 1.ª vez: descarga completa del historial; después: lista en memoria + recarga.
        await op(r == 0 ? 'abrir_pedidos_1ra' : 'abrir_pedidos', () async {
          await t.tap(find.text('Pedidos'));
          await esperar(t, find.textContaining('Pedido #').hitTestable());
        });
        await op('scroll_pedidos', () async {
          final lista = find.descendant(of: find.byType(MisComprasScreen), matching: find.byType(Scrollable)).first;
          final pos = t.state<ScrollableState>(lista).position;
          await animar(t, pos.animateTo(pos.maxScrollExtent, duration: const Duration(seconds: 3), curve: Curves.linear));
          await animar(t, pos.animateTo(0, duration: const Duration(milliseconds: 800), curve: Curves.linear));
        });
        await op('ir_perfil', () async {
          await t.tap(find.text('Perfil'));
          await esperar(t, find.text('Cerrar sesión').hitTestable());
        });
        await op('ir_tienda', () async {
          await t.tap(find.text('Tienda'));
          await esperar(t, find.text('Encuentra tu par ideal').hitTestable());
        });
      }
    }, reportKey: 'frames_navegacion');

    // ── 2. Escritura: agregar al carrito (SQLite) y confirmar compra (API) ──
    marca('escritura');
    await binding.watchPerformance(() async {
      for (var r = 0; r < 2; r++) {
        await escribir(t, buscador, 'P12');
        await t.pump(const Duration(milliseconds: 200));
        final tarjeta = find.byType(TarjetaProducto).first;
        await esperar(t, tarjeta);
        await t.ensureVisible(tarjeta);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(tarjeta);
        await esperar(t, find.text('Talla (MX)').hitTestable());
        final talla = find.text('26').last;
        await t.ensureVisible(talla);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(talla);
        await t.pump(const Duration(milliseconds: 200));
        await op('agregar_carrito', () async {
          await t.tap(find.textContaining('AGREGAR AL CARRITO').hitTestable());
          await esperar(t, find.textContaining('agregado al carrito'));
        });
        // El aviso flotante tapa el botón de pago: se cierra como lo haría el usuario.
        t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).removeCurrentSnackBar();
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.byIcon(Icons.arrow_back).hitTestable().first);
        await esperarAusencia(t, find.text('Talla (MX)'));
        await t.tap(find.text('Carrito'));
        await esperar(t, find.text('CONTINUAR AL PAGO').hitTestable());
        await t.tap(find.text('CONTINUAR AL PAGO').hitTestable());
        await esperar(t, find.textContaining('CONFIRMAR COMPRA').hitTestable());
        await t.pump(const Duration(milliseconds: 300));
        await op('confirmar_compra', () async {
          await t.tap(find.textContaining('CONFIRMAR COMPRA').hitTestable());
          await esperar(t, find.text('¡Compra realizada!'));
        });
        await t.tap(find.text('VER MIS PEDIDOS'));
        await esperar(t, find.text('Mis pedidos').hitTestable());
        await t.tap(find.text('Tienda'));
        await esperar(t, find.byType(TiendaScreen).hitTestable());
        await escribir(t, buscador, '');
      }
    }, reportKey: 'frames_escritura');
    marca('fin');

    binding.reportData ??= {};
    binding.reportData!['operaciones'] = operaciones;
    binding.reportData!['marcas'] = marcas;
    // En escritorio el reporte también se escribe directo (el driver no siempre lo recibe).
    const ruta = String.fromEnvironment('P12_SALIDA', defaultValue: 'practica12/resultados/perfil/perfil.json');
    File(ruta)
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(binding.reportData));
  });
}
