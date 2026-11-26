/// Validaciones de entrada de la app, extraídas de las pantallas para poder
/// probarlas de forma aislada (Práctica 11 — pruebas White Box).
///
/// Las reglas son exactamente las mismas que ya aplicaban los formularios; no
/// se relajó ni se endureció ninguna condición.
class Validaciones {
  Validaciones._();

  static final RegExp _emailCompleto = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _soloDigitos = RegExp(r'^\d+$');

  /// Campo obligatorio (nombre, calle, colonia, etc.).
  static String? requerido(String? valor, {String mensaje = 'Obligatorio'}) {
    return (valor == null || valor.trim().isEmpty) ? mensaje : null;
  }

  /// Correo con estructura `usuario@dominio.ext` (registro y CRUD local).
  static bool emailValido(String? valor) {
    return _emailCompleto.hasMatch(valor?.trim() ?? '');
  }

  static String? email(String? valor, {String mensaje = 'Escribe un correo válido'}) {
    return emailValido(valor) ? null : mensaje;
  }

  /// Validación deliberadamente laxa del login: solo exige una `@`.
  /// Se conserva así porque el backend es quien valida el correo real.
  static bool emailBasico(String? valor) {
    return valor != null && valor.contains('@');
  }

  static String? loginEmail(String? valor, {String mensaje = 'Escribe un correo válido'}) {
    return emailBasico(valor) ? null : mensaje;
  }

  // ---- Práctica 5: código seguro en el inicio de sesión ----

  /// Longitudes máximas aceptadas en el login (el correo más largo permitido por RFC 5321 es 254).
  static const int maxCorreo = 100;
  static const int maxPassword = 64;
  static const int minPassword = 8;

  /// Correo del login: obligatorio, sin aceptar solo espacios, con longitud máxima y formato válido.
  static String? correoLogin(String? valor) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return 'Escribe tu correo';
    if (t.length > maxCorreo) return 'El correo no puede tener más de $maxCorreo caracteres';
    if (!emailValido(t)) return 'Escribe un correo válido';
    return null;
  }

  /// Contraseña del login: obligatoria, de 8 a 64 caracteres. No se recorta: los espacios cuentan.
  static String? passwordLogin(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Escribe tu contraseña';
    if (v.length < minPassword) return 'La contraseña debe tener al menos $minPassword caracteres';
    if (v.length > maxPassword) return 'La contraseña no puede tener más de $maxPassword caracteres';
    return null;
  }

  /// Reglas de contraseña fuertes, idénticas a `IsStrongPassword` del backend.
  static Map<String, bool> reglasPassword(String password) {
    return {
      '8 caracteres o más': password.length >= 8,
      'Una mayúscula': password.contains(RegExp(r'[A-Z]')),
      'Una minúscula': password.contains(RegExp(r'[a-z]')),
      'Un número': password.contains(RegExp(r'\d')),
      'Un símbolo': password.contains(RegExp(r'[^A-Za-z0-9]')),
    };
  }

  static bool passwordFuerte(String password) {
    return reglasPassword(password).values.every((ok) => ok);
  }

  static String? password(String password, {String mensaje = 'La contraseña no cumple los requisitos'}) {
    return passwordFuerte(password) ? null : mensaje;
  }

  /// Edad permitida: entero entre 0 y 120 (tabla `usuarios`).
  static bool edadValida(String? valor) {
    final n = int.tryParse(valor?.trim() ?? '');
    return n != null && n >= 0 && n <= 120;
  }

  static String? edad(String? valor, {String mensaje = 'Edad inválida'}) {
    return edadValida(valor) ? null : mensaje;
  }

  /// Código postal mexicano: exactamente cinco dígitos.
  static bool codigoPostalValido(String? valor) {
    final t = valor?.trim() ?? '';
    return t.length == 5 && _soloDigitos.hasMatch(t);
  }

  static String? codigoPostal(String? valor, {String mensaje = '5 dígitos'}) {
    return codigoPostalValido(valor) ? null : mensaje;
  }
}
