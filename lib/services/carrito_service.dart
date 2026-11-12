import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../models/producto.dart';

class ItemCarrito {
  final int id;
  final String productoId;
  final String nombre;
  final double precio;
  final String imagenUrl;
  final String talla;
  final int cantidad;
  final int stock;

  ItemCarrito.fromMap(Map<String, Object?> m)
      : id = m['id'] as int,
        productoId = m['producto_id'] as String,
        nombre = m['nombre'] as String,
        precio = (m['precio'] as num).toDouble(),
        imagenUrl = m['imagen_url'] as String,
        talla = m['talla'] as String,
        cantidad = m['cantidad'] as int,
        stock = m['stock'] as int;

  double get subtotal => precio * cantidad;
}

/// Carrito guardado en SQLite: no se pierde al cerrar la app.
class CarritoService extends ChangeNotifier {
  CarritoService._();
  static final instancia = CarritoService._();

  List<ItemCarrito> items = [];

  int get piezas => items.fold(0, (s, i) => s + i.cantidad);
  double get total => items.fold(0, (s, i) => s + i.subtotal);
  bool get vacio => items.isEmpty;

  Future<void> cargar() async {
    final db = await AppDatabase.instancia;
    items = (await db.query('carrito', orderBy: 'id')).map(ItemCarrito.fromMap).toList();
    notifyListeners();
  }

  Future<void> agregar(Producto p, String talla, int cantidad) async {
    final db = await AppDatabase.instancia;
    final existente = await db.query('carrito',
        where: 'producto_id = ? AND talla = ?', whereArgs: [p.id, talla], limit: 1);
    if (existente.isEmpty) {
      await db.insert('carrito', {
        'producto_id': p.id,
        'nombre': p.nombre,
        'precio': p.precio,
        'imagen_url': p.imagenUrl,
        'talla': talla,
        'cantidad': cantidad.clamp(1, p.stock),
        'stock': p.stock,
      });
    } else {
      final nueva = ((existente.first['cantidad'] as int) + cantidad).clamp(1, p.stock);
      await db.update('carrito', {'cantidad': nueva, 'stock': p.stock},
          where: 'id = ?', whereArgs: [existente.first['id']]);
    }
    await cargar();
  }

  Future<void> cambiarCantidad(ItemCarrito item, int cantidad) async {
    if (cantidad < 1) return quitar(item);
    final db = await AppDatabase.instancia;
    await db.update('carrito', {'cantidad': cantidad.clamp(1, item.stock)}, where: 'id = ?', whereArgs: [item.id]);
    await cargar();
  }

  Future<void> quitar(ItemCarrito item) async {
    final db = await AppDatabase.instancia;
    await db.delete('carrito', where: 'id = ?', whereArgs: [item.id]);
    await cargar();
  }

  Future<void> vaciar() async {
    final db = await AppDatabase.instancia;
    await db.delete('carrito');
    await cargar();
  }

  /// Formato que espera POST /api/compras.
  List<Map<String, dynamic>> paraCompra() => items
      .map((i) => {'producto_id': i.productoId, 'size': i.talla, 'quantity': i.cantidad})
      .toList();
}
