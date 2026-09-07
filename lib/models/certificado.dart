class Certificado {
  final int? id;
  final int trabajadorId;
  final String numero;
  final String fechaDesde;
  final String fechaHasta;
  final double totalGanado;
  final double totalAfp;
  final double totalLiquido;
  final int totalDias;
  final int? generadoPor;
  final String createdAt;

  Certificado({
    this.id,
    required this.trabajadorId,
    this.numero = '',
    this.fechaDesde = '',
    this.fechaHasta = '',
    this.totalGanado = 0,
    this.totalAfp = 0,
    this.totalLiquido = 0,
    this.totalDias = 0,
    this.generadoPor,
    this.createdAt = '',
  });

  factory Certificado.fromRow(Map<String, Object?> r) => Certificado(
        id: r['id'] as int?,
        trabajadorId: (r['trabajador_id'] ?? 0) as int,
        numero: (r['numero'] ?? '') as String,
        fechaDesde: (r['fecha_desde'] ?? '') as String,
        fechaHasta: (r['fecha_hasta'] ?? '') as String,
        totalGanado: ((r['total_ganado'] ?? 0) as num).toDouble(),
        totalAfp: ((r['total_afp'] ?? 0) as num).toDouble(),
        totalLiquido: ((r['total_liquido'] ?? 0) as num).toDouble(),
        totalDias: (r['total_dias'] ?? 0) as int,
        generadoPor: r['generado_por'] as int?,
        createdAt: (r['created_at'] ?? '') as String,
      );
}
