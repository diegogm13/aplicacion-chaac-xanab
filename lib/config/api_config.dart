/// URL preasignada (Práctica 3).
///
/// La URL vive separada de la lógica de la app: si el backend cambia de
/// dominio solo se modifica este archivo.
class ApiConfig {
  ///
  /// Se puede cambiar al compilar sin tocar el código (Práctica 12), p. ej.:
  ///   flutter run --dart-define=API_URL=http://localhost:3000/api
  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'https://backend-chaac-xanab.vercel.app/api');

  /// Recurso que consulta la pantalla "Consulta de información".
  static const String productosUrl = '$baseUrl/productos';

  /// Tiempo máximo de espera de cada intento HTTP.
  /// Práctica 12: 20 s → 10 s. Una consulta normal tarda < 0.5 s y la compra < 1 s
  /// (P95 bajo carga ≈ 1.2 s), así que 10 s sigue dejando un margen amplio y la app
  /// detecta un servidor colgado en la mitad del tiempo.
  static const Duration timeout = Duration(seconds: 10);
}
