import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/producto.dart';
import '../services/api_service.dart';
import '../theme.dart';

enum _Estado { inicial, consultando, listo, error }

/// Práctica 3 — ConsultaWeb (extensión del sitio Chaac Xanab).
class ConsultaScreen extends StatefulWidget {
  const ConsultaScreen({super.key});

  @override
  State<ConsultaScreen> createState() => _ConsultaScreenState();
}

class _ConsultaScreenState extends State<ConsultaScreen> {
  final _api = ApiService();
  final _urlCtrl = TextEditingController(text: ApiConfig.productosUrl);

  _Estado _estado = _Estado.inicial;
  List<Producto> _productos = [];
  String _detalleError = '';

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    setState(() => _estado = _Estado.consultando); // RF05
    try {
      final productos = await _api.obtenerProductos(url: _urlCtrl.text.trim()); // RF03
      setState(() {
        _productos = productos;
        _estado = _Estado.listo; // RF04
      });
    } on ConsultaException catch (e) {
      setState(() {
        _detalleError = e.detalle;
        _estado = _Estado.error; // RF06
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text('Consulta de información', // RF01
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Catálogo en vivo de la tienda Chaac Xanab',
              style: TextStyle(color: Colors.grey.shade600)),
        ),
        // Prueba 3 — modificación de la URL
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text('URL preasignada', style: TextStyle(fontSize: 14)),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              TextField(
                controller: _urlCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Restaurar',
                    icon: const Icon(Icons.restore),
                    onPressed: () => _urlCtrl.text = ApiConfig.productosUrl,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: _estado == _Estado.consultando ? null : _consultar,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('CONSULTAR'), // RF02
            style: FilledButton.styleFrom(
              backgroundColor: ChaacColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _contenido()),
      ],
    );
  }

  Widget _contenido() {
    switch (_estado) {
      case _Estado.inicial:
        return const _Mensaje(icono: Icons.touch_app_outlined, texto: 'Presiona CONSULTAR para cargar el catálogo.');
      case _Estado.consultando:
        return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: ChaacColors.teal),
            SizedBox(height: 12),
            Text('Consultando...'),
          ]),
        );
      case _Estado.error:
        return _Mensaje(
          icono: Icons.wifi_off,
          color: ChaacColors.redDark,
          texto: 'No fue posible obtener la información.',
          detalle: _detalleError,
        );
      case _Estado.listo:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: _productos.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => i == 0
              ? Text('${_productos.length} productos recibidos', style: TextStyle(color: Colors.grey.shade600))
              : _ProductoCard(producto: _productos[i - 1]),
        );
    }
  }
}

class _ProductoCard extends StatelessWidget {
  final Producto producto;
  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            p.imagenUrl,
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(width: 104, height: 104, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (p.categoria != null)
                      Text(p.categoria!.toUpperCase(),
                          style: const TextStyle(fontSize: 11, color: ChaacColors.teal, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (p.badge != null) _Badge(p.badge!),
                  ]),
                  const SizedBox(height: 2),
                  Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(p.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('\$${p.precio.toStringAsFixed(0)} MXN', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (p.precioOriginal != null) ...[
                      const SizedBox(width: 6),
                      Text('\$${p.precioOriginal!.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
                    ],
                    const Spacer(),
                    Text('Stock ${p.stock}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String badge;
  const _Badge(this.badge);

  @override
  Widget build(BuildContext context) {
    const etiquetas = {'new': 'NUEVO', 'popular': 'POPULAR', 'sale': 'OFERTA'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: ChaacColors.coral, borderRadius: BorderRadius.circular(4)),
      child: Text(etiquetas[badge] ?? badge.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? detalle;
  final Color? color;
  const _Mensaje({required this.icono, required this.texto, this.detalle, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 48, color: color ?? Colors.grey),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: color)),
          if (detalle != null) ...[
            const SizedBox(height: 6),
            Text(detalle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ]),
      ),
    );
  }
}
