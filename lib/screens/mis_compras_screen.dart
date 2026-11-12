import 'package:flutter/material.dart';

import '../models/tienda.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/tienda_service.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Historial de pedidos (GET /api/compras/mis-compras). Se recarga al abrir la pestaña.
class MisComprasScreen extends StatefulWidget {
  final bool visible;
  const MisComprasScreen({super.key, required this.visible});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  final _servicio = TiendaService();
  List<Compra>? _compras;
  String? _error;
  bool _cargando = false;

  @override
  void didUpdateWidget(MisComprasScreen old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _cargar();
  }

  Future<void> _cargar() async {
    if (!AuthService.instancia.conSesion) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final c = await _servicio.misCompras();
      if (mounted) setState(() => _compras = c);
    } on ApiException catch (e) {
      if (e.noAutorizado) await AuthService.instancia.sesionExpirada();
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: AuthService.instancia,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Mis pedidos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          Expanded(child: _contenido(context)),
        ]),
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    if (!AuthService.instancia.conSesion) {
      return _Vacio(
        icono: Icons.lock_outline,
        titulo: 'Inicia sesión para ver tus pedidos',
        boton: 'INICIAR SESIÓN',
        onBoton: () async {
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginScreen(regresar: true)));
          if (ok == true) _cargar();
        },
      );
    }
    if (_cargando && _compras == null) return const Center(child: CircularProgressIndicator(color: ChaacColors.coral));
    if (_error != null) return _Vacio(icono: Icons.wifi_off_rounded, titulo: _error!, boton: 'REINTENTAR', onBoton: _cargar);
    final compras = _compras ?? [];
    if (compras.isEmpty) {
      return const _Vacio(icono: Icons.receipt_long_outlined, titulo: 'Aún no tienes pedidos');
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      color: ChaacColors.coral,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: compras.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _TarjetaCompra(compra: compras[i]),
      ),
    );
  }
}

class _TarjetaCompra extends StatelessWidget {
  final Compra compra;
  const _TarjetaCompra({required this.compra});

  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  @override
  Widget build(BuildContext context) {
    final c = compra;
    final f = c.fecha;
    final color = switch (c.estado.toLowerCase()) {
      'entregado' || 'completada' || 'completado' => ChaacColors.teal,
      'cancelado' || 'cancelada' => ChaacColors.redDark,
      _ => ChaacColors.coral,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ChaacColors.gray100, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${f.day} ${_meses.elementAt(f.month - 1)} ${f.year}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
            child: Text(c.estado.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: c.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 56, child: ImagenRed(c.items[i].imagenUrl)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...c.items.map((it) => Text('${it.cantidad} × ${it.nombre} · talla ${it.talla}',
            style: const TextStyle(color: Color(0xFF3D3D3D)))),
        const SizedBox(height: 8),
        Row(children: [
          Text('Pedido #${c.id.substring(0, 8).toUpperCase()}', style: const TextStyle(color: ChaacColors.gray400, fontSize: 12)),
          const Spacer(),
          Text(precio(c.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ]),
      ]),
    );
  }
}

class _Vacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? boton;
  final VoidCallback? onBoton;
  const _Vacio({required this.icono, required this.titulo, this.boton, this.onBoton});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icono, size: 56, color: ChaacColors.gray400),
          const SizedBox(height: 16),
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (boton != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onBoton, child: Text(boton!)),
          ],
        ]),
      );
}
