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

  /// POST /api/compras — el backend valida stock y calcula el total.
  Future<Compra> comprar({
    required List<Map<String, dynamic>> items,
    required Direccion direccion,
  }) async {
    final datos = await _api.post('/compras', {'items': items, 'direccion': direccion.toJson()});
    return Compra.fromJson(datos as Map<String, dynamic>);
  }

  Future<List<Compra>> misCompras() async {
    final datos = await _api.get('/compras/mis-compras') as List<dynamic>;
    return datos.map((e) => Compra.fromJson(e as Map<String, dynamic>)).toList();
  }
}
