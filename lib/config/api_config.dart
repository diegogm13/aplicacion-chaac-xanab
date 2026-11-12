/// URL preasignada (Práctica 3).
///
/// La URL vive separada de la lógica de la app: si el backend cambia de
/// dominio solo se modifica este archivo.
class ApiConfig {
  static const String baseUrl = 'https://backend-chaac-xanab.vercel.app/api';

  /// Recurso que consulta la pantalla "Consulta de información".
  static const String productosUrl = '$baseUrl/productos';

  /// Tiempo máximo de espera de la petición HTTP.
  static const Duration timeout = Duration(seconds: 20);
}
