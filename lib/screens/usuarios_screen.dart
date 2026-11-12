import 'package:flutter/material.dart';

import '../db/usuario_dao.dart';
import '../models/usuario.dart';
import '../theme.dart';

/// Práctica 4 — almacenamiento estructurado (CRUD de usuarios en SQLite).
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _dao = UsuarioDao();
  List<Usuario>? _usuarios; // null = aún no se presiona "VER usuarios"

  Future<void> _verUsuarios() async {
    final lista = await _dao.obtenerTodos();
    setState(() => _usuarios = lista);
  }

  Future<void> _abrirFormulario([Usuario? existente]) async {
    final resultado = await showModalBottomSheet<Usuario>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UsuarioForm(existente: existente),
    );
    if (resultado == null) return;
    if (existente == null) {
      await _dao.insertar(resultado);
    } else {
      await _dao.actualizar(resultado);
    }
    await _verUsuarios();
    _avisar(existente == null ? 'Usuario registrado' : 'Usuario actualizado');
  }

  Future<void> _eliminar(Usuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${u.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.eliminar(u.id!);
    await _verUsuarios();
    _avisar('Usuario eliminado');
  }

  void _avisar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = _usuarios;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: ChaacColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Registrar'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Usuarios',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Guardados en SQLite dentro del teléfono', style: TextStyle(color: Colors.grey.shade600)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _verUsuarios,
              icon: const Icon(Icons.list_alt),
              label: const Text('VER usuarios'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ChaacColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: usuarios == null
                ? const Center(child: Text('Presiona VER usuarios para consultar la tabla.'))
                : usuarios.isEmpty
                    ? const Center(child: Text('No hay usuarios registrados.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: usuarios.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _UsuarioTile(
                          usuario: usuarios[i],
                          onEditar: () => _abrirFormulario(usuarios[i]),
                          onEliminar: () => _eliminar(usuarios[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UsuarioTile extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  const _UsuarioTile({required this.usuario, required this.onEditar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ChaacColors.teal,
          foregroundColor: Colors.white,
          child: Text('${u.id}'),
        ),
        title: Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${u.edad} años · ${u.profesion}${u.correo.isEmpty ? '' : '\n${u.correo}'}'),
        isThreeLine: u.correo.isNotEmpty,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Modificar', icon: const Icon(Icons.edit_outlined), onPressed: onEditar),
          IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline), onPressed: onEliminar),
        ]),
      ),
    );
  }
}

class _UsuarioForm extends StatefulWidget {
  final Usuario? existente;
  const _UsuarioForm({this.existente});

  @override
  State<_UsuarioForm> createState() => _UsuarioFormState();
}

class _UsuarioFormState extends State<_UsuarioForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.existente?.nombre);
  late final _edad = TextEditingController(text: widget.existente?.edad.toString());
  late final _profesion = TextEditingController(text: widget.existente?.profesion);
  late final _correo = TextEditingController(text: widget.existente?.correo);

  @override
  void dispose() {
    for (final c in [_nombre, _edad, _profesion, _correo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final datos = Usuario(
      id: widget.existente?.id,
      nombre: _nombre.text.trim(),
      edad: int.parse(_edad.text.trim()),
      profesion: _profesion.text.trim(),
      correo: _correo.text.trim(),
    );
    Navigator.pop(context, datos);
  }

  String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final editando = widget.existente != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editando ? 'Modificar usuario' : 'Registrar usuario',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextFormField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre'), validator: _requerido),
            TextFormField(
              controller: _edad,
              decoration: const InputDecoration(labelText: 'Edad'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return (n == null || n < 0 || n > 120) ? 'Edad inválida' : null;
              },
            ),
            TextFormField(
                controller: _profesion, decoration: const InputDecoration(labelText: 'Profesión / carrera'), validator: _requerido),
            TextFormField(
              controller: _correo,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Correo inválido';
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardar,
              style: FilledButton.styleFrom(backgroundColor: ChaacColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(editando ? 'GUARDAR CAMBIOS' : 'REGISTRAR'),
            ),
          ],
        ),
      ),
    );
  }
}
