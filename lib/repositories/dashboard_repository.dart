import '../database/database_helper.dart';
import '../models/movimiento.dart';
import 'documento_repository.dart';

class DashboardDatos {
  int trabajadores = 0;
  int documentos = 0;
  int procesados = 0;
  int pendientes = 0;
  int certificados = 0;
  List<Movimiento> movimientos = [];
}

class DashboardRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  DashboardDatos resumen() {
    final d = DashboardDatos();
    int count(String sql) => (rowMap(_db.db.select(sql).first)['c'] as int);

    d.trabajadores = count('SELECT COUNT(*) AS c FROM trabajadores');
    d.documentos = count('SELECT COUNT(*) AS c FROM documentos');
    d.procesados = count("SELECT COUNT(*) AS c FROM documentos WHERE estado='PROCESADO'");
    d.pendientes = count("SELECT COUNT(*) AS c FROM documentos WHERE estado IN ('PENDIENTE','PROCESANDO','REQUIERE_REVISION','ERROR')");
    d.certificados = count('SELECT COUNT(*) AS c FROM certificados');

    final rows = _db.db.select('SELECT * FROM movimientos');
    d.movimientos = rows.map((r) => Movimiento.fromRow(rowMap(r))).toList();
    return d;
  }

  /// Total ganado por año.
  Map<int, double> totalGanadoPorAnio(List<Movimiento> movs) {
    final map = <int, double>{};
    for (final m in movs) {
      if (m.tipoMovimiento == 'APORTE_LABORAL') {
        map[m.anio] = (map[m.anio] ?? 0) + m.totalGanado;
      }
    }
    return map;
  }

  /// Total aportes (AFP) por año.
  Map<int, double> totalAportesPorAnio(List<Movimiento> movs) {
    final map = <int, double>{};
    for (final m in movs) {
      if (m.tipoMovimiento == 'APORTE_LABORAL') {
        map[m.anio] = (map[m.anio] ?? 0) + m.afp;
      }
    }
    return map;
  }

  Map<int, int> diasPorAnio(List<Movimiento> movs) {
    final map = <int, int>{};
    for (final m in movs) {
      if (m.tipoMovimiento == 'APORTE_LABORAL') {
        map[m.anio] = (map[m.anio] ?? 0) + m.diasTrabajados;
      }
    }
    return map;
  }

  Map<String, int> documentosPorMes() {
    final map = <String, int>{};
    final rows = _db.db.select(
      "SELECT strftime('%Y-%m', uploaded_at) AS m, COUNT(*) AS c FROM documentos GROUP BY m ORDER BY m",
    );
    for (final r in rows) {
      final rm = rowMap(r);
      map[(rm['m'] ?? '') as String] = (rm['c'] ?? 0) as int;
    }
    return map;
  }

  /// Detecta periodos faltantes en un rango dado para un trabajador.
  List<String> detectarPeriodosFaltantes(int trabajadorId, int anioDesde, int anioHasta) {
    final rep = DocumentoRepository().listarMovimientos(trabajadorId: trabajadorId);
    final presentes = <String>{};
    for (final m in rep) {
      if (m.tipoMovimiento == 'APORTE_LABORAL') {
        presentes.add('${m.anio}-${m.mes}');
      }
    }
    final faltantes = <String>[];
    for (var anio = anioDesde; anio <= anioHasta; anio++) {
      for (var mes = 1; mes <= 12; mes++) {
        if (!presentes.contains('$anio-$mes')) {
          faltantes.add('${mesNombre(mes)} $anio');
        }
      }
    }
    return faltantes;
  }

  static String mesNombre(int mes) {
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return meses[mes - 1];
  }
}
