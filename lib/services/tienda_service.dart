import '../models/producto.dart';
import '../models/tienda.dart';
import 'api_client.dart';

/// Endpoints de la tienda (mismos que usa la web en Angular).
class TiendaService {
  final _api = ApiClient.instancia;

  /// DEF-10 (Práctica 11): si el servidor responde 200 con una forma inesperada
  /// (p. ej. {"message":"mantenimiento"} en vez de una lista), los casts lanzaban
  /// TypeError, que ninguna pantalla atrapaba. Ahora se convierte en ApiException,
  /// que todas las pantallas ya muestran con su botón de reintentar.
  T _interpretar<T>(Object? datos, T Function(Object? d) convertir) {
    try {
      return convertir(datos);
    } on TypeError {
      throw ApiException('Recibimos una respuesta inesperada del servidor. Intenta de nuevo en un momento.');
    }
  }

  List<T> _lista<T>(Object? datos, T Function(Map<String, dynamic> j) desde) =>
      _interpretar(datos, (d) => (d as List<dynamic>).map((e) => desde(e as Map<String, dynamic>)).toList());

  Future<List<Categoria>> categorias() async => _lista(await _api.get('/categorias'), Categoria.fromJson);

  Future<List<Producto>> productos() async => _lista(await _api.get('/productos'), Producto.fromJson);

  Future<Direccion?> miDireccion() async {
    final datos = await _api.get('/auth/me/direccion');
    return datos is Map<String, dynamic> ? _interpretar(datos, (_) => Direccion.fromJson(datos)) : null;
  }

  /// POST /api/compras — el backend valida stock y calcula el total en una transacción.
  /// [idempotencyKey] (Práctica 12): la misma llave en un reintento devuelve la compra
  /// original en vez de crear otra; además habilita el reintento automático del ApiClient.
  Future<Compra> comprar({
    required List<Map<String, dynamic>> items,
    required Direccion direccion,
    String? idempotencyKey,
  }) async {
    final datos = await _api.post('/compras', {'items': items, 'direccion': direccion.toJson()},
        idempotencyKey: idempotencyKey);
    return _interpretar(datos, (d) => Compra.fromJson(d as Map<String, dynamic>));
  }

  /// Historial paginado (Práctica 12): [limite] compras más recientes que [antes].
  /// Sin parámetros devuelve todo, como antes.
  Future<List<Compra>> misCompras({int? limite, String? antes}) async {
    final query = <String, String>{if (limite != null) 'limite': '$limite', 'antes': ?antes};
    return _lista(await _api.get('/compras/mis-compras', query: query.isEmpty ? null : query), Compra.fromJson);
  }
}
