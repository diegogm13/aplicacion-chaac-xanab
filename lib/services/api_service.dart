import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/producto.dart';

/// Error que la interfaz muestra como "No fue posible obtener la información."
class ConsultaException implements Exception {
  final String detalle;
  ConsultaException(this.detalle);

  @override
  String toString() => detalle;
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// 1. URL preasignada  2. Solicitud HTTP  3. Procesamiento de la respuesta.
  Future<List<Producto>> obtenerProductos({String url = ApiConfig.productosUrl}) async {
    final http.Response respuesta;
    try {
      respuesta = await _client.get(Uri.parse(url)).timeout(ApiConfig.timeout);
    } catch (e) {
      // Sin internet, DNS caído, timeout, URL mal formada...
      throw ConsultaException('Error de conexión: $e');
    }

    if (respuesta.statusCode != 200) {
      throw ConsultaException('El servidor respondió ${respuesta.statusCode}');
    }

    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes)) as List<dynamic>;
      return datos.map((e) => Producto.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ConsultaException('Respuesta con formato inesperado: $e');
    }
  }
}
