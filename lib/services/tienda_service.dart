import '../models/producto.dart';
import '../models/tienda.dart';
import 'api_client.dart';

/// Endpoints de la tienda (mismos que usa la web en Angular).
class TiendaService {
  final _api = ApiClient.instancia;

  Future<List<Categoria>> categorias() async {
    final datos = await _api.get('/categorias') as List<dynamic>;
    return datos.map((e) => Categoria.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Producto>> productos() async {
    final datos = await _api.get('/productos') as List<dynamic>;
    return datos.map((e) => Producto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Direccion?> miDireccion() async {
    final datos = await _api.get('/auth/me/direccion');
    return datos is Map<String, dynamic> ? Direccion.fromJson(datos) : null;
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
    return Compra.fromJson(datos as Map<String, dynamic>);
  }

  /// Historial paginado (Práctica 12): [limite] compras más recientes que [antes].
  /// Sin parámetros devuelve todo, como antes.
  Future<List<Compra>> misCompras({int? limite, String? antes}) async {
    final query = <String, String>{if (limite != null) 'limite': '$limite', 'antes': ?antes};
    final datos = await _api.get('/compras/mis-compras', query: query.isEmpty ? null : query) as List<dynamic>;
    return datos.map((e) => Compra.fromJson(e as Map<String, dynamic>)).toList();
  }
}
