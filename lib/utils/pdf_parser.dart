// Parser del ESTADO DE AHORRO PREVISIONAL de la Gestora Publica de Bolivia.
// No depende de posiciones fijas: usa encabezados, palabras clave, regex y contexto.

class ParsedPayment {
  String empleador;
  int mes;
  int anio;
  String tipoMovimiento;
  double totalGanado;
  int diasTrabajados;
  double aporteAfp;
  double liquidoPagable;
  double cotizacionMensual;
  double aporteVoluntario;
  double aporteBeneficioSocial;
  double comision;
  double totalAportes;
  double valorCuota;
  double totalNumeroCuotas;
  String fechaPago;
  bool requiereRevision;

  ParsedPayment({
    this.empleador = '',
    required this.mes,
    required this.anio,
    this.tipoMovimiento = 'APORTE_LABORAL',
    this.totalGanado = 0,
    this.diasTrabajados = 0,
    this.aporteAfp = 0,
    this.liquidoPagable = 0,
    this.cotizacionMensual = 0,
    this.aporteVoluntario = 0,
    this.aporteBeneficioSocial = 0,
    this.comision = 0,
    this.totalAportes = 0,
    this.valorCuota = 0,
    this.totalNumeroCuotas = 0,
    this.fechaPago = '',
    this.requiereRevision = false,
  });
}

class ParsedResult {
  Map<String, String> asegurado;
  List<ParsedPayment> movimientos;
  ParsedResult({required this.asegurado, required this.movimientos});
}

class PdfParser {
  static const Map<String, int> _months = {
    'ene': 1, 'feb': 2, 'mar': 3, 'abr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'ago': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dic': 12,
    'jan': 1, 'dec': 12,
  };

  static const _mesesList = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static String mesNombre(int mes) =>
      (mes >= 1 && mes <= 12) ? _mesesList[mes - 1] : '$mes';

  /// Periodo de cotizacion dentro del texto de una fila: "Abr-2024".
  static final RegExp _monthPeriodRe =
      RegExp(r'\b([A-Za-z]{3,9})-(\d{4})\b', caseSensitive: false);

  /// Fecha de pago: "15/05/2024".
  static final RegExp _dateRe = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b');

  /// Token numerico: "5,817.67", "0.00", "-0.75".
  static final RegExp _numTokenRe = RegExp(r'^-?[\d][\d.,]*$');

  /// Busca numeros dentro de un texto: "-0.75 841.1268".
  static final RegExp _numRe = RegExp(r'-?[\d][\d.,]*');

  /// Convierte "6.800,55" -> 6800.55, "5,817.67" -> 5817.67,
  /// "680,06" -> 680.06, "-0.75" -> -0.75.
  static double num(Object? s) {
    if (s == null) return 0;
    var t = s.toString().trim();
    t = t.replaceAll(RegExp(r'[^\d.,\-]'), '');
    if (t.isEmpty) return 0;
    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      // Ambos presentes: el separador decimal es el que aparece al final.
      if (lastComma > lastDot) {
        // decimal = coma, miles = punto: "6.800,55"
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // decimal = punto, miles = coma: "5,817.67"
        t = t.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      t = t.replaceAll(',', '.');
    }
    return double.tryParse(t) ?? 0;
  }

  /// Detecta un periodo tipo "Feb-2026", "Febrero 2026", "02/2026"
  static ({int mes, int anio})? parsePeriod(String text) {
    final m = RegExp(r'([A-Za-z]{3,9})\s*[-/]\s*(\d{4})', caseSensitive: false)
        .firstMatch(text);
    if (m != null) {
      final month = _months[m.group(1)!.toLowerCase().substring(0, 3)];
      final year = int.tryParse(m.group(2)!);
      if (month != null && year != null) return (mes: month, anio: year);
    }
    final dm = RegExp(r'[-/](\d{2})/(\d{4})').firstMatch(text);
    if (dm != null) {
      final month = int.tryParse(dm.group(1)!);
      final year = int.tryParse(dm.group(2)!);
      if (month != null && year != null && month >= 1 && month <= 12) {
        return (mes: month, anio: year);
      }
    }
    return null;
  }

