import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../models/tienda.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/tienda_service.dart';
import '../theme.dart';
import 'producto_screen.dart';

/// Pantalla principal: saludo, buscador, categorías y cuadrícula de zapatos.
class TiendaScreen extends StatefulWidget {
  const TiendaScreen({super.key});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  final _servicio = TiendaService();
  final _buscar = TextEditingController();

  List<Categoria> _categorias = [];
  List<Producto> _productos = [];
  bool _cargando = true;
  String? _error;

  String? _slug; // null = todas
  String _orden = 'recientes';

  @override
  void initState() {
    super.initState();
    _buscar.addListener(() => setState(() {}));
    _cargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait([_servicio.categorias(), _servicio.productos()]);
      if (!mounted) return;
      setState(() {
        _categorias = r[0] as List<Categoria>;
        _productos = r[1] as List<Producto>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      // DEF-10: cualquier otro error también se muestra con "Reintentar" (antes la tienda quedaba vacía).
      if (mounted) setState(() => _error = 'No pudimos cargar la tienda. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Producto> get _visibles {
    final q = _buscar.text.trim().toLowerCase();
    final lista = _productos.where((p) {
      if (_slug == 'ofertas') {
        if (!(p.enOferta || p.badge == 'sale')) return false;
      } else if (_slug != null && p.categoriaSlug != _slug) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.nombre.toLowerCase().contains(q) ||
          p.descripcion.toLowerCase().contains(q) ||
          (p.categoria ?? '').toLowerCase().contains(q);
    }).toList();
    if (_orden == 'menor') lista.sort((a, b) => a.precio.compareTo(b.precio));
    if (_orden == 'mayor') lista.sort((a, b) => b.precio.compareTo(a.precio));
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: ChaacColors.coral,
        onRefresh: _cargar,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _encabezado()),
            SliverToBoxAdapter(child: _buscador()),
            if (_buscar.text.isEmpty && _slug == null && !_cargando && _error == null)
              SliverToBoxAdapter(child: _banner()),
            SliverToBoxAdapter(child: _chips()),
            ..._cuerpo(),
          ],
        ),
      ),
    );
  }

  Widget _encabezado() {
    return ListenableBuilder(
      listenable: AuthService.instancia,
      builder: (context, _) {
        final u = AuthService.instancia.usuario;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u == null ? 'Hola 👋' : 'Hola, ${u.primerNombre} 👋',
                    style: const TextStyle(color: ChaacColors.gray400, fontSize: 15)),
                const Text('Encuentra tu par ideal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ]),
            ),
            const CircleAvatar(
              radius: 22,
              backgroundColor: ChaacColors.black,
              child: Icon(Icons.directions_run, color: ChaacColors.coral),
            ),
          ]),
        );
      },
    );
  }

  Widget _buscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _buscar,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar zapatos, marcas…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscar.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: _buscar.clear),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'Ordenar',
          initialValue: _orden,
          onSelected: (v) => setState(() => _orden = v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'recientes', child: Text('Más recientes')),
            PopupMenuItem(value: 'menor', child: Text('Precio: menor a mayor')),
            PopupMenuItem(value: 'mayor', child: Text('Precio: mayor a menor')),
          ],
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(color: ChaacColors.black, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _banner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => setState(() => _slug = 'ofertas'),
        child: Container(
          height: 156,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [ChaacColors.teal, Color(0xFF00796B)]),
          ),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('NUEVA TEMPORADA', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Corre más lejos,\npaga menos', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
                SizedBox(height: 8),
                Text('Ver ofertas →', style: TextStyle(color: ChaacColors.coral, fontWeight: FontWeight.w800)),
              ]),
            ),
            Transform.rotate(angle: -.35, child: const Icon(Icons.directions_run, size: 82, color: Colors.white24)),
          ]),
        ),
      ),
    );
  }

  Widget _chips() {
    final opciones = <(String?, String)>[
      (null, 'Todos'),
      ('ofertas', 'Ofertas'),
      ..._categorias.map((c) => (c.slug, c.nombre)),
    ];
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (slug, nombre) = opciones[i];
          final activo = _slug == slug;
          return ChoiceChip(
            label: Text(nombre),
            selected: activo,
            showCheckmark: false,
            onSelected: (_) => setState(() => _slug = slug),
            selectedColor: ChaacColors.black,
            backgroundColor: ChaacColors.gray100,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: TextStyle(color: activo ? Colors.white : ChaacColors.black, fontWeight: FontWeight.w600),
          );
        },
      ),
    );
  }

  List<Widget> _cuerpo() {
    if (_cargando) {
      return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: ChaacColors.coral)))];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: ChaacColors.gray400),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
            ]),
          ),
        ),
      ];
    }
    final lista = _visibles;
    if (lista.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No encontramos zapatos con ese filtro.', style: TextStyle(color: ChaacColors.gray400))),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        sliver: SliverToBoxAdapter(
          child: Text('${lista.length} ${lista.length == 1 ? 'modelo' : 'modelos'}',
              style: const TextStyle(color: ChaacColors.gray400)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: .62,
          ),
          itemCount: lista.length,
          itemBuilder: (_, i) => TarjetaProducto(producto: lista[i]),
        ),
      ),
    ];
  }
}

class TarjetaProducto extends StatelessWidget {
  final Producto producto;
  const TarjetaProducto({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductoScreen(producto: p))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: Hero(
                tag: 'img-${p.id}',
                child: ClipRRect(borderRadius: BorderRadius.circular(18), child: ImagenRed(p.imagenUrl)),
              ),
            ),
            if (p.badge != null || p.agotado)
              Positioned(left: 10, top: 10, child: EtiquetaBadge(badge: p.agotado ? 'agotado' : p.badge!)),
          ]),
        ),
        const SizedBox(height: 10),
        if (p.categoria != null)
          Text(p.categoria!.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: ChaacColors.teal, fontWeight: FontWeight.w700, letterSpacing: .8)),
        Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 2),
        Row(children: [
          Text(precio(p.precio), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (p.enOferta) ...[
            const SizedBox(width: 6),
            Text(precio(p.precioOriginal!),
                style: const TextStyle(fontSize: 12, color: ChaacColors.gray400, decoration: TextDecoration.lineThrough)),
          ],
        ]),
      ]),
    );
  }
}

class EtiquetaBadge extends StatelessWidget {
  final String badge;
  const EtiquetaBadge({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    const textos = {'new': 'NUEVO', 'popular': 'POPULAR', 'sale': 'OFERTA', 'agotado': 'AGOTADO'};
    final color = switch (badge) {
      'new' => ChaacColors.teal,
      'agotado' => ChaacColors.gray400,
      _ => ChaacColors.coral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(textos[badge] ?? badge.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
    );
  }
}
