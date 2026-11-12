import 'package:flutter/material.dart';

/// Paleta tomada de chaac-xanab-dg/src/styles.css
class ChaacColors {
  static const black = Color(0xFF000000);
  static const teal = Color(0xFF005147);
  static const redDark = Color(0xFFBA2B2B);
  static const coral = Color(0xFFEA553B);
  static const gray100 = Color(0xFFF5F5F5);
  static const gray400 = Color(0xFF757575);
}

ThemeData chaacTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ChaacColors.teal, primary: ChaacColors.teal, secondary: ChaacColors.coral),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ChaacColors.black,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ChaacColors.gray100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ChaacColors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: .5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// $2,999
String precio(double valor) {
  final entero = valor.round().toString();
  final conComas = entero.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '\$$conComas';
}

/// Imagen de producto con placeholder mientras carga o si falla.
class ImagenRed extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const ImagenRed(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progreso) =>
          progreso == null ? child : Container(color: ChaacColors.gray100),
      errorBuilder: (_, _, _) => Container(
        color: ChaacColors.gray100,
        child: const Center(child: Icon(Icons.image_not_supported_outlined, color: ChaacColors.gray400)),
      ),
    );
  }
}

void avisar(BuildContext context, String mensaje, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? ChaacColors.redDark : ChaacColors.black,
    ));
}
