class Trabajador {
  final int? id;
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String nombreCompleto;
  final String ci;
  final String cua;
  final String cargo;
  final String area;
  final String estado;
  final String createdAt;

  Trabajador({
    this.id,
    required this.nombres,
    required this.apellidoPaterno,
    this.apellidoMaterno = '',
    required this.nombreCompleto,
    required this.ci,
    this.cua = '',
    this.cargo = '',
    this.area = '',
    this.estado = 'ACTIVO',
    this.createdAt = '',
  });

  factory Trabajador.fromRow(Map<String, Object?> r) => Trabajador(
        id: r['id'] as int?,
        nombres: (r['nombres'] ?? '') as String,
        apellidoPaterno: (r['apellido_paterno'] ?? '') as String,
        apellidoMaterno: (r['apellido_materno'] ?? '') as String,
        nombreCompleto: (r['nombre_completo'] ?? '') as String,
        ci: (r['ci'] ?? '') as String,
        cua: (r['cua'] ?? '') as String,
        cargo: (r['cargo'] ?? '') as String,
        area: (r['area'] ?? '') as String,
        estado: (r['estado'] ?? 'ACTIVO') as String,
        createdAt: (r['created_at'] ?? '') as String,
      );
}
