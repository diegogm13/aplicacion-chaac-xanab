import 'package:flutter/material.dart';

import '../config/validaciones.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _cargando = false;
  bool _verPass = false;

  @override
  void initState() {
    super.initState();
    _pass.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // Mismas reglas que IsStrongPassword en el backend.
  Map<String, bool> get _reglas => Validaciones.reglasPassword(_pass.text);

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final msg = await AuthService.instancia.registrar(_nombre.text.trim(), _email.text.trim(), _pass.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined, color: ChaacColors.teal, size: 40),
          title: const Text('¡Cuenta creada!'),
          content: Text(msg, textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('IR A INICIAR SESIÓN'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) avisar(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Crea tu cuenta', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Compra más rápido y sigue tus pedidos.', style: TextStyle(color: ChaacColors.gray400, fontSize: 15)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => Validaciones.requerido(v, mensaje: 'Escribe tu nombre'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline)),
                  validator: Validaciones.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  obscureText: !_verPass,
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _verPass = !_verPass),
                    ),
                  ),
                  validator: (_) => Validaciones.password(_pass.text),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reglas.entries
                      .map((r) => Chip(
                            avatar: Icon(r.value ? Icons.check_circle : Icons.circle_outlined,
                                size: 18, color: r.value ? ChaacColors.teal : ChaacColors.gray400),
                            label: Text(r.key, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor: ChaacColors.gray100,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _cargando ? null : _registrar,
                  child: _cargando
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('CREAR CUENTA'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
