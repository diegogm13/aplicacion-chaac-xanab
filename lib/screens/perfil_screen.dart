import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'consulta_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'usuarios_screen.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instancia;
    return SafeArea(
      child: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          final u = auth.usuario;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            const Text('Perfil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: ChaacColors.black, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: ChaacColors.coral,
                  child: Text(u == null ? '?' : u.nombre.characters.first.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u?.nombre ?? 'Invitado',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(u?.email ?? 'Inicia sesión para comprar',
                        style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            if (u == null)
              FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen(regresar: true))),
                child: const Text('INICIAR SESIÓN'),
              )
            else ...[
              _Opcion(
                icono: Icons.receipt_long_outlined,
                texto: 'Mis pedidos',
                onTap: () => HomeShell.irA(HomeShell.pedidos),
              ),
              _Opcion(
                icono: Icons.shopping_bag_outlined,
                texto: 'Mi carrito',
                onTap: () => HomeShell.irA(HomeShell.carrito),
              ),
            ],
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 0, 6),
              child: Text('PRÁCTICAS DE LABORATORIO',
                  style: TextStyle(color: ChaacColors.gray400, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
            _Opcion(
              icono: Icons.cloud_download_outlined,
              texto: 'Práctica 3 · Consulta de información',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _Practica(titulo: 'ConsultaWeb', child: ConsultaScreen()))),
            ),
            _Opcion(
              icono: Icons.storage_outlined,
              texto: 'Práctica 4 · Usuarios en SQLite',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _Practica(titulo: 'Almacenamiento', child: UsuariosScreen()))),
            ),
            if (u != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ChaacColors.redDark,
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: ChaacColors.redDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  await auth.logout();
                  if (!context.mounted) return;
                  HomeShell.irA(HomeShell.tienda);
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  const _Opcion({required this.icono, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: ChaacColors.gray100,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: Icon(icono, color: ChaacColors.teal),
          title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _Practica extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Practica({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800))),
        backgroundColor: ChaacColors.gray100,
        body: child,
      );
}
