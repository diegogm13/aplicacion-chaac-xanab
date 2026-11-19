import 'package:flutter/material.dart';

import '../config/validaciones.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'registro_screen.dart';

/// Inicio de sesión. Con [regresar] = true solo hace pop al terminar
/// (se usa cuando el invitado intenta pagar).
class LoginScreen extends StatefulWidget {
  final bool regresar;
  const LoginScreen({super.key, this.regresar = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _verPass = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AuthService.instancia.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      _continuar();
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _continuar() {
    if (widget.regresar) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.regresar ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Marca(),
                  const SizedBox(height: 40),
                  const Text('Bienvenido de vuelta', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Inicia sesión para comprar y ver tus pedidos.',
                      style: TextStyle(color: ChaacColors.gray400, fontSize: 15)),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline)),
                    // OBS-02 (P11): antes bastaba con una "@" ("a@" pasaba); ahora es la misma regla del registro.
                    validator: Validaciones.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: !_verPass,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _entrar(),
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _verPass = !_verPass),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ChaacColors.redDark.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: ChaacColors.redDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: ChaacColors.redDark))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _cargando ? null : _entrar,
                    child: _cargando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('INICIAR SESIÓN'),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('¿No tienes cuenta?'),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroScreen())),
                      child: const Text('Regístrate', style: TextStyle(fontWeight: FontWeight.w700, color: ChaacColors.coral)),
                    ),
                  ]),
                  if (!widget.regresar)
                    TextButton(
                      onPressed: _continuar,
                      child: const Text('Explorar como invitado', style: TextStyle(color: ChaacColors.gray400)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(color: ChaacColors.black, borderRadius: BorderRadius.circular(22)),
        child: const Icon(Icons.directions_run, color: ChaacColors.coral, size: 44),
      ),
      const SizedBox(height: 14),
      const Text('CHAAC XANAB', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
      const Text('Zapatos deportivos', style: TextStyle(color: ChaacColors.teal, fontWeight: FontWeight.w600)),
    ]);
  }
}
