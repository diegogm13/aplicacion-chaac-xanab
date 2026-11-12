import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Error de la API con un mensaje listo para mostrarse al usuario.
class ApiException implements Exception {
  final String mensaje;
  final int? status;
  final Map<String, dynamic>? cuerpo;
  ApiException(this.mensaje, {this.status, this.cuerpo});

  bool get noAutorizado => status == 401;

  @override
  String toString() => mensaje;
}

/// Cliente HTTP compartido: agrega el JWT y traduce los errores de NestJS.
class ApiClient {
  ApiClient._([http.Client? cliente]) : _http = cliente ?? http.Client();
  static final instancia = ApiClient._();

  /// Cliente aislado para pruebas unitarias (Práctica 11).
  @visibleForTesting
  factory ApiClient.conCliente(http.Client cliente) => ApiClient._(cliente);

  http.Client _http;
  String? token;

  /// Permite que las pruebas sustituyan el transporte HTTP del singleton.
  @visibleForTesting
  set cliente(http.Client c) => _http = c;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String ruta, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$ruta').replace(queryParameters: query);

  Future<dynamic> get(String ruta, {Map<String, String>? query}) =>
      _enviar(() => _http.get(_uri(ruta, query), headers: _headers));

  Future<dynamic> post(String ruta, Object? body) =>
      _enviar(() => _http.post(_uri(ruta), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> put(String ruta, Object? body) =>
      _enviar(() => _http.put(_uri(ruta), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> _enviar(Future<http.Response> Function() peticion) async {
    final http.Response r;
    try {
      r = await peticion().timeout(ApiConfig.timeout);
    } catch (_) {
      throw ApiException('No fue posible conectar con la tienda. Revisa tu conexión a internet.');
    }

    final texto = utf8.decode(r.bodyBytes);
    final dynamic datos = texto.isEmpty ? null : _jsonSeguro(texto);

    if (r.statusCode >= 200 && r.statusCode < 300) return datos;

    final mapa = datos is Map<String, dynamic> ? datos : null;
    throw ApiException(_mensajeDe(mapa, r.statusCode), status: r.statusCode, cuerpo: mapa);
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
