import '../database/database_helper.dart';
import '../models/trabajador.dart';
import '../utils/audit.dart';

class TrabajadorRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Trabajador> listar({String query = ''}) {
    if (query.isEmpty) {
      return _db.db
          .select('SELECT * FROM trabajadores ORDER BY nombre_completo')
          .map((r) => Trabajador.fromRow(rowMap(r)))
          .toList();
    }
    final q = '%$query%';
    return _db.db
        .select(
          'SELECT * FROM trabajadores WHERE nombre_completo LIKE ? OR ci LIKE ? OR cua LIKE ? ORDER BY nombre_completo',
          [q, q, q],
        )
        .map((r) => Trabajador.fromRow(rowMap(r)))
        .toList();
  }

  Trabajador? getById(int id) {
    final rows = _db.db.select('SELECT * FROM trabajadores WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return Trabajador.fromRow(rowMap(rows.first));
  }

  int crear(Trabajador t) {
    _db.db.execute(
      'INSERT INTO trabajadores (nombres, apellido_paterno, apellido_materno, nombre_completo, ci, cua, cargo, area, estado) VALUES (?,?,?,?,?,?,?,?,?)',
      [t.nombres, t.apellidoPaterno, t.apellidoMaterno, t.nombreCompleto, t.ci, t.cua, t.cargo, t.area, t.estado],
    );
    final newId = _db.db.lastInsertRowId;
    Audit.log('CREAR_TRABAJADOR', entidad: 'trabajadores', entidadId: newId, detalle: 'Creó al trabajador ${t.nombreCompleto}');
    return newId;
  }

  void actualizar(Trabajador t) {
    _db.db.execute(
      'UPDATE trabajadores SET nombres=?, apellido_paterno=?, apellido_materno=?, nombre_completo=?, ci=?, cua=?, cargo=?, area=?, estado=?, updated_at=datetime(\'now\',\'localtime\') WHERE id=?',
      [t.nombres, t.apellidoPaterno, t.apellidoMaterno, t.nombreCompleto, t.ci, t.cua, t.cargo, t.area, t.estado, t.id],
    );
    Audit.log('EDITAR_TRABAJADOR', entidad: 'trabajadores', entidadId: t.id, detalle: 'Editó al trabajador ${t.nombreCompleto}');
  }

  bool eliminar(int id) {
    try {
      final docs = _db.db.select(
          'SELECT COUNT(*) AS c FROM documentos WHERE trabajador_id=?', [id]);
      if ((rowMap(docs.first)['c'] as int) > 0) return false;
      _db.db.execute('DELETE FROM trabajadores WHERE id=?', [id]);
      Audit.log('ELIMINAR_TRABAJADOR', entidad: 'trabajadores', entidadId: id, detalle: 'Eliminó al trabajador id=$id');
      return true;
    } catch (_) {
      return false;
    }
  }
}