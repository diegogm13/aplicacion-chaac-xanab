import 'package:chaac_xanab_app/models/producto.dart';
import 'package:chaac_xanab_app/models/usuario.dart';
import 'package:chaac_xanab_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Producto.fromJson procesa la respuesta de /api/productos', () {
    final p = Producto.fromJson({
      'id': 'abc',
      'name': 'Nike Pegasus 40',
      'description': 'Amortiguación Air Zoom',
      'price': 2999,
      'original_price': null,
      'stock': 21,
      'image_url': 'https://x/y.jpg',
      'sizes': ['26', 27],
      'badge': 'popular',
      'categorias': {'id': '1', 'name': 'Running', 'slug': 'running'},
    });
    expect(p.nombre, 'Nike Pegasus 40');
    expect(p.precio, 2999.0);
    expect(p.categoria, 'Running');
    expect(p.tallas, ['26', '27']);
  });

  test('ApiService lanza ConsultaException si el servidor falla', () async {
    final api = ApiService(client: MockClient((_) async => http.Response('boom', 500)));
    expect(api.obtenerProductos(), throwsA(isA<ConsultaException>()));
  });

  test('Usuario conserva el correo al pasar por la tabla', () {
    const u = Usuario(nombre: 'Ana', edad: 21, profesion: 'ISC', correo: 'ana@mail.com');
    final copia = Usuario.fromMap({...u.toMap(), 'id': 1});
    expect(copia.correo, 'ana@mail.com');
    expect(copia.id, 1);
  });
}