  static String parseDate(String? s) {
    if (s == null) return '';
    final m = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})').firstMatch(s);
    if (m == null) return s;
    var year = m.group(3)!;
    if (year.length == 2) year = '20$year';
    return '$year-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
  }

  static bool isCommission(String text) {
    final t = text.toLowerCase();
    return t.contains('comision') || t.contains('comisión') || t.contains('cobro de comision');
  }

  static List<String> _normalizeLines(String text) {
    return text
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  static Map<String, String> _extractAsegurado(List<String> lines) {
    final joined = lines.join('\n');
    final out = {
      'nombres': '', 'apellidos': '', 'ci': '', 'cua': '',
      'periodo': '', 'numero': '', 'fechaEmision': '',
    };

    final nomM = RegExp(
            r'Nombres\s+y\s+Apellidos:\s*([A-ZÑÁÉÍÓÚ0-9][A-ZÑÁÉÍÓÚ0-9 ]*)',
            caseSensitive: false)
        .firstMatch(joined);
    if (nomM != null) {
      final palabras = nomM
          .group(1)!
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (palabras.isNotEmpty) {
        out['nombres'] =
            palabras.length >= 2 ? '${palabras[0]} ${palabras[1]}' : palabras[0];
        out['apellidos'] =
            palabras.length > 2 ? palabras.sublist(2).join(' ') : '';
      }
    }

    final ciM = RegExp(
            r'(?:C\.?I\.?|Cedula|Cédula|Documento\s+de\s+Identidad|Doc\.?\s*Identidad|N\.?\s*Doc)[:\s]*(?:[A-ZÑ]+[\s\-]*)?(\d{4,12})',
            caseSensitive: false)
        .firstMatch(joined);
    if (ciM != null) out['ci'] = ciM.group(1)!.trim();

    final cuaM = RegExp(
            r'(?:CUA|Cuenta\s+Única|cuenta\s+unica)[:\s#]*([A-Za-z0-9\-]{6,})',
            caseSensitive: false)
        .firstMatch(joined);
    if (cuaM != null) out['cua'] = cuaM.group(1)!.trim();

    final numM = RegExp(
            r'\bdel\s+[Ee]stado\s+[Dd]e\s+[Aa]horro\s+([A-Za-z0-9\-]{8,})',
            caseSensitive: false)
        .firstMatch(joined);
    if (numM != null) out['numero'] = numM.group(1)!.trim();

    final feM = RegExp(
            r'Fecha\s+de\s+(?:Emisi[oó]n|Emision)[^\d]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
            caseSensitive: false)
        .firstMatch(joined);
    if (feM != null) out['fechaEmision'] = parseDate(feM.group(1));

    final perM = RegExp(
            r'Periodo(?:\s+del\s+Estado\s+de\s+Ahorro)?\s*(\d{1,2}/\d{4}(?:\s*a\s+\d{1,2}/\d{4})?)',
            caseSensitive: false)
        .firstMatch(joined);
    if (perM != null) out['periodo'] = perM.group(1)!.trim();

    return out;
  }

  static bool _lineHasPeriod(String line) => parsePeriod(line) != null;

  static bool _isEmployerLine(String line) {
    return RegExp(r'^[A-ZÑÁÉÍÓÚ][A-ZÑÁÉÍÓÚ0-9&.\- ]{3,}$').hasMatch(line) &&
        !_lineHasPeriod(line);
  }

  static List<String> _splitMovementRows(List<String> section) {
    final rows = <String>[];
    final buf = StringBuffer();

    void flush() {
      final t = buf.toString().trim();
      if (t.isNotEmpty) rows.add(t);
      buf.clear();
    }

    for (final line in section) {
      final hasPeriod = _lineHasPeriod(line);
      if (hasPeriod) {
        if (buf.isNotEmpty) {
          buf.write('\n');
        }
        buf.write(line);
      } else if (_isEmployerLine(line)) {
        if (buf.isNotEmpty) flush();
        buf.write(line);
      } else {
        if (buf.isNotEmpty) buf.write('\n$line');
      }
    }
    flush();

    return rows.where((r) {
      final low = r.toLowerCase();
      if (low.contains('total ganado') && !_lineHasPeriod(r)) return false;
      if (low.contains('empleador / tipo de movimiento')) return false;
      return true;
    }).toList();
  }

  static ParsedPayment? _parseBlock(String block) {
    final period = parsePeriod(block);
    if (period == null) return null;

    final empM = RegExp(r'([A-ZÑÁÉÍÓÚ][A-ZÑÁÉÍÓÚ0-9&.\-/ ]{3,})').firstMatch(block);
    final fecha = RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})').firstMatch(block);

    return ParsedPayment(
      empleador: empM?.group(1)?.trim() ?? '',
      mes: period.mes,
      anio: period.anio,
      tipoMovimiento: isCommission(block) ? 'COMISION' : 'APORTE_LABORAL',
      totalGanado: num(RegExp(r'(?:total\s+ganado|ingreso\s+cotizable|total\s+ganado\s+o\s+ingreso)[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      diasTrabajados: int.tryParse(RegExp(r'(?:^|\s)(\d{1,2})\s*(?:d[ií]as)?(?:\s|$)', caseSensitive: false).firstMatch(block)?.group(1) ?? '') ?? 0,
      aporteAfp: num(RegExp(r'(?:aporte\s+)?(?:a\.?f\.?p\.?|afp)[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      liquidoPagable: num(RegExp(r'(?:l[ií]quido\s+(?:pagable|a\s+pagar|neto)|neto\s+(?:a\s+)?(?:pagar|pagable)|liquido\s+pagado)[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      cotizacionMensual: num(RegExp(r'cotizaci[oó]n\s+mensual[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      aporteVoluntario: num(RegExp(r'aporte\s+voluntario[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      aporteBeneficioSocial: num(RegExp(r'(?:aporte\s+)?beneficio\s+social[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      comision: num(RegExp(r'(?:comisi[oó]n|aporte\s+comisi[oó]n)[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      totalAportes: num(RegExp(r'total\s+aportes[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      valorCuota: num(RegExp(r'valor\s+cuota[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      totalNumeroCuotas: num(RegExp(r'total\s+n[úu]mero\s+de\s+cuotas[:\s]*([\d., ]+)', caseSensitive: false).firstMatch(block)?.group(1)),
      fechaPago: fecha?.group(1) ?? '',
    );
  }

  /// Parsea una fila de la tabla de movimientos tal como la extrae el PDF.
  ///
  /// Formato real (cada celda sale unida por espacios, por fila):
  ///   `"<Empleador> <Total Ganado> <Abr-2024> <15/05/2024> ` + 
  ///   `<30> <cotiz> <vol> <benef> <comision> <total aportes> <valor cuota> <num cuotas>"`
  ///
  /// En los "Cobro de comision" el "Total Ganado" (y a veces "Dias trabajados")
  /// salen vacios, por lo que se omiten columnas.
  static ParsedPayment? _parseMovementLine(String line) {
    final pm = _monthPeriodRe.firstMatch(line);
    if (pm == null) return null;
    final mes = _months[pm.group(1)!.toLowerCase().substring(0, 3)];
    final anio = int.tryParse(pm.group(2)!);
    if (mes == null || anio == null) return null;

    final dms = _dateRe.allMatches(line, pm.end).toList();
    if (dms.isEmpty) return null;
    final dm = dms.first;
    final dia = dm.group(1)!, mesNum = dm.group(2)!, anioDate = dm.group(3)!;
    final fechaPago =
        '$anioDate-${mesNum.padLeft(2, '0')}-${dia.padLeft(2, '0')}';

    final before = line.substring(0, pm.start).trim();
    final after = line.substring(dm.end).trim();
    if (before.isEmpty) return null;

    final antes = before.split(RegExp(r'\s+'));
    var employer = before;
    var totalGanado = 0.0;
    if (antes.isNotEmpty && _numTokenRe.hasMatch(antes.last)) {
      totalGanado = num(antes.last);
      employer = antes.sublist(0, antes.length - 1).join(' ');
    }

    final nums = _numRe
        .allMatches(after)
        .map((m) => num(m.group(0)!))
        .toList();

    var dias = 0;
    var cotizacion = 0.0, voluntario = 0.0, beneficioSocial = 0.0;
    var comision = 0.0, totalAportes = 0.0, valorCuota = 0.0, nroCuotas = 0.0;
    if (nums.length >= 8) {
      dias = nums[0].toInt();
      cotizacion = nums[1];
      voluntario = nums[2];
      beneficioSocial = nums[3];
      comision = nums[4];
      totalAportes = nums[5];
      valorCuota = nums[6];
      nroCuotas = nums[7];
    } else if (nums.length == 7) {
      // "Cobro de comision": la columna "Dias trabajados" va vacia.
      cotizacion = nums[0];
      voluntario = nums[1];
      beneficioSocial = nums[2];
      comision = nums[3];
      totalAportes = nums[4];
      valorCuota = nums[5];
      nroCuotas = nums[6];
    } else {
      return null;
    }

    return ParsedPayment(
      empleador: employer.trim(),
      mes: mes,
      anio: anio,
      tipoMovimiento: isCommission(line) ? 'COMISION' : 'APORTE_LABORAL',
      totalGanado: totalGanado,
      diasTrabajados: dias,
      cotizacionMensual: cotizacion,
      aporteVoluntario: voluntario,
      aporteBeneficioSocial: beneficioSocial,
      comision: comision,
      totalAportes: totalAportes,
      valorCuota: valorCuota,
      totalNumeroCuotas: nroCuotas,
      fechaPago: fechaPago,
    );
  }

  static ParsedResult parse(String text) {
    final lines = _normalizeLines(text);
    final asegurado = _extractAsegurado(lines);

    // Formato real: una linea por movimiento.
    final porLinea =
        lines.map(_parseMovementLine).whereType<ParsedPayment>().toList();

    List<ParsedPayment> movimientos;
    if (porLinea.isNotEmpty) {
      movimientos =
          porLinea.where((m) => m.tipoMovimiento != 'COMISION').toList();
    } else {
      // Respaldo: layout flexible por bloques (encabezados, palabras clave).
      final joined = lines.join('\n');
      final movIdx = lines
          .indexWhere((l) => RegExp(r'^movimiento', caseSensitive: false).hasMatch(l));
      final section = movIdx >= 0 ? lines.sublist(movIdx) : lines;
      movimientos = _splitMovementRows(section)
          .map(_parseBlock)
          .whereType<ParsedPayment>()
          .where((m) => m.anio != 0)
          .toList();
      if (movimientos.isEmpty) {
        final m = _parseBlock(joined);
        if (m != null && m.anio != 0) movimientos.add(m);
      }
    }

    // Marcar como requiere revision aquellos sin total ganado.
    for (final m in movimientos) {
      m.requiereRevision = m.totalGanado == 0 && m.tipoMovimiento != 'COMISION';
    }

    return ParsedResult(asegurado: asegurado, movimientos: movimientos);
  }
}
