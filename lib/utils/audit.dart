import '../database/database_helper.dart';
import '../repositories/auth_repository.dart';

/// Registra acciones de auditoria usando el usuario actual.
class Audit {
  static void log(String accion, {String entidad = '', int? entidadId, String detalle = ''}) {
    final u = AuthRepository.instance.currentUser;
    DatabaseHelper.instance.db.execute(
      "INSERT INTO auditoria (usuario_id, usuario_nombre, accion, entidad, entidad_id, detalle) VALUES (?,?,?,?,?,?)",
      [u?.id, u?.nombre, accion, entidad, entidadId, detalle],
    );
  }
}
