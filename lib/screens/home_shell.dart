import 'package:flutter/material.dart';

import '../services/carrito_service.dart';
import '../theme.dart';
import 'carrito_screen.dart';
import 'mis_compras_screen.dart';
import 'perfil_screen.dart';
import 'tienda_screen.dart';

/// Navegación principal: Tienda · Carrito · Pedidos · Perfil.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const tienda = 0, carrito = 1, pedidos = 2, perfil = 3;

  /// Pestaña activa; otras pantallas la cambian (p. ej. "Ir al carrito").
  static final tab = ValueNotifier<int>(tienda);
  static void irA(int t) => tab.value = t;

  @override
  Widget build(BuildContext context) {
    final cart = CarritoService.instancia;
    return ListenableBuilder(
      listenable: Listenable.merge([tab, cart]),
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: tab.value,
          children: [
            const TiendaScreen(),
            const CarritoScreen(),
            MisComprasScreen(visible: tab.value == pedidos),
            const PerfilScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.value,
          onDestinationSelected: irA,
          backgroundColor: Colors.white,
          indicatorColor: ChaacColors.coral.withValues(alpha: .15),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Tienda'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: cart.piezas > 0,
                label: Text('${cart.piezas}'),
                backgroundColor: ChaacColors.coral,
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_bag),
              label: 'Carrito',
            ),
            const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
