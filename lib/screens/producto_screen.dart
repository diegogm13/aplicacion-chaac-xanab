import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../services/carrito_service.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'tienda_screen.dart';

/// Detalle: imagen grande, tallas, cantidad y "Agregar al carrito".
class ProductoScreen extends StatefulWidget {
  final Producto producto;
  const ProductoScreen({super.key, required this.producto});

  @override
  State<ProductoScreen> createState() => _ProductoScreenState();
}

class _ProductoScreenState extends State<ProductoScreen> {
  String? _talla;
  int _cantidad = 1;
  bool _agregando = false;

  Producto get p => widget.producto;

  Future<void> _agregar() async {
    if (_talla == null) {
      avisar(context, 'Elige tu talla primero', error: true);
      return;
    }
    setState(() => _agregando = true);
    await CarritoService.instancia.agregar(p, _talla!, _cantidad);
    if (!mounted) return;
    setState(() => _agregando = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${p.nombre} (talla $_talla) agregado al carrito'),
        backgroundColor: ChaacColors.black,
        action: SnackBarAction(
          label: 'VER CARRITO',
          textColor: ChaacColors.coral,
          onPressed: () {
            HomeShell.irA(HomeShell.carrito);
            Navigator.popUntil(context, (r) => r.isFirst);
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: ChaacColors.gray100,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(tag: 'img-${p.id}', child: ImagenRed(p.imagenUrl)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (p.categoria != null)
                    Text(p.categoria!.toUpperCase(),
                        style: const TextStyle(color: ChaacColors.teal, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const Spacer(),
                  if (p.badge != null) EtiquetaBadge(badge: p.badge!),
                ]),
                const SizedBox(height: 6),
                Text(p.nombre, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(precio(p.precio), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('MXN', style: TextStyle(color: ChaacColors.gray400))),
                  if (p.enOferta) ...[
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(precio(p.precioOriginal!),
                          style: const TextStyle(color: ChaacColors.gray400, decoration: TextDecoration.lineThrough)),
                    ),
                  ],
                ]),
                const SizedBox(height: 16),
                Text(p.descripcion, style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF3D3D3D))),
                const SizedBox(height: 24),
                Row(children: [
                  const Text('Talla (MX)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const Spacer(),
                  Text(p.agotado ? 'Agotado' : '${p.stock} disponibles',
                      style: TextStyle(color: p.agotado ? ChaacColors.redDark : ChaacColors.gray400)),
                ]),
                const SizedBox(height: 12),
                if (p.tallas.isEmpty)
                  const Text('Sin tallas registradas', style: TextStyle(color: ChaacColors.gray400))
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: p.tallas.map((t) {
                      final sel = _talla == t;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: p.agotado ? null : () => setState(() => _talla = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 62,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? ChaacColors.black : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: sel ? ChaacColors.black : const Color(0xFFDDDDDD)),
                          ),
                          child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.black)),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),
                Row(children: [
                  const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const Spacer(),
                  SelectorCantidad(
                    valor: _cantidad,
                    max: p.stock,
                    onCambio: (v) => setState(() => _cantidad = v),
                  ),
                ]),
                const SizedBox(height: 8),
                const Row(children: [
                  Icon(Icons.local_shipping_outlined, size: 18, color: ChaacColors.teal),
                  SizedBox(width: 6),
                  Text('Envío a todo México', style: TextStyle(color: ChaacColors.teal)),
                ]),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: p.agotado || _agregando ? null : _agregar,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(p.agotado ? 'AGOTADO' : 'AGREGAR AL CARRITO · ${precio(p.precio * _cantidad)}'),
          ),
        ),
      ),
    );
  }
}

class SelectorCantidad extends StatelessWidget {
  final int valor;
  final int max;
  final ValueChanged<int> onCambio;
  final int min;
  const SelectorCantidad({super.key, required this.valor, required this.max, required this.onCambio, this.min = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ChaacColors.gray100, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(valor <= 1 && min == 0 ? Icons.delete_outline : Icons.remove),
          onPressed: valor > min ? () => onCambio(valor - 1) : null,
        ),
        SizedBox(width: 24, child: Text('$valor', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add),
          onPressed: valor < max ? () => onCambio(valor + 1) : null,
        ),
      ]),
    );
  }
}
