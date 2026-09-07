class EstadoAhorro {
  final int? id;
  final int documentoId;
  final int trabajadorId;
  final String numeroEstado;
  final String periodo;
  final String fechaEmision;
  final String estado;
  final String rawText;
  final String createdAt;

  EstadoAhorro({
    this.id,
    required this.documentoId,
    required this.trabajadorId,
    this.numeroEstado = '',
    this.periodo = '',
    this.fechaEmision = '',
    this.estado = 'REQUIERE_REVISION',
    this.rawText = '',
    this.createdAt = '',
  });

  factory EstadoAhorro.fromRow(Map<String, Object?> r) => EstadoAhorro(
        id: r['id'] as int?,
        documentoId: (r['documento_id'] ?? 0) as int,
        trabajadorId: (r['trabajador_id'] ?? 0) as int,
        numeroEstado: (r['numero_estado'] ?? '') as String,
        periodo: (r['periodo'] ?? '') as String,
        fechaEmision: (r['fecha_emision'] ?? '') as String,
        estado: (r['estado'] ?? 'REQUIERE_REVISION') as String,
        rawText: (r['raw_text'] ?? '') as String,
        createdAt: (r['created_at'] ?? '') as String,
      );
}
