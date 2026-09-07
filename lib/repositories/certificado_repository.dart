import '../database/database_helper.dart';
import '../models/certificado.dart';
import '../models/movimiento.dart';
import '../utils/audit.dart';
import 'auth_repository.dart';

class CertificadoRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Datos del certificado: movimientos del trabajador entre fechas, ordenados cronologicamente.
  List<Movimiento> datosParaCertificado(int trabajadorId, {int? anioDesde, int? mesDesde, int? anioHasta, int? mesHasta}) {
    var sql = 'SELECT * FROM movimientos WHERE trabajador_id=?';
    final params = <Object?>[trabajadorId];
    // Solo aportes laborales (no comisiones) en certificados.
    sql += " AND tipo_movimiento='APORTE_LABORAL'";
    if (anioDesde != null) {
      if (mesDesde != null) {
        sql += ' AND (anio > ? OR (anio = ? AND mes >= ?))';
        params.addAll([anioDesde, anioDesde, mesDesde]);
      } else {
        sql += ' AND anio >= ?';
        params.add(anioDesde);
      }
    }
    if (anioHasta != null) {
      if (mesHasta != null) {
        sql += ' AND (anio < ? OR (anio = ? AND mes <= ?))';
        params.addAll([anioHasta, anioHasta, mesHasta]);
      } else {
        sql += ' AND anio <= ?';
        params.add(anioHasta);
      }
    }
    sql += ' ORDER BY anio, mes';
    return _db.db.select(sql, params).map((r) => Movimiento.fromRow(r.toMap())).toList();
  }

  Map<String, double> totales(List<Movimiento> movs) {
    double ganado = 0, afp = 0, liquido = 0;
    int dias = 0;
    for (final m in movs) {
      ganado += m.totalGanado;
      afp += m.afp;
      liquido += m.liquidoPagable;
      dias += m.diasTrabajados;
    }
    return {'ganado': ganado, 'afp': afp, 'liquido': liquido, 'dias': dias.toDouble()};
  }

  int guardar(Certificado c) {
    final user = AuthRepository.instance.currentUser;
    _db.db.execute(
      'INSERT INTO certificados (trabajador_id, numero, fecha_desde, fecha_hasta, total_ganado, total_afp, total_liquido, total_dias, generado_por) VALUES (?,?,?,?,?,?,?,?,?)',
      [c.trabajadorId, c.numero, c.fechaDesde, c.fechaHasta, c.totalGanado, c.totalAfp, c.totalLiquido, c.totalDias, user?.id],
    );
    final id = _db.db.lastInsertRowId;
    Audit.log('GENERAR_CERTIFICADO', entidad: 'certificados', entidadId: id, detalle: 'Generó certificado para trabajador ${c.trabajadorId}');
    return id;
  }

  List<Certificado> listar({int? trabajadorId}) {
    var sql = 'SELECT * FROM certificados';
    final params = <Object?>[];
    if (trabajadorId != null) { sql += ' WHERE trabajador_id=?'; params.add(trabajadorId); }
    sql += ' ORDER BY created_at DESC';
    return _db.db.select(sql, params).map((r) => Certificado.fromRow(r.toMap())).toList();
  }
}
