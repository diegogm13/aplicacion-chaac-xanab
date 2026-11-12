import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/carrito_service.dart';
import '../theme.dart';
import 'checkout_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'producto_screen.dart';

class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  Future<void> _pagar(BuildContext context) async {
    if (!AuthService.instancia.conSesion) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(regresar: true)),
      );
      if (ok != true || !context.mounted) return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final carrito = CarritoService.instancia;
    return SafeArea(
      child: ListenableBuilder(
        listenable: carrito,
        builder: (context, _) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(children: [
                const Expanded(child: Text('Mi carrito', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
                if (!carrito.vacio)
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Vaciar carrito?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vaciar')),
                          ],
                        ),
                      );
                      if (ok == true) carrito.vaciar();
                    },
                    child: const Text('Vaciar', style: TextStyle(color: ChaacColors.redDark)),
                  ),
              ]),
            ),
            if (carrito.vacio)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: const BoxDecoration(color: ChaacColors.gray100, shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_bag_outlined, size: 56, color: ChaacColors.gray400),
                    ),
                    const SizedBox(height: 20),
                    const Text('Tu carrito está vacío', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('Agrega tus zapatos favoritos y aparecerán aquí.',
                        textAlign: TextAlign.center, style: TextStyle(color: ChaacColors.gray400)),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () => HomeShell.irA(HomeShell.tienda), child: const Text('IR A LA TIENDA')),
                  ]),
                ),
              )
            else ...[
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  itemCount: carrito.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (_, i) {
                    final it = carrito.items[i];
                    return Dismissible(
                      key: ValueKey(it.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: ChaacColors.redDark, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => carrito.quitar(it),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(width: 92, height: 92, child: ImagenRed(it.imagenUrl)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(it.nombre, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('Talla ${it.talla}', style: const TextStyle(color: ChaacColors.gray400)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: Text(precio(it.subtotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                              SelectorCantidad(
                                valor: it.cantidad,
                                max: it.stock,
                                min: 0,
                                onCambio: (v) => carrito.cambiarCantidad(it, v),
                              ),
                            ]),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
                ),
                child: Column(children: [
                  _fila('Productos (${carrito.piezas})', precio(carrito.total)),
                  const SizedBox(height: 4),
                  _fila('Envío', 'Gratis', color: ChaacColors.teal),
                  const Divider(height: 20),
                  _fila('Total', precio(carrito.total), grande: true),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: () => _pagar(context), child: const Text('CONTINUAR AL PAGO')),
                ]),
              ),
            ],
          ]);
        },
      ),
    );
  }

  Widget _fila(String a, String b, {bool grande = false, Color? color}) {
    final estilo = TextStyle(fontSize: grande ? 20 : 15, fontWeight: grande ? FontWeight.w900 : FontWeight.w500);
    return Row(children: [
      Text(a, style: estilo.copyWith(color: grande ? null : ChaacColors.gray400)),
      const Spacer(),
      Text(b, style: estilo.copyWith(color: color)),
    ]);
  }
}
