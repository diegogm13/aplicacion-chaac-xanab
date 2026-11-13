import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Error de la API con un mensaje listo para mostrarse al usuario.
class ApiException implements Exception {
  final String mensaje;
  final int? status;
  final Map<String, dynamic>? cuerpo;

  /// La petición no obtuvo respuesta a tiempo: el servidor PUDO haberla procesado.
  final bool porTimeout;
  ApiException(this.mensaje, {this.status, this.cuerpo, this.porTimeout = false});

  bool get noAutorizado => status == 401;

  @override
  String toString() => mensaje;
}

/// Llave de idempotencia (128 bits aleatorios en hexadecimal). Se genera UNA vez
/// por intento de compra y se reenvía en cada reintento (Práctica 12).
String nuevaLlaveIdempotencia() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Cliente HTTP compartido: agrega el JWT, traduce los errores de NestJS y, desde
/// la Práctica 12, reintenta de forma controlada las peticiones seguras de repetir.
///
/// Política de reintentos (exponential backoff con jitter):
///  - Sólo GET y POST con llave de idempotencia (repetirlos no duplica nada).
///  - Sólo ante fallas de conexión (sin respuesta del servidor) o 502/503/504.
///  - Máximo [maxReintentos]; espera base·2^intento + azar(0…base/2): ~0.5 s y ~1 s.
///  - Un timeout NO se reintenta automáticamente: el servidor pudo haber procesado
///    la operación; se informa al usuario y, si reintenta, la llave evita duplicados.
class ApiClient {
  ApiClient._([http.Client? cliente, Duration? esperaBase])
      : _http = cliente ?? http.Client(),
        esperaBase = esperaBase ?? const Duration(milliseconds: 500);
  static final instancia = ApiClient._();

  /// Cliente aislado para pruebas unitarias (Práctica 11). Sin espera entre reintentos.
  @visibleForTesting
  factory ApiClient.conCliente(http.Client cliente, {Duration esperaBase = Duration.zero}) =>
      ApiClient._(cliente, esperaBase);

  static const int maxReintentos = 2;
  static const _reintentables = {502, 503, 504};

  http.Client _http;
  String? token;

  /// Espera base del backoff; las pruebas la pueden poner en cero.
  Duration esperaBase;

  /// Reintentos automáticos realizados (para métricas de resiliencia).
  int reintentosRealizados = 0;

  final _azar = Random();

  /// Permite que las pruebas sustituyan el transporte HTTP del singleton.
  @visibleForTesting
  set cliente(http.Client c) => _http = c;

  Map<String, String> _headers([String? idempotencyKey]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'Idempotency-Key': ?idempotencyKey,
      };

  Uri _uri(String ruta, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$ruta').replace(queryParameters: query);

  Future<dynamic> get(String ruta, {Map<String, String>? query}) =>
      _enviar(() => _http.get(_uri(ruta, query), headers: _headers()), reintentable: true);

  Future<dynamic> post(String ruta, Object? body, {String? idempotencyKey}) => _enviar(
        () => _http.post(_uri(ruta), headers: _headers(idempotencyKey), body: jsonEncode(body)),
        reintentable: idempotencyKey != null,
      );

  Future<dynamic> put(String ruta, Object? body) =>
      _enviar(() => _http.put(_uri(ruta), headers: _headers(), body: jsonEncode(body)), reintentable: false);

  Future<void> _esperar(int intento) {
    final base = esperaBase.inMilliseconds;
    final ms = base * pow(2, intento).toInt() + (base == 0 ? 0 : _azar.nextInt(base ~/ 2 + 1));
    reintentosRealizados++;
    return Future<void>.delayed(Duration(milliseconds: ms));
  }

  Future<dynamic> _enviar(Future<http.Response> Function() peticion, {required bool reintentable}) async {
    for (var intento = 0;; intento++) {
      final http.Response r;
      try {
        r = await peticion().timeout(ApiConfig.timeout);
      } on TimeoutException {
        throw ApiException('El servidor tardó demasiado en responder. Revisa tu conexión e intenta de nuevo.',
            porTimeout: true);
      } catch (_) {
        if (reintentable && intento < maxReintentos) {
          await _esperar(intento);
          continue;
        }
        throw ApiException('No fue posible conectar con la tienda. Revisa tu conexión a internet.');
      }

      if (reintentable && intento < maxReintentos && _reintentables.contains(r.statusCode)) {
        await _esperar(intento);
        continue;
      }

      final texto = utf8.decode(r.bodyBytes);
      final dynamic datos = texto.isEmpty ? null : _jsonSeguro(texto);

      if (r.statusCode >= 200 && r.statusCode < 300) return datos;

      final mapa = datos is Map<String, dynamic> ? datos : null;
      throw ApiException(_mensajeDe(mapa, r.statusCode), status: r.statusCode, cuerpo: mapa);
    }
  }

  dynamic _jsonSeguro(String texto) {
    try {
      return jsonDecode(texto);
    } catch (_) {
      return null;
    }
  }

  String _mensajeDe(Map<String, dynamic>? cuerpo, int status) {
    final m = cuerpo?['message'];
    if (m is List && m.isNotEmpty) return m.first.toString();
    if (m is String && m.isNotEmpty) return m;
    if (status == 401) return 'Tu sesión expiró. Inicia sesión de nuevo.';
    return 'Ocurrió un error ($status). Intenta de nuevo.';
  }
}
