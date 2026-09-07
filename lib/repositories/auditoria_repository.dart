import '../database/database_helper.dart';

class Auditoria {
  final int? id;
  final String? usuarioNombre;
  final String accion;
  final String entidad;
  final int? entidadId;
  final String detalle;
  final String fecha;

  Auditoria({
    this.id,
    this.usuarioNombre,
    required this.accion,
    this.entidad = '',
    this.entidadId,
    this.detalle = '',
    this.fecha = '',
  });

  factory Auditoria.fromRow(Map<String, Object?> r) => Auditoria(
        id: r['id'] as int?,
        usuarioNombre: (r['usuario_nombre'] ?? '') as String,
        accion: (r['accion'] ?? '') as String,
        entidad: (r['entidad'] ?? '') as String,
        entidadId: r['entidad_id'] as int?,
        detalle: (r['detalle'] ?? '') as String,
        fecha: (r['fecha'] ?? '') as String,
      );
}

class AuditoriaRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Auditoria> listar({String? usuario, String? accion, int limit = 500}) {
    var sql = 'SELECT * FROM auditoria WHERE 1=1';
    final params = <Object?>[];
    if (usuario != null && usuario.isNotEmpty) {
      sql += ' AND (usuario_nombre LIKE ?)';
      params.add('%$usuario%');
    }
    if (accion != null && accion.isNotEmpty) {
      sql += ' AND accion=?';
      params.add(accion);
    }
    sql += ' ORDER BY fecha DESC LIMIT ?';
    params.add(limit);
    return _db.db.select(sql, params).map((r) => Auditoria.fromRow(r.toMap())).toList();
  }
}
