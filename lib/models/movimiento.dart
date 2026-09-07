class Movimiento {
  final int? id;
  final int estadoAhorroId;
  final int trabajadorId;
  final int anio;
  final int mes;
  final String empleador;
  final String tipoMovimiento;
  final double totalGanado;
  final int diasTrabajados;
  final double cotizacionMensual;
  final double aporteVoluntario;
  final double aporteBeneficioSocial;
  final double comision;
  final double totalAportes;
  final double valorCuota;
  final double totalNumeroCuotas;
  final String fechaPago;
  double afp;
  double liquidoPagable;
  final double? originalTotalGanado;
  final double? originalAfp;
  final double? originalLiquido;
  final int? originalDias;
  final bool requiereRevision;

  Movimiento({
    this.id,
    required this.estadoAhorroId,
    required this.trabajadorId,
    required this.anio,
    required this.mes,
    this.empleador = '',
    this.tipoMovimiento = 'APORTE_LABORAL',
    this.totalGanado = 0,
    this.diasTrabajados = 0,
    this.cotizacionMensual = 0,
    this.aporteVoluntario = 0,
    this.aporteBeneficioSocial = 0,
    this.comision = 0,
    this.totalAportes = 0,
    this.valorCuota = 0,
    this.totalNumeroCuotas = 0,
    this.fechaPago = '',
    this.afp = 0,
    this.liquidoPagable = 0,
    this.originalTotalGanado,
    this.originalAfp,
    this.originalLiquido,
    this.originalDias,
    this.requiereRevision = false,
  });

  factory Movimiento.fromRow(Map<String, Object?> r) => Movimiento(
        id: r['id'] as int?,
        estadoAhorroId: (r['estado_ahorro_id'] ?? 0) as int,
        trabajadorId: (r['trabajador_id'] ?? 0) as int,
        anio: (r['anio'] ?? 0) as int,
        mes: (r['mes'] ?? 0) as int,
        empleador: (r['empleador'] ?? '') as String,
        tipoMovimiento: (r['tipo_movimiento'] ?? 'APORTE_LABORAL') as String,
        totalGanado: ((r['total_ganado'] ?? 0) as num).toDouble(),
        diasTrabajados: (r['dias_trabajados'] ?? 0) as int,
        cotizacionMensual: ((r['cotizacion_mensual'] ?? 0) as num).toDouble(),
        aporteVoluntario: ((r['aporte_voluntario'] ?? 0) as num).toDouble(),
        aporteBeneficioSocial: ((r['aporte_beneficio_social'] ?? 0) as num).toDouble(),
        comision: ((r['comision'] ?? 0) as num).toDouble(),
        totalAportes: ((r['total_aportes'] ?? 0) as num).toDouble(),
        valorCuota: ((r['valor_cuota'] ?? 0) as num).toDouble(),
        totalNumeroCuotas: ((r['total_numero_cuotas'] ?? 0) as num).toDouble(),
        fechaPago: (r['fecha_pago'] ?? '') as String,
        afp: ((r['afp'] ?? 0) as num).toDouble(),
        liquidoPagable: ((r['liquido_pagable'] ?? 0) as num).toDouble(),
        originalTotalGanado: (r['original_total_ganado'] as num?)?.toDouble(),
        originalAfp: (r['original_afp'] as num?)?.toDouble(),
        originalLiquido: (r['original_liquido'] as num?)?.toDouble(),
        originalDias: r['original_dias'] as int?,
        requiereRevision: (r['requiere_revision'] ?? 0) == 1,
      );

  String get mesNombre {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return (mes >= 1 && mes <= 12) ? meses[mes - 1] : '$mes';
  }

  String get periodoDisplay => '$mesNombre $anio';
}
