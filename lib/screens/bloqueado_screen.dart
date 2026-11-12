import 'package:flutter/material.dart';

import '../config/funciones.dart';
import '../theme.dart';
import 'home_shell.dart';

/// Pantalla que ocupa el lugar de una función aún no liberada.
class BloqueadoScreen extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  const BloqueadoScreen({super.key, required this.titulo, required this.descripcion, required this.icono});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(color: ChaacColors.gray100, shape: BoxShape.circle),
                  child: Icon(icono, size: 56, color: ChaacColors.gray400),
                ),
                const Positioned(
                  right: -4,
                  bottom: -4,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: ChaacColors.black,
                    child: Icon(Icons.lock, color: Colors.white, size: 20),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              const Text('Muy pronto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(descripcion, textAlign: TextAlign.center, style: const TextStyle(color: ChaacColors.gray400, fontSize: 15)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ChaacColors.coral.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Disponible en el ${Funciones.parcialCompras}'.toUpperCase(),
                    style: const TextStyle(color: ChaacColors.coral, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(height: 28),
              FilledButton(onPressed: () => HomeShell.irA(HomeShell.tienda), child: const Text('SEGUIR EXPLORANDO')),
            ]),
          ),
        ),
      ]),
    );
  }
}
