// Práctica 12 — Resiliencia de la app ORIGINAL (antes de optimizar).
//   node practica12/scripts/servidor_fallas.mjs --puerto 3100 --destino http://localhost:3001
//   flutter test test_resiliencia/res_antes_test.dart --dart-define=API_URL=http://localhost:3100/api
import 'package:chaac_xanab_app/services/api_client.dart';
import 'package:chaac_xanab_app/services/tienda_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'comun.dart';

void main() {
  final tienda = TiendaService();
  setUpAll(preparar);
  tearDown(() => modo('normal'));
  tearDownAll(() => guardar('practica12/resultados/resiliencia/res_antes.json'));

  test('RES-01 pérdida de red durante una consulta', () async {
    await modo('reset');
    final (ms, e) = await cronometrar(() => tienda.productos());
    registrar('RES-01', 'Pérdida de Internet durante una consulta', 'Error controlado', describir(e), ms,
        e is ApiException && e.status == null);
  });

  test('RES-02 pérdida de red durante una escritura', () async {
    final antes = await comprasEnServidor();
    await modo('reset');
    final (ms, e) = await cronometrar(() => tienda.comprar(items: items(), direccion: direccion));
    await modo('normal');
    final nuevasRes02 = await comprasNuevas(antes);
    registrar('RES-02', 'Pérdida de Internet durante una escritura', 'No confirmar falsamente el registro',
        '${describir(e)} · compras nuevas en servidor: $nuevasRes02', ms, e is ApiException && nuevasRes02 == 0,
        {'compras_nuevas': nuevasRes02});
  });

  test('RES-03 servidor sin respuesta', () async {
    await modo('colgado');
    final (ms, e) = await cronometrar(() => tienda.productos());
    registrar('RES-03', 'Servidor sin respuesta', 'Timeout controlado', describir(e), ms, e is ApiException);
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
    final (ms, e) = await cronometrar(() => tienda.misCompras());
    await modo('403');
    final (ms2, e2) = await cronometrar(() => tienda.misCompras());
    final ok = e is ApiException && e.noAutorizado && e2 is ApiException && !e2.noAutorizado && e2.status == 403;
    registrar('RES-05', 'Respuesta HTTP 401 o 403', 'Gestionar autenticación o permisos',
        '401 → noAutorizado=${(e as ApiException?)?.noAutorizado} (cierra sesión) · 403 → noAutorizado=${(e2 as ApiException?)?.noAutorizado} ($ms2 ms)',
        ms, ok);
  });

  test('RES-06 recuperación de la conexión', () async {
    await modo('apagado:3000');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final (ms, e) = await cronometrar(() => tienda.productos());
    // La app original no reintenta: el usuario tiene que pulsar "Reintentar".
    final sw = Stopwatch()..start();
    var intentos = 0;
    Object? ultimo = e;
    while (ultimo != null && sw.elapsed.inSeconds < 15) {
      await Future<void>.delayed(const Duration(milliseconds: 1000)); // reintento manual cada segundo
      intentos++;
      (_, ultimo) = await cronometrar(() => tienda.productos());
    }
    registrar('RES-06', 'Recuperación de conexión', 'Restablecer comunicación',
        'primer intento: ${describir(e)} ($ms ms) · sin reintento automático; recuperó con $intentos reintento(s) MANUAL(es) a los ${sw.elapsedMilliseconds} ms',
        sw.elapsedMilliseconds, ultimo == null, {'reintento_automatico': false, 'intentos_manuales': intentos});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('RES-07 reintento de una escritura cuya respuesta se perdió', () async {
    final antes = await comprasEnServidor();
    await modo('cortar-despues');
    final (ms, e) = await cronometrar(() => tienda.comprar(items: items(), direccion: direccion));
    await modo('normal');
    final (_, e2) = await cronometrar(() => tienda.comprar(items: items(), direccion: direccion)); // el usuario reintenta
    final nuevas = await comprasNuevas(antes);
    registrar('RES-07', 'Reintento de una escritura', 'Evitar duplicados inesperados',
        '1.er intento: ${describir(e)} · reintento: ${describir(e2)} · compras creadas: $nuevas', ms, nuevas == 1,
        {'compras_nuevas': nuevas});
  });

  test('RES-08 respuesta tardía con doble envío', () async {
    final antes = await comprasEnServidor();
    await modo('lento:2500');
    final sw = Stopwatch()..start();
    // Doble toque: dos envíos de la MISMA compra mientras la primera respuesta tarda.
    final r = await Future.wait([
      cronometrar(() => tienda.comprar(items: items(), direccion: direccion)),
      cronometrar(() => tienda.comprar(items: items(), direccion: direccion)),
    ]);
    await modo('normal');
    final nuevas = await comprasNuevas(antes);
    registrar('RES-08', 'Respuesta tardía', 'Evitar operaciones duplicadas o inconsistentes',
        'dos envíos durante la espera → compras creadas: $nuevas (${r.map((x) => describir(x.$2)).join(' / ')}). '
        'En la UI, CheckoutScreen deshabilita el botón mientras espera (_pagando).',
        sw.elapsedMilliseconds, nuevas == 1, {'compras_nuevas': nuevas});
  });
}
