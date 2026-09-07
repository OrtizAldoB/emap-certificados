import '../database/database_helper.dart';
import '../utils/audit.dart';

class ConfiguracionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Map<String, String> obtenerTodas() {
    final rows = _db.db.select('SELECT clave, valor FROM configuracion');
    return {for (final r in rows) (r.toMap()['clave'] as String): (r.toMap()['valor'] as String)};
  }

  String get(String clave, [String def = '']) {
    final rows = _db.db.select('SELECT valor FROM configuracion WHERE clave=?', [clave]);
    if (rows.isEmpty) return def;
    return (rows.first.toMap()['valor'] ?? def) as String;
  }

  void set(String clave, String valor, {bool soloAdmin = true}) {
    final exists = _db.db.select('SELECT clave FROM configuracion WHERE clave=?', [clave]);
    if (exists.isEmpty) {
      _db.db.execute(
        'INSERT INTO configuracion (clave, valor, descripcion, solo_admin) VALUES (?,?,?,?)',
        [clave, valor, '', soloAdmin ? 1 : 0],
      );
    } else {
      _db.db.execute(
        "UPDATE configuracion SET valor=?, updated_at=datetime('now','localtime') WHERE clave=?",
        [valor, clave],
      );
    }
    Audit.log('MODIFICAR_CONFIGURACION', entidad: 'configuracion', detalle: '$clave = $valor');
  }

  /// Resuelve el valor AFP de un movimiento segun el campo configurado.
  double resolverAfp(Map<String, Object?> mov) {
    final campo = get('afp_campo', 'TOTAL_APORTES');
    switch (campo) {
      case 'COTIZACION_MENSUAL':
        return ((mov['cotizacion_mensual'] ?? 0) as num).toDouble();
      case 'TOTAL_APORTES':
        return ((mov['total_aportes'] ?? 0) as num).toDouble();
      case 'COMISION':
        return ((mov['comision'] ?? 0) as num).toDouble();
      case 'APORTE_VOLUNTARIO':
        return ((mov['aporte_voluntario'] ?? 0) as num).toDouble();
      default:
        return ((mov['total_aportes'] ?? 0) as num).toDouble();
    }
  }

  /// Resuelve el liquido pagable segun la formula configurada.
  double resolverLiquido(double totalGanado, double afp) {
    final formula = get('liquido_formula', 'MANUAL');
    switch (formula) {
      case 'TOTAL_GANADO_MENOS_AFP':
        return totalGanado - afp;
      case 'MANUAL':
      case 'LIBRE':
      default:
        // Manual: el operador ingresa el valor.
        return 0;
    }
  }
}
