import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tienda.dart';
import 'api_client.dart';

/// Sesión del usuario: login contra /api/auth y token guardado en el teléfono.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final instancia = AuthService._();

  static const _claveToken = 'jwt';
  final _api = ApiClient.instancia;

  UsuarioSesion? usuario;
  bool get conSesion => usuario != null;

  /// Recupera la sesión guardada al abrir la app.
  Future<void> restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_claveToken);
    if (token == null) return;
    _api.token = token;
    try {
      usuario = UsuarioSesion.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);
    } on ApiException catch (e) {
      // Token vencido: se borra. Sin red: se conserva para reintentar luego.
      if (e.noAutorizado) await _limpiar();
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      final r = await _api.post('/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
      _api.token = r['token'] as String;
    } on ApiException catch (e) {
      throw ApiException(_traducir(e), status: e.status);
    }
    usuario = UsuarioSesion.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveToken, _api.token!);
    notifyListeners();
  }

  Future<String> registrar(String nombre, String email, String password) async {
    final r = await _api.post('/auth/register', {'name': nombre, 'email': email, 'password': password});
    return (r as Map<String, dynamic>)['message'] as String? ?? 'Cuenta creada. Revisa tu correo.';
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', {});
    } catch (_) {
      // Aunque falle la red, la sesión local se cierra.
    }
    await _limpiar();
    notifyListeners();
  }

  /// Llamar cuando una petición autenticada responde 401.
  Future<void> sesionExpirada() async {
    await _limpiar();
    notifyListeners();
  }

  Future<void> _limpiar() async {
    usuario = null;
    _api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveToken);
  }

  String _traducir(ApiException e) {
    switch (e.mensaje) {
      case 'EMAIL_NOT_VERIFIED':
        return 'Tu correo aún no está verificado. Revisa tu bandeja de entrada.';
      case 'ACCOUNT_LOCKED':
        final min = e.cuerpo?['retryAfterMinutes'];
        return 'Cuenta bloqueada por intentos fallidos. Intenta en ${min ?? 'unos'} minutos.';
      default:
        return e.mensaje;
    }
  }
}
