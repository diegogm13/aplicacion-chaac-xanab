// Práctica 12 — Resiliencia de la app OPTIMIZADA (reintentos con backoff + idempotencia).
//   node practica12/scripts/servidor_fallas.mjs --puerto 3100 --destino http://localhost:3000
//   flutter test test_resiliencia/res_despues_test.dart --dart-define=API_URL=http://localhost:3100/api \
//                --dart-define=BACKEND_URL=http://localhost:3000/api
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/tienda_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'comun.dart';

void main() {
  final tienda = TiendaService();
  final api = ApiClient.instancia;
  setUpAll(preparar);
  tearDown(() => modo('normal'));
  tearDownAll(() => guardar('practica12/resultados/resiliencia/res_despues.json'));

  int reintentos(void Function() f) {
    final a = api.reintentosRealizados;
    f();
    return api.reintentosRealizados - a;
  }

  test('RES-01 pérdida de red durante una consulta', () async {
    await modo('reset');
    final a = api.reintentosRealizados;
    final (ms, e) = await cronometrar(() => tienda.productos());
    registrar('RES-01', 'Pérdida de Internet durante una consulta', 'Error controlado',
        '${describir(e)} · reintentos automáticos: ${api.reintentosRealizados - a}', ms,
        e is ApiException && e.status == null, {'reintentos': api.reintentosRealizados - a});
  });

  test('RES-02 pérdida de red durante una escritura', () async {
    final antes = await comprasEnServidor();
    await modo('reset');
    final (ms, e) = await cronometrar(
        () => tienda.comprar(items: items(), direccion: direccion, idempotencyKey: nuevaLlaveIdempotencia()));
    await modo('normal');
    final nuevasRes02 = await comprasNuevas(antes);
    registrar('RES-02', 'Pérdida de Internet durante una escritura', 'No confirmar falsamente el registro',
        '${describir(e)} · compras nuevas en servidor: $nuevasRes02', ms, e is ApiException && nuevasRes02 == 0,
        {'compras_nuevas': nuevasRes02});
  });

  test('RES-03 servidor sin respuesta', () async {
    await modo('colgado');
    final (ms, e) = await cronometrar(() => tienda.productos());
    registrar('RES-03', 'Servidor sin respuesta', 'Timeout controlado',
        '${describir(e)} · porTimeout=${(e as ApiException?)?.porTimeout} (no se reintenta un timeout)', ms,
        e is ApiException && e.porTimeout);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('RES-04 respuesta HTTP 500', () async {
    await modo('500');
    final (ms, e) = await cronometrar(() => tienda.productos());
    await modo('normal');
    final (ms2, e2) = await cronometrar(() => tienda.productos());
    registrar('RES-04', 'Respuesta HTTP 500', 'Mostrar error y conservar estabilidad',
        '${describir(e)} · siguiente consulta: ${e2 == null ? 'OK' : describir(e2)} ($ms2 ms)', ms,
        e is ApiException && e.status == 500 && e2 == null);
  });

  test('RES-05 respuestas 401 y 403', () async {
    await modo('401');
    final (ms, e) = await cronometrar(() => tienda.misCompras(limite: 20));
    await modo('403');
    final (ms2, e2) = await cronometrar(() => tienda.misCompras(limite: 20));
    final ok = e is ApiException && e.noAutorizado && e2 is ApiException && !e2.noAutorizado && e2.status == 403;
    registrar('RES-05', 'Respuesta HTTP 401 o 403', 'Gestionar autenticación o permisos',
        '401 → noAutorizado=${(e as ApiException?)?.noAutorizado} (cierra sesión) · 403 → noAutorizado=${(e2 as ApiException?)?.noAutorizado} ($ms2 ms)',
        ms, ok);
  });

  test('RES-06 recuperación de la conexión', () async {
    await modo('apagado:3000');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final a = api.reintentosRealizados;
    final (ms, e) = await cronometrar(() => tienda.productos());
    var manuales = 0;
    var ultimo = e;
    final sw = Stopwatch()..start();
    while (ultimo != null && sw.elapsed.inSeconds < 15) {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      manuales++;
      (_, ultimo) = await cronometrar(() => tienda.productos());
    }
    final auto = api.reintentosRealizados - a;
    registrar('RES-06', 'Recuperación de conexión', 'Restablecer comunicación',
        e == null
            ? 'recuperación AUTOMÁTICA en $ms ms con $auto reintento(s) con backoff, sin intervención del usuario'
            : 'primer intento: ${describir(e)} ($ms ms, $auto reintentos automáticos) · luego $manuales reintento(s) manual(es)',
        ms + sw.elapsedMilliseconds, ultimo == null, {'reintento_automatico': true, 'reintentos_automaticos': auto, 'intentos_manuales': manuales});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('RES-07 reintento de una escritura cuya respuesta se perdió', () async {
    final antes = await comprasEnServidor();
    await modo('cortar-despues');
    final llave = nuevaLlaveIdempotencia();
    // La 1.ª respuesta se pierde y el cliente reintenta solo; el proxy deja pasar el reintento.
    final cambio = Future<void>.delayed(const Duration(milliseconds: 150), () => modo('normal'));
    final a = api.reintentosRealizados;
    final (ms, e) = await cronometrar(() => tienda.comprar(items: items(), direccion: direccion, idempotencyKey: llave));
    await cambio;
    // Y si además el usuario pulsa otra vez CONFIRMAR (misma pantalla = misma llave):
    final (_, e2) = await cronometrar(() => tienda.comprar(items: items(), direccion: direccion, idempotencyKey: llave));
    final nuevas = await comprasNuevas(antes);
    registrar('RES-07', 'Reintento de una escritura', 'Evitar duplicados inesperados',
        '1.er envío: ${describir(e)} (reintentos automáticos: ${api.reintentosRealizados - a}) · 2.º envío manual: ${describir(e2)} · compras creadas: $nuevas',
        ms, nuevas == 1, {'compras_nuevas': nuevas});
  });

  test('RES-08 respuesta tardía con doble envío', () async {
    final antes = await comprasEnServidor();
    await modo('lento:2500');
    final llave = nuevaLlaveIdempotencia();
    final sw = Stopwatch()..start();
    final r = await Future.wait([
      cronometrar(() => tienda.comprar(items: items(), direccion: direccion, idempotencyKey: llave)),
      cronometrar(() => tienda.comprar(items: items(), direccion: direccion, idempotencyKey: llave)),
    ]);
    await modo('normal');
    final nuevas = await comprasNuevas(antes);
    registrar('RES-08', 'Respuesta tardía', 'Evitar operaciones duplicadas o inconsistentes',
        'dos envíos con la misma llave durante la espera → compras creadas: $nuevas (${r.map((x) => describir(x.$2)).join(' / ')}). '
        'Además la UI deshabilita el botón mientras espera (_pagando).',
        sw.elapsedMilliseconds, nuevas == 1, {'compras_nuevas': nuevas});
  });

  test('sanidad: helper de reintentos', () => expect(reintentos(() {}), 0));
}
