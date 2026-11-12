import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/carrito_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // En Windows/Linux/macOS SQLite se usa vía FFI; en Android/iOS es nativo.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ChaacXanabApp());
}

class ChaacXanabApp extends StatelessWidget {
  const ChaacXanabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chaac Xanab',
      debugShowCheckedModeBanner: false,
      theme: chaacTheme(),
      home: const Arranque(),
    );
  }
}

/// Restaura la sesión y el carrito, luego decide si mostrar login o tienda.
class Arranque extends StatefulWidget {
  const Arranque({super.key});

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await Future.wait([AuthService.instancia.restaurar(), CarritoService.instancia.cargar()]);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AuthService.instancia.conSesion ? const HomeShell() : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ChaacColors.black,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.directions_run, color: ChaacColors.coral, size: 64),
          SizedBox(height: 12),
          Text('CHAAC XANAB', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
        ]),
      ),
    );
  }
}
