class Usuario {
  final int? id;
  final String username;
  final String passwordHash;
  final String nombre;
  final String rol;
  final bool activo;
  final String createdAt;

  Usuario({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.nombre,
    required this.rol,
    this.activo = true,
    this.createdAt = '',
  });

  bool get esAdministrador => rol == 'ADMINISTRADOR';

  factory Usuario.fromRow(Map<String, Object?> r) => Usuario(
        id: r['id'] as int?,
        username: (r['username'] ?? '') as String,
        passwordHash: (r['password_hash'] ?? '') as String,
        nombre: (r['nombre'] ?? '') as String,
        rol: (r['rol'] ?? 'OPERADOR') as String,
        activo: (r['activo'] ?? 1) == 1,
        createdAt: (r['created_at'] ?? '') as String,
      );
}
