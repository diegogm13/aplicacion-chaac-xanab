// Práctica 12 — guarda el reporte del profiling (operaciones + frames) en JSON.
// La ruta de salida se toma de la variable de entorno P12_SALIDA.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(responseDataCallback: (data) async {
      final ruta = Platform.environment['P12_SALIDA'] ?? 'practica12/resultados/perfil/perfil.json';
      File(ruta)
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
      stdout.writeln('Reporte de profiling -> $ruta');
    });
