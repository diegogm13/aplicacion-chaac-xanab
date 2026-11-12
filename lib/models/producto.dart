/// Producto tal como lo devuelve GET /api/productos (JSON).
class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final double? precioOriginal;
  final String imagenUrl;
  final int stock;
  final String? badge;
  final String? categoria;
  final String? categoriaSlug;
  final List<String> tallas;

  Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.imagenUrl,
    required this.stock,
    required this.tallas,
    this.precioOriginal,
    this.badge,
    this.categoria,
    this.categoriaSlug,
  });

  bool get enOferta => precioOriginal != null && precioOriginal! > precio;
  bool get agotado => stock <= 0;

  factory Producto.fromJson(Map<String, dynamic> json) {
    final cat = json['categorias'] as Map<String, dynamic>?;
    return Producto(
      id: json['id'] as String,
      nombre: json['name'] as String? ?? '',
      descripcion: json['description'] as String? ?? '',
      precio: (json['price'] as num?)?.toDouble() ?? 0,
      precioOriginal: (json['original_price'] as num?)?.toDouble(),
      imagenUrl: json['image_url'] as String? ?? '',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      badge: json['badge'] as String?,
      categoria: cat?['name'] as String?,
      categoriaSlug: cat?['slug'] as String?,
      tallas: (json['sizes'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
