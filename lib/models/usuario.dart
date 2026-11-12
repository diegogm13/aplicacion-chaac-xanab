/// Entidad de la tabla `usuarios` (Práctica 4).
///
/// Caso 4: se agregó el campo `correo`. Al cambiar la estructura también se
/// modificaron la base de datos (migración v2), la interfaz, la inserción,
/// la consulta y la actualización.
class Usuario {
  final int? id;
  final String nombre;
  final int edad;
  final String profesion;
  final String correo;

  const Usuario({
    this.id,
    required this.nombre,
    required this.edad,
    required this.profesion,
    this.correo = '',
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'edad': edad,
        'profesion': profesion,
        'correo': correo,
      };

  factory Usuario.fromMap(Map<String, Object?> map) => Usuario(
        id: map['id'] as int?,
        nombre: map['nombre'] as String,
        edad: map['edad'] as int,
        profesion: map['profesion'] as String,
        correo: (map['correo'] as String?) ?? '',
      );

  Usuario copyWith({String? nombre, int? edad, String? profesion, String? correo}) => Usuario(
        id: id,
        nombre: nombre ?? this.nombre,
        edad: edad ?? this.edad,
        profesion: profesion ?? this.profesion,
        correo: correo ?? this.correo,
      );
}
