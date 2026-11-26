// Práctica 5 — Código seguro en el inicio de sesión (adaptada de Kotlin a Flutter).
import 'dart:io';

import 'package:chaac_xanab_app/config/validaciones.dart';
import 'package:chaac_xanab_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5 validación de entradas del login', () {
    test('correo: vacío, solo espacios, demasiado largo, mal formado y válido', () {
      expect(Validaciones.correoLogin(null), 'Escribe tu correo');
      expect(Validaciones.correoLogin(''), 'Escribe tu correo');
      expect(Validaciones.correoLogin('     '), 'Escribe tu correo');
      final largo = '${'a' * 95}@x.com'; // 101 caracteres
      expect(Validaciones.correoLogin(largo), contains('más de 100'));
      expect(Validaciones.correoLogin('a@'), 'Escribe un correo válido');
      expect(Validaciones.correoLogin('  cliente@chaac.mx  '), isNull);
    });

    test('contraseña: vacía, menos de 8, límites 8 y 64, más de 64', () {
      expect(Validaciones.passwordLogin(null), 'Escribe tu contraseña');
      expect(Validaciones.passwordLogin(''), 'Escribe tu contraseña');
      expect(Validaciones.passwordLogin('1234567'), contains('al menos 8'));
      expect(Validaciones.passwordLogin('12345678'), isNull);
      expect(Validaciones.passwordLogin('x' * 64), isNull);
      expect(Validaciones.passwordLogin('x' * 65), contains('más de 64'));
    });
  });

  group('P5 pantalla de login', () {
    testWidgets('la contraseña se oculta y las entradas inválidas muestran mensajes genéricos', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      final campos = find.byType(TextField);
      expect(campos, findsNWidgets(2));
      final pass = tester.widget<TextField>(campos.at(1));
      expect(pass.obscureText, isTrue);
      expect(pass.enableSuggestions, isFalse);
      expect(pass.autocorrect, isFalse);

      await tester.enterText(campos.at(0), '   ');
      await tester.enterText(campos.at(1), '123');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();
      expect(find.text('Escribe tu correo'), findsOneWidget);
      expect(find.text('La contraseña debe tener al menos 8 caracteres'), findsOneWidget);
    });
  });

  group('P5 no se registran datos sensibles', () {
    test('el código de la app no usa print, debugPrint ni log', () {
      final archivos = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      final patron = RegExp(r'\b(print|debugPrint|log)\s*\(');
      final conLogs = [
        for (final f in archivos)
          if (patron.hasMatch(f.readAsStringSync())) f.path,
      ];
      expect(conLogs, isEmpty, reason: 'Ningún archivo debe escribir en la consola (Logcat).');
    });
  });
}
