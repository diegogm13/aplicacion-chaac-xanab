// Capturas de evidencia de las prácticas 3, 4 y 5 con la app REAL en ejecución (Windows, tamaño de teléfono).
//
// Fase "ok" (API local con el catálogo guardado en la Práctica 11):
//   flutter drive --profile -d windows --dart-define=FASE=ok --dart-define=API_URL=http://localhost:4300/api \
//     --dart-define=CAPTURAS=<carpeta> --driver=test_driver/perfil_driver.dart --target=integration_test/practicas_capturas_test.dart
// Fase "error" (API de producción tal como está):
//   flutter drive --profile -d windows --dart-define=FASE=error --dart-define=CAPTURAS=<carpeta> ...
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chaac_xanab_app/db/usuario_dao.dart';
import 'package:chaac_xanab_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const carpeta = String.fromEnvironment('CAPTURAS', defaultValue: 'capturas_practicas');
const fase = String.fromEnvironment('FASE', defaultValue: 'ok');
const telefono = Size(412, 860);
final raiz = GlobalKey();

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

Future<void> capturar(WidgetTester t, String nombre) async {
  await asentar(t, 700);
  final limite = raiz.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final imagen = await limite.toImage(pixelRatio: 2.5);
  final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
  File('$carpeta/$nombre.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

Future<void> abrirPractica(WidgetTester t, String texto) async {
  final opcion = find.text(texto);
  await t.ensureVisible(opcion);
  await t.tap(opcion);
  await asentar(t);
}

Future<void> volver(WidgetTester t) async {
  t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).removeCurrentSnackBar();
  await t.tap(find.byIcon(Icons.arrow_back).hitTestable().first);
  await asentar(t);
}

/// Pulsa un botón llamando a su acción (las animaciones de la hoja inferior y del aviso
/// mueven los botones y hacen fallar los toques por coordenadas).
Future<void> pulsar(WidgetTester t, String texto) async {
  final boton = find.ancestor(of: find.text(texto), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton || w is FloatingActionButton));
  final w = t.widget(boton.first);
  (w is FloatingActionButton ? w.onPressed : (w as ButtonStyleButton).onPressed)!();
  await asentar(t, 500);
}

Future<void> registrarUsuario(WidgetTester t, String nombre, String edad, String profesion, String correo) async {
  t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).removeCurrentSnackBar();
  await asentar(t, 400);
  await pulsar(t, 'Registrar');
  await esperar(t, find.text('REGISTRAR'));
  await asentar(t, 400);
  await escribir(t, find.widgetWithText(TextFormField, 'Nombre'), nombre);
  await escribir(t, find.widgetWithText(TextFormField, 'Edad'), edad);
  await escribir(t, find.widgetWithText(TextFormField, 'Profesión / carrera'), profesion);
  await escribir(t, find.widgetWithText(TextFormField, 'Correo'), correo);
  await pulsar(t, 'REGISTRAR');
  await esperar(t, find.text(nombre));
  await asentar(t, 400);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Capturas de las prácticas (fase $fase)', (t) async {
    await binding.setSurfaceSize(telefono);
    (await SharedPreferences.getInstance()).clear();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dao = UsuarioDao();
    for (final u in await dao.obtenerTodos()) {
      await dao.eliminar(u.id!);
    }
    runApp(RepaintBoundary(key: raiz, child: const app.ChaacXanabApp()));
    await esperar(t, find.text('INICIAR SESIÓN'));

    if (fase == 'p9') {
      // Práctica 9: la app (dispositivo A) muestra el nombre que cambió otra sesión (dispositivo B).
      await escribir(t, find.byType(TextFormField).at(0), 'p12.carga@example.invalid');
      await escribir(t, find.byType(TextFormField).at(1), 'P12carga#2026');
      await t.tap(find.text('INICIAR SESIÓN'));
      await esperar(t, find.text('Perfil'));
      await asentar(t, 1500);
      await t.tap(find.text('Perfil'));
      await esperar(t, find.text('PRUEBA_B_001'));
      await capturar(t, 'p9_app_perfil_cambio_de_b');
      return;
    }

    if (fase == 'ok') {
      // Práctica 5: entradas inválidas (no llegan al servidor).
      await escribir(t, find.byType(TextFormField).at(0), '     ');
      await escribir(t, find.byType(TextFormField).at(1), '123');
      await t.tap(find.text('INICIAR SESIÓN'));
      await asentar(t, 500);
      await capturar(t, 'p5_login_invalido');
    } else {
      // Práctica 5: credenciales con formato válido pero inexistentes -> mensaje genérico del servidor.
      await escribir(t, find.byType(TextFormField).at(0), 'cliente@example.invalid');
      await escribir(t, find.byType(TextFormField).at(1), 'Prueba#2026');
      await t.tap(find.text('INICIAR SESIÓN'));
      await esperar(t, find.textContaining('Correo o contraseña incorrectos'), segundos: 30);
      await capturar(t, 'p5_login_mensaje_generico');
    }

    // Entrar como invitado e ir a Perfil > Prácticas.
    await escribir(t, find.byType(TextFormField).at(0), '');
    await escribir(t, find.byType(TextFormField).at(1), '');
    await t.tap(find.text('Explorar como invitado'));
    await asentar(t, 1500);
    await t.tap(find.text('Perfil'));
    await asentar(t);

    // Práctica 3: ConsultaWeb.
    await abrirPractica(t, 'Práctica 3 · Consulta de información');
    await capturar(t, 'p3_${fase}_inicial');
    await t.tap(find.text('CONSULTAR'));
    if (fase == 'ok') {
      await esperar(t, find.textContaining('productos recibidos'));
      await capturar(t, 'p3_ok_resultado');
    } else {
      await esperar(t, find.text('No fue posible obtener la información.'), segundos: 30);
      await capturar(t, 'p3_error_sin_servidor');
    }
    await volver(t);

    if (fase == 'ok') {
      // Práctica 4: CRUD en SQLite.
      await abrirPractica(t, 'Práctica 4 · Usuarios en SQLite');
      await registrarUsuario(t, 'Ana López', '21', 'Ing. en Software', 'ana@chaac.mx');
      await registrarUsuario(t, 'Luis Pérez', '22', 'Diseño Digital', 'luis@chaac.mx');
      await registrarUsuario(t, 'María Can', '20', 'Mecatrónica', '');
      t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).removeCurrentSnackBar();
      await t.tap(find.text('VER usuarios'));
      await asentar(t, 900);
      await capturar(t, 'p4_usuarios_consulta');

      // Caso 3: actualizar la carrera de un usuario.
      final fila = find.ancestor(of: find.text('Luis Pérez'), matching: find.byType(ListTile));
      await t.tap(find.descendant(of: fila, matching: find.byTooltip('Modificar')));
      await esperar(t, find.text('GUARDAR CAMBIOS'));
      await asentar(t, 800);
      await escribir(t, find.widgetWithText(TextFormField, 'Profesión / carrera'), 'Ing. en Datos');
      await pulsar(t, 'GUARDAR CAMBIOS');
      await esperar(t, find.textContaining('Ing. en Datos'));
      await asentar(t, 300);
      await capturar(t, 'p4_usuarios_actualizado');
    }
  });
}
