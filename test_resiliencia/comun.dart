// Práctica 12 — utilidades del arnés de resiliencia (RES-01 … RES-08).
// Requiere: backend en BACKEND_URL y proxy de fallas en PROXY (scripts/servidor_fallas.mjs);
// la app se compila con --dart-define=API_URL=<PROXY>/api para que sus peticiones pasen por el proxy.
import 'dart:convert';
import 'dart:io';

import 'package:chaac_xanab_app/models/tienda.dart';
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:http/http.dart' as http;

const proxy = String.fromEnvironment('PROXY', defaultValue: 'http://localhost:3100');
const backend = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3001/api');
const correo = 'p12.carga@example.invalid';
const password = 'P12carga#2026';

final resultados = <Map<String, Object?>>[];
late String token;
late String productoId;

final direccion = Direccion(
  calle: 'Calle P12', numeroExt: '1', colonia: 'Centro', ciudad: 'Mérida', estado: 'Yucatán', codigoPostal: '97000');

List<Map<String, dynamic>> items() => [
      {'producto_id': productoId, 'size': '26', 'quantity': 1},
    ];

Future<void> modo(String m) async => http.get(Uri.parse('$proxy/__modo?m=$m'));

Future<void> preparar() async {
  final r = await http.post(Uri.parse('$backend/auth/login'),
      headers: {'content-type': 'application/json'}, body: jsonEncode({'email': correo, 'password': password}));
  token = (jsonDecode(r.body) as Map)['token'] as String;
  ApiClient.instancia.token = token;
  final productos = jsonDecode(utf8.decode((await http.get(Uri.parse('$backend/productos'))).bodyBytes)) as List;
  productoId = (productos.firstWhere((p) => (p['name'] as String).startsWith('P12 PRUEBA')))['id'] as String;
  await modo('normal');
}

/// Ids de las compras más recientes del usuario P12 (directo al backend, sin proxy).
/// No se cuenta el total: PostgREST corta las respuestas en 1,000 filas y el
/// usuario de prueba ya tiene más; se comparan los ids recientes antes y después.
Future<Set<String>> comprasEnServidor() async {
  final r = await http.get(Uri.parse('$backend/compras/mis-compras?limite=100'), headers: {'authorization': 'Bearer $token'});
  return (jsonDecode(r.body) as List).map((c) => c['id'] as String).take(100).toSet();
}

/// Compras nuevas respecto a una foto previa de [comprasEnServidor].
Future<int> comprasNuevas(Set<String> antes) async => (await comprasEnServidor()).difference(antes).length;

/// Ejecuta una operación y devuelve (ms, error o null).
Future<(int, Object?)> cronometrar(Future<Object?> Function() f) async {
  final sw = Stopwatch()..start();
  try {
    await f();
    return (sw.elapsedMilliseconds, null);
  } catch (e) {
    return (sw.elapsedMilliseconds, e);
  }
}

void registrar(String id, String escenario, String esperado, String observado, int ms, bool cumple, [Map<String, Object?>? extra]) {
  resultados.add({'id': id, 'escenario': escenario, 'esperado': esperado, 'observado': observado,
    'tiempo_ms': ms, 'cumple': cumple, ...?extra});
  // ignore: avoid_print
  print('${cumple ? 'OK   ' : 'FALLA'} $id ($ms ms) $observado');
}

void guardar(String ruta) {
  File(ruta)
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'fecha': DateTime.now().toIso8601String(), 'resultados': resultados}));
}

String describir(Object? e) => e == null ? 'sin error' : (e is ApiException ? 'ApiException(${e.status ?? 'sin status'}): ${e.mensaje}' : '$e');
