/// Fila resultado de extraer un Estado de Ahorro Previsional desde un PDF.
/// Contiene exactamente los campos que el usuario solicito exportar.
class RegistroExtraido {
  String archivo;
  String ci;
  String nombres;
  String cua;
  String empleador;
  int mes;
  int anio;
  double totalGanado;
  double aportesAfp;
  double liquidoPagable;
  int diasTrabajados;
  String fechaProceso;

  RegistroExtraido({
    this.archivo = '',
    this.ci = '',
    this.nombres = '',
    this.cua = '',
    this.empleador = '',
    required this.mes,
    required this.anio,
    this.totalGanado = 0,
    this.aportesAfp = 0,
    this.liquidoPagable = 0,
    int diasTrabajados = 0,
    this.fechaProceso = '',
  }) : diasTrabajados = _normalizarDias(diasTrabajados);

  Map<String, dynamic> toJson() => {
    'archivo': archivo,
    'ci': ci,
    'nombres': nombres,
    'cua': cua,
    'empleador': empleador,
    'mes': mes,
    'anio': anio,
    'totalGanado': totalGanado,
    'aportesAfp': aportesAfp,
    'liquidoPagable': liquidoPagable,
    'diasTrabajados': diasTrabajados,
    'fechaProceso': fechaProceso,
  };

  factory RegistroExtraido.fromJson(Map<String, dynamic> j) => RegistroExtraido(
    archivo: j['archivo'] ?? '',
    ci: j['ci'] ?? '',
    nombres: j['nombres'] ?? '',
    cua: j['cua'] ?? '',
    empleador: j['empleador'] ?? '',
    mes: (j['mes'] as num?)?.toInt() ?? 0,
    anio: (j['anio'] as num?)?.toInt() ?? 0,
    totalGanado: (j['totalGanado'] as num?)?.toDouble() ?? 0,
    aportesAfp: (j['aportesAfp'] as num?)?.toDouble() ?? 0,
    liquidoPagable: (j['liquidoPagable'] as num?)?.toDouble() ?? 0,
    diasTrabajados: (j['diasTrabajados'] as num?)?.toInt() ?? 0,
    fechaProceso: j['fechaProceso'] ?? '',
  );

  static String nombreMes(int mes) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return (mes >= 1 && mes <= 12) ? meses[mes - 1] : '$mes';
  }

  String get mesNombre => nombreMes(mes);

  String get periodo => '$mesNombre $anio';
}

int _normalizarDias(int dias) => dias.clamp(0, 30);
