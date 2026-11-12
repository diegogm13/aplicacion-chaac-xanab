/// Modelos de la tienda que vienen del backend.
class Categoria {
  final String id;
  final String slug;
  final String nombre;
  final String? subtitulo;
  final String? imagenUrl;

  Categoria({required this.id, required this.slug, required this.nombre, this.subtitulo, this.imagenUrl});

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
        id: j['id'] as String,
        slug: j['slug'] as String,
        nombre: j['name'] as String? ?? '',
        subtitulo: j['subtitle'] as String?,
        imagenUrl: j['image_url'] as String?,
      );
}

class UsuarioSesion {
  final String id;
  final String nombre;
  final String email;
  final String rol;

  UsuarioSesion({required this.id, required this.nombre, required this.email, required this.rol});

  factory UsuarioSesion.fromJson(Map<String, dynamic> j) => UsuarioSesion(
        id: j['id'] as String,
        nombre: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        rol: j['role'] as String? ?? 'cliente',
      );

  String get primerNombre => nombre.trim().split(' ').first;
}

class Direccion {
  final String calle;
  final String numeroExt;
  final String? numeroInt;
  final String colonia;
  final String ciudad;
  final String estado;
  final String codigoPostal;

  Direccion({
    required this.calle,
    required this.numeroExt,
    this.numeroInt,
    required this.colonia,
    required this.ciudad,
    required this.estado,
    required this.codigoPostal,
  });

  factory Direccion.fromJson(Map<String, dynamic> j) => Direccion(
        calle: j['calle'] as String? ?? '',
        numeroExt: j['numero_ext'] as String? ?? '',
        numeroInt: j['numero_int'] as String?,
        colonia: j['colonia'] as String? ?? '',
        ciudad: j['ciudad'] as String? ?? '',
        estado: j['estado'] as String? ?? '',
        codigoPostal: j['codigo_postal'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'calle': calle,
        'numero_ext': numeroExt,
        if (numeroInt != null && numeroInt!.isNotEmpty) 'numero_int': numeroInt,
        'colonia': colonia,
        'ciudad': ciudad,
        'estado': estado,
        'codigo_postal': codigoPostal,
      };
}

class CompraItem {
  final String nombre;
  final double precio;
  final String talla;
  final int cantidad;
  final String imagenUrl;

  CompraItem({required this.nombre, required this.precio, required this.talla, required this.cantidad, required this.imagenUrl});

  factory CompraItem.fromJson(Map<String, dynamic> j) => CompraItem(
        nombre: j['name'] as String? ?? '',
        precio: (j['price'] as num?)?.toDouble() ?? 0,
        talla: j['size']?.toString() ?? '',
        cantidad: (j['quantity'] as num?)?.toInt() ?? 1,
        imagenUrl: j['image_url'] as String? ?? '',
      );
}

class Compra {
  final String id;
  final double total;
  final String estado;
  final DateTime fecha;
  final List<CompraItem> items;

  Compra({required this.id, required this.total, required this.estado, required this.fecha, required this.items});

  factory Compra.fromJson(Map<String, dynamic> j) => Compra(
        id: j['id'] as String,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        estado: j['status'] as String? ?? 'pendiente',
        fecha: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        items: ((j['compras_items'] ?? j['items']) as List<dynamic>? ?? [])
            .map((e) => CompraItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
