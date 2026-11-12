// Práctica 11 — White Box: método de VALIDACIÓN (lib/config/validaciones.dart).
//
// Cada prueba indica el camino (P#) del grafo de flujo y la condición (C#) que
// se fuerza a verdadero/falso. Los grafos están en practica11/INFORME.md §2.1.
import 'package:chaac_xanab_app/config/validaciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requerido()  — D1: valor == null || valor.trim().isEmpty', () {
    test('P1  C1=V            null -> mensaje', () => expect(Validaciones.requerido(null), 'Obligatorio'));
    test('P2  C1=F C2=V       "" -> mensaje', () => expect(Validaciones.requerido(''), 'Obligatorio'));
    test('P2  C1=F C2=V       solo espacios -> mensaje (límite)', () => expect(Validaciones.requerido('   '), 'Obligatorio'));
    test('P3  C1=F C2=F       "a" (1 carácter, límite) -> null', () => expect(Validaciones.requerido('a'), isNull));
    test('mensaje personalizado se propaga', () {
      expect(Validaciones.requerido(null, mensaje: 'Escribe tu nombre'), 'Escribe tu nombre');
    });
  });

  group('edadValida()  — D1: n != null && n >= 0 && n <= 120', () {
    // Condición C1 (n != null)
    test('C1=F  texto no numérico', () => expect(Validaciones.edadValida('abc'), isFalse));
    test('C1=F  null', () => expect(Validaciones.edadValida(null), isFalse));
    test('C1=F  decimal "20.5"', () => expect(Validaciones.edadValida('20.5'), isFalse));
    // Valores límite inferiores (C2)
    test('C2=F  -1 (límite inferior - 1)', () => expect(Validaciones.edadValida('-1'), isFalse));
    test('C2=V   0 (límite inferior)', () => expect(Validaciones.edadValida('0'), isTrue));
    test('C2=V   1 (límite inferior + 1)', () => expect(Validaciones.edadValida('1'), isTrue));
    // Valores límite superiores (C3)
    test('C3=V 119 (límite superior - 1)', () => expect(Validaciones.edadValida('119'), isTrue));
    test('C3=V 120 (límite superior)', () => expect(Validaciones.edadValida('120'), isTrue));
    test('C3=F 121 (límite superior + 1)', () => expect(Validaciones.edadValida('121'), isFalse));
    test('trim: " 30 " es válido', () => expect(Validaciones.edadValida(' 30 '), isTrue));
    test('edad() devuelve mensaje / null', () {
      expect(Validaciones.edad('200'), 'Edad inválida');
      expect(Validaciones.edad('25'), isNull);
    });
  });

  group('codigoPostalValido()  — D1: t.length == 5 && soloDigitos', () {
    test('C1=F  4 dígitos (límite - 1)', () => expect(Validaciones.codigoPostalValido('9700'), isFalse));
    test('C1=V C2=V  5 dígitos (límite)', () => expect(Validaciones.codigoPostalValido('97000'), isTrue));
    test('C1=F  6 dígitos (límite + 1)', () => expect(Validaciones.codigoPostalValido('970001'), isFalse));
    test('C1=V C2=F  5 caracteres con letra', () => expect(Validaciones.codigoPostalValido('9700a'), isFalse));
    test('C1=V C2=F  5 caracteres con guion', () => expect(Validaciones.codigoPostalValido('97-00'), isFalse));
    test('null -> inválido', () => expect(Validaciones.codigoPostalValido(null), isFalse));
    test('espacios alrededor se recortan', () => expect(Validaciones.codigoPostalValido(' 97000 '), isTrue));
    test('codigoPostal() mensaje', () {
      expect(Validaciones.codigoPostal('1'), '5 dígitos');
      expect(Validaciones.codigoPostal('01000'), isNull);
    });
  });

  group('reglasPassword() / passwordFuerte()  — 5 condiciones independientes', () {
    const valida = 'Chaac#2026';

    test('todas las condiciones V -> fuerte', () {
      expect(Validaciones.reglasPassword(valida).values, everyElement(isTrue));
      expect(Validaciones.passwordFuerte(valida), isTrue);
      expect(Validaciones.password(valida), isNull);
    });

    // Cobertura de condiciones: cada caso deja UNA sola condición en falso.
    final casos = <String, String>{
      '8 caracteres o más': 'Ch#2026', //          7 caracteres (límite - 1)
      'Una mayúscula': 'chaac#2026',
      'Una minúscula': 'CHAAC#2026',
      'Un número': 'Chaac#Xan',
      'Un símbolo': 'Chaac2026',
    };
    casos.forEach((regla, pass) {
      test('solo "$regla" = F  ("$pass")', () {
        final r = Validaciones.reglasPassword(pass);
        expect(r[regla], isFalse, reason: regla);
        expect(r.entries.where((e) => e.key != regla).map((e) => e.value), everyElement(isTrue));
        expect(Validaciones.passwordFuerte(pass), isFalse);
        expect(Validaciones.password(pass), 'La contraseña no cumple los requisitos');
      });
    });

    test('longitud exactamente 8 (límite) -> cumple', () {
      expect(Validaciones.reglasPassword('Ab#45678')['8 caracteres o más'], isTrue);
    });

    test('cadena vacía -> ninguna regla', () {
      expect(Validaciones.reglasPassword('').values, everyElement(isFalse));
    });

    test('espacio cuenta como símbolo (igual que IsStrongPassword del backend)', () {
      expect(Validaciones.reglasPassword('Chaac 2026')['Un símbolo'], isTrue);
    });
  });

  group('email() completo vs loginEmail() básico', () {
    test('email válido', () => expect(Validaciones.emailValido('ana@chaac.mx'), isTrue));
    test('sin dominio', () => expect(Validaciones.emailValido('ana@chaac'), isFalse));
    test('sin usuario', () => expect(Validaciones.emailValido('@chaac.mx'), isFalse));
    test('con espacio interno', () => expect(Validaciones.emailValido('a na@chaac.mx'), isFalse));
    test('null', () => expect(Validaciones.emailValido(null), isFalse));
    test('email() mensaje', () {
      expect(Validaciones.email('x'), 'Escribe un correo válido');
      expect(Validaciones.email('a@b.co'), isNull);
    });

    // loginEmail: D1 = valor != null && valor.contains('@')
    test('login C1=F  null', () => expect(Validaciones.loginEmail(null), isNotNull));
    test('login C1=V C2=F  sin @', () => expect(Validaciones.loginEmail('ana'), isNotNull));
    test('login C1=V C2=V  "a@"', () => expect(Validaciones.loginEmail('a@'), isNull));

    test('HALLAZGO: login acepta "a@" que el registro rechaza (validación inconsistente)', () {
      expect(Validaciones.emailBasico('a@'), isTrue);
      expect(Validaciones.emailValido('a@'), isFalse);
    });
  });
}
