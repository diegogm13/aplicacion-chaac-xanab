import 'package:flutter/material.dart';

import '../config/validaciones.dart';
import '../models/tienda.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/carrito_service.dart';
import '../services/tienda_service.dart';
import '../theme.dart';
import 'home_shell.dart';

/// Dirección de envío + resumen + confirmar compra (POST /api/compras).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _servicio = TiendaService();
  final _carrito = CarritoService.instancia;

  final _calle = TextEditingController();
  final _numExt = TextEditingController();
  final _numInt = TextEditingController();
  final _colonia = TextEditingController();
  final _ciudad = TextEditingController();
  final _estado = TextEditingController();
  final _cp = TextEditingController();

  bool _cargandoDir = true;
  bool _pagando = false;

  /// Práctica 12: una llave por intento de compra. Si la respuesta se pierde y el
  /// usuario vuelve a pulsar CONFIRMAR, se reenvía la MISMA llave y el servidor
  /// devuelve la compra original en lugar de crear un duplicado.
  final String _llave = nuevaLlaveIdempotencia();

  @override
  void initState() {
    super.initState();
    _precargarDireccion();
  }

  @override
  void dispose() {
    for (final c in [_calle, _numExt, _numInt, _colonia, _ciudad, _estado, _cp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _precargarDireccion() async {
    try {
      final d = await _servicio.miDireccion();
      if (d != null) {
        _calle.text = d.calle;
        _numExt.text = d.numeroExt;
        _numInt.text = d.numeroInt ?? '';
        _colonia.text = d.colonia;
        _ciudad.text = d.ciudad;
        _estado.text = d.estado;
        _cp.text = d.codigoPostal;
      }
    } catch (_) {
      // Sin dirección guardada: el usuario la escribe.
    }
    if (mounted) setState(() => _cargandoDir = false);
  }

  Future<void> _confirmar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _pagando = true);
    try {
      final compra = await _servicio.comprar(
        items: _carrito.paraCompra(),
        direccion: Direccion(
          calle: _calle.text.trim(),
          numeroExt: _numExt.text.trim(),
          numeroInt: _numInt.text.trim(),
          colonia: _colonia.text.trim(),
          ciudad: _ciudad.text.trim(),
          estado: _estado.text.trim(),
          codigoPostal: _cp.text.trim(),
        ),
        idempotencyKey: _llave,
      );
      await _carrito.vaciar();
      if (!mounted) return;
      await _exito(compra.total);
      if (!mounted) return;
      HomeShell.irA(HomeShell.pedidos);
      Navigator.popUntil(context, (r) => r.isFirst);
    } on ApiException catch (e) {
      if (e.noAutorizado) await AuthService.instancia.sesionExpirada();
      if (mounted) avisar(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  Future<void> _exito(double total) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const CircleAvatar(
          radius: 34,
          backgroundColor: ChaacColors.teal,
          child: Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
        title: const Text('¡Compra realizada!'),
        content: Text('Tu pedido por ${precio(total)} MXN fue registrado. Puedes seguirlo en Pedidos.',
            textAlign: TextAlign.center),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('VER MIS PEDIDOS'))],
      ),
    );
  }

  String? _req(String? v) => Validaciones.requerido(v);

  Widget _campo(TextEditingController c, String label, {String? Function(String?)? validator, TextInputType? tipo}) {
    return TextFormField(
      controller: c,
      keyboardType: tipo,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar compra', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _cargandoDir
          ? const Center(child: CircularProgressIndicator(color: ChaacColors.coral))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const _Titulo(icono: Icons.location_on_outlined, texto: 'Dirección de envío'),
                  const SizedBox(height: 12),
                  _campo(_calle, 'Calle', validator: _req),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _campo(_numExt, 'Núm. exterior', validator: _req)),
                    const SizedBox(width: 10),
                    Expanded(child: _campo(_numInt, 'Núm. interior (opcional)')),
                  ]),
                  const SizedBox(height: 10),
                  _campo(_colonia, 'Colonia', validator: _req),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _campo(_ciudad, 'Ciudad', validator: _req)),
                    const SizedBox(width: 10),
                    Expanded(child: _campo(_estado, 'Estado', validator: _req)),
                  ]),
                  const SizedBox(height: 10),
                  _campo(_cp, 'Código postal',
                      tipo: TextInputType.number,
                      validator: Validaciones.codigoPostal),
                  const SizedBox(height: 28),
                  const _Titulo(icono: Icons.receipt_outlined, texto: 'Resumen'),
                  const SizedBox(height: 8),
                  ..._carrito.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(width: 48, height: 48, child: ImagenRed(it.imagenUrl)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('${it.nombre}\nTalla ${it.talla} · ${it.cantidad} pz',
                                style: const TextStyle(height: 1.3)),
                          ),
                          Text(precio(it.subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                      )),
                  const Divider(height: 28),
                  Row(children: [
                    const Text('Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text('${precio(_carrito.total)} MXN', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ]),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ChaacColors.coral),
            onPressed: _pagando || _cargandoDir ? null : _confirmar,
            child: _pagando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text('CONFIRMAR COMPRA · ${precio(_carrito.total)}'),
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Titulo({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icono, color: ChaacColors.teal),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]);
}
