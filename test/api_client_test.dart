// Práctica 11 — White Box: método de COMUNICACIÓN con el servicio
// (lib/services/api_client.dart → _enviar() y _mensajeDe()).
//
// Grafo de _enviar (ver INFORME §2.3):
//   D1 catch (excepción de red/timeout)      -> P1
//   D2 texto.isEmpty                          -> datos = null
//   D3 _jsonSeguro: jsonDecode lanza           -> datos = null
//   D4 status >= 200 (C1) && status < 300 (C2) -> return datos
//   D5 datos is Map                            -> cuerpo
//   _mensajeDe: D6 m is List (C3) && m.isNotEmpty (C4)
//               D7 m is String (C5) && m.isNotEmpty (C6)
//               D8 status == 401
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response resp(Object? cuerpo, int status) => http.Response.bytes(
      utf8.encode(cuerpo == null ? '' : (cuerpo is String ? cuerpo : jsonEncode(cuerpo))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient con(MockClientHandler h) => ApiClient.conCliente(MockClient(h));

Future<ApiException> fallo(Future<dynamic> f) async {
  try {
    await f;
  } on ApiException catch (e) {
    return e;
  }
  fail('Se esperaba ApiException');
}

void main() {
  group('_enviar(): caminos independientes', () {
    test('P1  D1=V  sin red (SocketException) -> ApiException sin status', () async {
      final e = await fallo(con((_) async => throw const SocketException('Network is unreachable')).get('/productos'));
      expect(e.status, isNull);
      expect(e.mensaje, contains('No fue posible conectar'));
      expect(e.noAutorizado, isFalse);
    });

    test('P1  D1=V  timeout -> mismo mensaje de conexión', () async {
      final e = await fallo(con((_) async => throw TimeoutException('20s')).post('/compras', {}));
      expect(e.mensaje, contains('Revisa tu conexión'));
    });

    test('P2  D2=F D3=ok D4=V  200 con JSON -> devuelve datos', () async {
      final r = await con((_) async => resp([{'id': 'a'}], 200)).get('/productos');
      expect(r, [{'id': 'a'}]);
    });

    test('P3  D2=V D4=V  204 sin cuerpo -> null', () async {
      expect(await con((_) async => resp(null, 204)).put('/x', {}), isNull);
    });

    test('P4  D3=error D4=V  200 con cuerpo no-JSON -> null (no lanza)', () async {
      expect(await con((_) async => resp('<html>ok</html>', 200)).get('/x'), isNull);
    });

    test('UTF-8: acentos llegan intactos', () async {
      final r = await con((_) async => resp({'name': 'Añil Café'}, 200)).get('/x');
      expect(r['name'], 'Añil Café');
    });
  });

  group('D4 = status >= 200 (C1) && status < 300 (C2) — valores límite', () {
    for (final (status, exito) in [(199, false), (200, true), (201, true), (299, true), (300, false)]) {
      test('status $status -> ${exito ? 'éxito' : 'ApiException'}', () async {
        final f = con((_) async => resp({'ok': true}, status)).get('/x');
        if (exito) {
          expect(await f, {'ok': true});
        } else {
          expect((await fallo(f)).status, status);
        }
      });
    }
  });

  group('_mensajeDe(): cobertura de decisiones y condiciones', () {
    test('D6 C3=V C4=V  message: [lista] -> primer elemento (class-validator)', () async {
      final e = await fallo(con((_) async =>
          resp({'message': ['email must be an email', 'password too weak'], 'statusCode': 400}, 400)).post('/auth/register', {}));
      expect(e.mensaje, 'email must be an email');
      expect(e.status, 400);
      expect(e.cuerpo?['statusCode'], 400);
    });

    test('D6 C3=V C4=F  message: [] vacía -> cae a mensaje genérico', () async {
      final e = await fallo(con((_) async => resp({'message': []}, 422)).get('/x'));
      expect(e.mensaje, 'Ocurrió un error (422). Intenta de nuevo.');
    });

    test('D7 C5=V C6=V  message: "texto" -> texto', () async {
      final e = await fallo(con((_) async => resp({'message': 'Compra no encontrada'}, 404)).get('/compras/1'));
      expect(e.mensaje, 'Compra no encontrada');
    });

    test('D7 C5=V C6=F  message: "" con 401 -> sesión expirada', () async {
      final e = await fallo(con((_) async => resp({'message': ''}, 401)).get('/auth/me'));
      expect(e.mensaje, contains('sesión expiró'));
      expect(e.noAutorizado, isTrue);
    });

    test('D8=V  401 sin cuerpo -> sesión expirada', () async {
      final e = await fallo(con((_) async => resp(null, 401)).get('/auth/me'));
      expect(e.mensaje, 'Tu sesión expiró. Inicia sesión de nuevo.');
      expect(e.cuerpo, isNull);
    });

    test('D5=F  502 con cuerpo HTML -> genérico, cuerpo null', () async {
      final e = await fallo(con((_) async => resp('<h1>Bad Gateway</h1>', 502)).get('/x'));
      expect(e.mensaje, 'La tienda tuvo un problema. Intenta de nuevo en unos minutos.');
      expect(e.cuerpo, isNull);
    });

    test('D5=F  cuerpo JSON que es lista (no Map) -> genérico', () async {
      final e = await fallo(con((_) async => resp([1, 2], 422)).get('/x'));
      expect(e.cuerpo, isNull);
      expect(e.toString(), 'Ocurrió un error (422). Intenta de nuevo.');
    });

    test('P5  un 500 nunca muestra el mensaje técnico del servidor', () async {
      final e = await fallo(con((_) async => resp({'statusCode': 500, 'message': 'Internal server error'}, 500)).get('/x'));
      expect(e.mensaje, 'La tienda tuvo un problema. Intenta de nuevo en unos minutos.');
      expect(e.mensaje, isNot(contains('Internal')));
      expect(e.status, 500);
    });

    test('403 se distingue de 401 (autorización ≠ autenticación)', () async {
      final e = await fallo(con((_) async => resp({'message': 'No tienes permisos para esta acción'}, 403)).get('/admin'));
      expect(e.status, 403);
      expect(e.noAutorizado, isFalse, reason: 'un 403 NO debe cerrar la sesión');
    });
  });

  group('Cabeceras', () {
    test('sin token no envía Authorization; con token envía Bearer', () async {
      final vistos = <String?>[];
      final api = con((req) async {
        vistos.add(req.headers['Authorization']);
        expect(req.headers['Content-Type'], 'application/json');
        return resp({}, 200);
      });
      await api.get('/productos');
      api.token = 'abc.def.ghi';
      await api.get('/auth/me');
      expect(vistos, [null, 'Bearer abc.def.ghi']);
    });

    test('query params se codifican en la URL', () async {
      late Uri uri;
      await con((req) async {
        uri = req.url;
        return resp([], 200);
      }).get('/productos', query: {'categoria_slug': 'running', 'q': 'tenis rojos'});
      expect(uri.path, '/api/productos');
      expect(uri.queryParameters['q'], 'tenis rojos');
    });
  });

  group('AuthService: manejo de excepciones', () {
    final api = ApiClient.instancia;
    final auth = AuthService.instancia;

    setUp(() {
      SharedPreferences.setMockInitialValues({'jwt': 'token-guardado'});
      api.token = null;
      auth.usuario = null;
    });

    test('restaurar(): 401 -> borra token guardado', () async {
      api.cliente = MockClient((_) async => resp({'message': 'Unauthorized', 'statusCode': 401}, 401));
      await auth.restaurar();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt'), isNull);
      expect(api.token, isNull);
      expect(auth.conSesion, isFalse);
    });

    test('restaurar(): sin red -> CONSERVA el token para reintentar', () async {
      api.cliente = MockClient((_) async => throw const SocketException('offline'));
      await auth.restaurar();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt'), 'token-guardado');
      expect(auth.conSesion, isFalse);
    });

    test('restaurar(): sin token guardado -> no hace petición', () async {
      SharedPreferences.setMockInitialValues({});
      var llamadas = 0;
      api.cliente = MockClient((_) async {
        llamadas++;
        return resp({}, 200);
      });
      await auth.restaurar();
      expect(llamadas, 0);
    });

    test('login(): éxito guarda token y usuario', () async {
      api.cliente = MockClient((req) async => req.url.path.endsWith('/login')
          ? resp({'token': 'jwt-nuevo'}, 201)
          : resp({'id': 'u1', 'name': 'Ana López', 'email': 'ana@x.mx', 'role': 'cliente'}, 200));
      await auth.login('ana@x.mx', 'Chaac#2026');
      expect(auth.usuario?.primerNombre, 'Ana');
      expect((await SharedPreferences.getInstance()).getString('jwt'), 'jwt-nuevo');
    });

    final traducciones = {
      ('EMAIL_NOT_VERIFIED', null): 'Tu correo aún no está verificado. Revisa tu bandeja de entrada.',
      ('ACCOUNT_LOCKED', 15): 'Cuenta bloqueada por intentos fallidos. Intenta en 15 minutos.',
      ('ACCOUNT_LOCKED', null): 'Cuenta bloqueada por intentos fallidos. Intenta en unos minutos.',
      ('Correo o contraseña incorrectos', null): 'Correo o contraseña incorrectos',
    };
    traducciones.forEach((entrada, esperado) {
      test('login(): traduce "${entrada.$1}" (min=${entrada.$2})', () async {
        api.cliente = MockClient((_) async => resp({
              'message': entrada.$1,
              if (entrada.$2 != null) 'retryAfterMinutes': entrada.$2,
            }, 401));
        final e = await fallo(auth.login('ana@x.mx', 'mala'));
        expect(e.mensaje, esperado);
        expect(e.status, 401);
        expect(auth.conSesion, isFalse);
      });
    });

    test('registrar(): 201 con mensaje / sin mensaje / 409 conflicto', () async {
      api.cliente = MockClient((_) async => resp({'message': 'Te enviamos un correo'}, 201));
      expect(await auth.registrar('Ana', 'ana@x.mx', 'Chaac#2026'), 'Te enviamos un correo');
      api.cliente = MockClient((_) async => resp({}, 201));
      expect(await auth.registrar('Ana', 'ana@x.mx', 'Chaac#2026'), 'Cuenta creada. Revisa tu correo.');
      api.cliente = MockClient((_) async => resp({'message': 'El correo ya está registrado', 'statusCode': 409}, 409));
      final e = await fallo(auth.registrar('Ana', 'ana@x.mx', 'Chaac#2026'));
      expect((e.status, e.mensaje), (409, 'El correo ya está registrado'));
    });

    test('logout(): aunque falle la red, la sesión local se cierra', () async {
      api.token = 'x';
      api.cliente = MockClient((_) async => throw const SocketException('offline'));
      await auth.logout();
      expect(api.token, isNull);
      expect((await SharedPreferences.getInstance()).getString('jwt'), isNull);
    });
  });
}
