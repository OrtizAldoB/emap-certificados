import '../database/database_helper.dart';
import '../models/documento.dart';
import '../models/estado_ahorro.dart';
import '../models/movimiento.dart';
import '../utils/audit.dart';
import 'auth_repository.dart';

class DocumentoRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Documento> listar({int? trabajadorId, String estado = ''}) {
    var sql = 'SELECT * FROM documentos WHERE 1=1';
    final params = <Object?>[];
    if (trabajadorId != null) {
      sql += ' AND trabajador_id=?';
      params.add(trabajadorId);
    }
    if (estado.isNotEmpty) {
      sql += ' AND estado=?';
      params.add(estado);
    }
    sql += ' ORDER BY uploaded_at DESC';
    return _db.db
        .select(sql, params)
        .map((r) => Documento.fromRow(rowMap(r)))
        .toList();
  }

  Documento? getById(int id) {
    final rows = _db.db.select('SELECT * FROM documentos WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return Documento.fromRow(rowMap(rows.first));
  }

  /// Registra un documento subido. Devuelve null si existe duplicado aparente.
  Documento? registrar({
    required int trabajadorId,
    required String filename,
    required String ruta,
    required String hash,
    required int size,
  }) {
    final dup = _db.db.select('SELECT * FROM documentos WHERE file_hash=? AND file_hash<>?', [hash, '']);
    if (dup.isNotEmpty) {
      return null;
    }
    final user = AuthRepository.instance.currentUser;
    _db.db.execute(
      'INSERT INTO documentos (trabajador_id, filename, file_hash, file_size, ruta, estado, uploaded_by) VALUES (?,?,?,?,?,?,?)',
      [trabajadorId, filename, hash, size, ruta, 'PENDIENTE', user?.id],
    );
    final newId = _db.db.lastInsertRowId;
    Audit.log('SUBIR_DOCUMENTO', entidad: 'documentos', entidadId: newId, detalle: 'Subió el documento $filename');
    return getById(newId);
  }

  void actualizarEstado(int id, String estado) {
    _db.db.execute('UPDATE documentos SET estado=? WHERE id=?', [estado, id]);
  }

  // ---- Estado de ahorro ----

  int crearEstadoAhorro(int documentoId, int trabajadorId, {String numero = '', String periodo = '', String fechaEmision = '', String rawText = '', String estado = 'REQUIERE_REVISION'}) {
    _db.db.execute(
      'INSERT INTO estados_ahorro (documento_id, trabajador_id, numero_estado, periodo, fecha_emision, estado, raw_text) VALUES (?,?,?,?,?,?,?)',
      [documentoId, trabajadorId, numero, periodo, fechaEmision, estado, rawText],
    );
    return _db.db.lastInsertRowId;
  }

  EstadoAhorro? getEstadoAhorroByDocumento(int documentoId) {
    final rows = _db.db.select('SELECT * FROM estados_ahorro WHERE documento_id=?', [documentoId]);
    if (rows.isEmpty) return null;
    return EstadoAhorro.fromRow(rowMap(rows.first));
  }

  // ---- Movimientos ----

  int guardarMovimiento(Movimiento m) {
    _db.db.execute(
      'INSERT INTO movimientos (estado_ahorro_id, trabajador_id, anio, mes, empleador, tipo_movimiento, total_ganado, dias_trabajados, cotizacion_mensual, aporte_voluntario, aporte_beneficio_social, comision, total_aportes, valor_cuota, total_numero_cuotas, fecha_pago, afp, liquido_pagable, original_total_ganado, original_afp, original_liquido, original_dias, requiere_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [m.estadoAhorroId, m.trabajadorId, m.anio, m.mes, m.empleador, m.tipoMovimiento, m.totalGanado, m.diasTrabajados, m.cotizacionMensual, m.aporteVoluntario, m.aporteBeneficioSocial, m.comision, m.totalAportes, m.valorCuota, m.totalNumeroCuotas, m.fechaPago, m.afp, m.liquidoPagable, m.originalTotalGanado, m.originalAfp, m.originalLiquido, m.originalDias, m.requiereRevision ? 1 : 0],
    );
    return _db.db.lastInsertRowId;
  }

  void actualizarMovimiento(Movimiento m) {
    _db.db.execute(
      'UPDATE movimientos SET total_ganado=?, dias_trabajados=?, afp=?, liquido_pagable=?, requiere_revision=?, updated_at=datetime(\'now\',\'localtime\') WHERE id=?',
      [m.totalGanado, m.diasTrabajados, m.afp, m.liquidoPagable, m.requiereRevision ? 1 : 0, m.id],
    );
  }

  void registrarCorreccion(int movimientoId, String campo, String original, String nuevo) {
    final user = AuthRepository.instance.currentUser;
    _db.db.execute(
      'INSERT INTO correcciones_movimiento (movimiento_id, campo, valor_original, valor_nuevo, usuario_id, usuario_nombre) VALUES (?,?,?,?,?,?)',
      [movimientoId, campo, original, nuevo, user?.id, user?.nombre],
    );
    Audit.log('MODIFICACION_MOVIMIENTO', entidad: 'movimientos', entidadId: movimientoId,
        detalle: 'Cambio en $campo: $original -> $nuevo');
  }

  List<Movimiento> listarMovimientos({int? trabajadorId, int? estadoAhorroId, int? anio, int? mes}) {
    var sql = 'SELECT * FROM movimientos WHERE 1=1';
    final params = <Object?>[];
    if (trabajadorId != null) { sql += ' AND trabajador_id=?'; params.add(trabajadorId); }
    if (estadoAhorroId != null) { sql += ' AND estado_ahorro_id=?'; params.add(estadoAhorroId); }
    if (anio != null) { sql += ' AND anio=?'; params.add(anio); }
    if (mes != null) { sql += ' AND mes=?'; params.add(mes); }
    sql += ' ORDER BY anio, mes';
    return _db.db.select(sql, params).map((r) => Movimiento.fromRow(rowMap(r))).toList();
  }

  bool documentoYaRegistrado(String fileHash) {
    final r = _db.db.select('SELECT COUNT(*) AS c FROM documentos WHERE file_hash=? AND file_hash<>?', [fileHash, '']);
    return (rowMap(r.first)['c'] as int) > 0;
  }
}