class Documento {
  final int? id;
  final int trabajadorId;
  final String filename;
  final String fileHash;
  final int fileSize;
  final String ruta;
  final String estado;
  final int? uploadedBy;
  final String uploadedAt;

  Documento({
    this.id,
    required this.trabajadorId,
    required this.filename,
    this.fileHash = '',
    this.fileSize = 0,
    this.ruta = '',
    this.estado = 'PENDIENTE',
    this.uploadedBy,
    this.uploadedAt = '',
  });

  factory Documento.fromRow(Map<String, Object?> r) => Documento(
        id: r['id'] as int?,
        trabajadorId: (r['trabajador_id'] ?? 0) as int,
        filename: (r['filename'] ?? '') as String,
        fileHash: (r['file_hash'] ?? '') as String,
        fileSize: (r['file_size'] ?? 0) as int,
        ruta: (r['ruta'] ?? '') as String,
        estado: (r['estado'] ?? 'PENDIENTE') as String,
        uploadedBy: r['uploaded_by'] as int?,
        uploadedAt: (r['uploaded_at'] ?? '') as String,
      );
}
