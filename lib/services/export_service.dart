import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/registro_extraido.dart';

class ExportService {
  static Future<String?> exportarXlsx(
    List<RegistroExtraido> registros,
    String nombreBase,
  ) async {
    if (registros.isEmpty) return null;

    final sugerido = '$nombreBase${_sufijoArchivo()}.xlsx';
    final destino = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Certificado de Aportaciones',
      fileName: sugerido,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (destino == null) return null;

    final excel = _buildExcel(registros);
    final bytes = excel.encode() ?? <int>[];
    var ruta = destino;
    if (!ruta.toLowerCase().endsWith('.xlsx')) ruta += '.xlsx';
    File(ruta).writeAsBytesSync(bytes);
    return ruta;
  }

  static Excel _buildExcel(List<RegistroExtraido> registros) {
    final excel = Excel.createExcel();
    final defSheet = excel.getDefaultSheet();
    if (defSheet != null) excel.rename(defSheet, 'Certificado');
    final sheet = excel['Certificado'];

    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 14);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 18);
    sheet.setColumnWidth(6, 18);

    final nombre = registros.isNotEmpty ? registros.first.nombres : '';
    final ci = registros.isNotEmpty ? registros.first.ci : '';

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('DCE6D1'),
      horizontalAlign: HorizontalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
    );

    final dataStyle = CellStyle(
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
    );

    final boldStyle = CellStyle(
      bold: true,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
    );

    int row = 1;

    _set(sheet, 0, row, 'EMAP/RR.HH./${DateTime.now().year}', bold: true);
    row += 2;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    _set(sheet, 0, row, 'CERTIFICADO DE APORTACIONES', bold: true, center: true, fontSize: 14);
    row += 2;

    _set(sheet, 0, row, 'DATOS PERSONALES:', bold: true);
    _set(sheet, 3, row, nombre, bold: true);
    row++;
    _set(sheet, 0, row, 'C.I.:');
    _set(sheet, 1, row, ci);
    _set(sheet, 3, row, 'ITEM:');
    row += 2;

    const dataHeaders = [
      'AÑO', 'FECHA', 'TOTAL GANADO',
      'APORTES A.F.P.', 'LÍQUIDO PAGABLE', 'DÍAS TRABAJADOS'
    ];
    for (var c = 0; c < dataHeaders.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
      );
      cell.value = TextCellValue(dataHeaders[c]);
      cell.cellStyle = headerStyle;
    }
    row++;

    final agrupados = _agrupar(registros);
    final anios = agrupados.keys.toList()..sort();

    for (final anio in anios) {
      final meses = agrupados[anio]!.keys.toList()..sort();
      for (final mes in meses) {
        final r = agrupados[anio]![mes]!;
        _setDataCell(sheet, 0, row, '$anio', dataStyle);
        _setDataCell(sheet, 1, row, '$mes', dataStyle);
        _setDataCell(sheet, 2, row, _fmtNum(r.totalGanado), dataStyle);
        _setDataCell(sheet, 3, row, _fmtNum(r.aportesAfp), dataStyle);
        _setDataCell(sheet, 4, row, _fmtNum(r.liquidoPagable), dataStyle);
        _setDataCell(sheet, 5, row, '${r.diasTrabajados}', dataStyle);
        if (mes == meses.last) {
          _setDataCell(sheet, 6, row, 'Tot GES $anio', boldStyle);
        }
        row++;
      }
    }

    row += 2;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    _set(sheet, 0, row, 'CERTIFICADO DE APORTACIONES', bold: true, center: true, fontSize: 12);
    row++;

    const sumHeaders = [
      'AÑO', 'DESDE', 'HASTA', 'NUMERO DE COTIZACIONES', 'APORTE EN'
    ];
    for (var c = 0; c < sumHeaders.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
      );
      cell.value = TextCellValue(sumHeaders[c]);
      cell.cellStyle = headerStyle;
    }
    row++;

    int totalMesesAll = 0;
    int totalDiasAll = 0;

    for (final anio in anios) {
      final mesesData = agrupados[anio]!;
      final mesesSorted = mesesData.keys.toList()..sort();

      final desde = RegistroExtraido(mes: mesesSorted.first, anio: anio).mesNombre;
      final hasta = RegistroExtraido(mes: mesesSorted.last, anio: anio).mesNombre;

      int diasAnio = 0;
      for (final m in mesesSorted) {
        diasAnio += mesesData[m]!.diasTrabajados;
      }

      final meses = diasAnio ~/ 30;
      final dias = diasAnio % 30;

      totalMesesAll += meses;
      totalDiasAll += dias;

      _setDataCell(sheet, 0, row, '$anio', dataStyle);
      _setDataCell(sheet, 1, row, desde, dataStyle);
      _setDataCell(sheet, 2, row, hasta, dataStyle);
      _setDataCell(sheet, 3, row, '$meses MESES', dataStyle);
      _setDataCell(sheet, 4, row, dias > 0 ? '$dias DIAS' : '', dataStyle);
      row++;
    }

    totalMesesAll += totalDiasAll ~/ 30;
    totalDiasAll = totalDiasAll % 30;

    final aniosTotal = totalMesesAll ~/ 12;
    final mesesTotal = totalMesesAll % 12;

    row++;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    _set(sheet, 0, row, '_________________________________');
    row++;

    _setDataCell(sheet, 0, row, '', boldStyle);
    _setDataCell(sheet, 1, row, 'TOTAL', boldStyle);
    String totalCorto = '$aniosTotal AÑOS';
    if (mesesTotal > 0) totalCorto += ' $mesesTotal MESES';
    _setDataCell(sheet, 2, row, totalCorto, boldStyle);
    if (totalDiasAll > 0) {
      _setDataCell(sheet, 3, row, '$totalDiasAll DIAS', boldStyle);
    }
    row += 2;

    String totalLargo = '';
    if (aniosTotal > 0) {
      totalLargo += '$aniosTotal año${aniosTotal > 1 ? 's' : ''}';
    }
    if (mesesTotal > 0) {
      if (totalLargo.isNotEmpty) totalLargo += ', ';
      totalLargo += '$mesesTotal mes${mesesTotal > 1 ? 'es' : ''}';
    }
    if (totalDiasAll > 0) {
      if (totalLargo.isNotEmpty) totalLargo += ' y ';
      totalLargo += '$totalDiasAll día${totalDiasAll > 1 ? 's' : ''}';
    }

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(sheet, 0, row,
        'EL FUNCIONARIO $nombre, trabaja $totalLargo', bold: true);
    row += 2;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(sheet, 0, row,
        'ES CUANTO CERTIFICO PARA FINES CONSIGUIENTES DEL INTERESADO');
    row += 2;

    final ahora = DateTime.now();
    const mesesNom = [
      'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
      'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'
    ];
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(sheet, 0, row,
        'Potosí, ${ahora.day} de ${mesesNom[ahora.month - 1]} de ${ahora.year}');
    row += 3;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
    );
    _set(sheet, 0, row, '_________________');
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(sheet, 4, row, '_________________');
    row++;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
    );
    _set(sheet, 0, row, 'ENCARGADO DE ARCHIVOS EMAP',
        bold: false, fontSize: 8, center: true);
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(sheet, 4, row, 'ENCARGADO DE PLANILLAS EMAP',
        bold: false, fontSize: 8, center: true);
    row += 2;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    _set(sheet, 2, row, '_________________');
    row++;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    _set(sheet, 2, row, 'DIR. ADM. Y FINANCIERA EMAP',
        bold: false, fontSize: 8, center: true);

    return excel;
  }

  static Map<int, Map<int, RegistroExtraido>> _agrupar(
      List<RegistroExtraido> registros) {
    final Map<int, Map<int, RegistroExtraido>> resultado = {};
    for (final r in registros) {
      resultado.putIfAbsent(r.anio, () => {});
      final meses = resultado[r.anio]!;
      final prev = meses[r.mes];
      if (prev == null) {
        meses[r.mes] = RegistroExtraido(
          archivo: r.archivo,
          ci: r.ci,
          nombres: r.nombres,
          cua: r.cua,
          empleador: r.empleador,
          mes: r.mes,
          anio: r.anio,
          totalGanado: r.totalGanado,
          aportesAfp: r.aportesAfp,
          liquidoPagable: r.liquidoPagable,
          diasTrabajados: r.diasTrabajados,
          fechaProceso: r.fechaProceso,
        );
      } else {
        meses[r.mes] = RegistroExtraido(
          archivo: prev.archivo,
          ci: prev.ci,
          nombres: prev.nombres,
          cua: prev.cua,
          empleador: prev.empleador,
          mes: prev.mes,
          anio: prev.anio,
          totalGanado: prev.totalGanado + r.totalGanado,
          aportesAfp: prev.aportesAfp + r.aportesAfp,
          liquidoPagable: prev.liquidoPagable + r.liquidoPagable,
          diasTrabajados:
              r.diasTrabajados > prev.diasTrabajados ? r.diasTrabajados : prev.diasTrabajados,
          fechaProceso: r.fechaProceso,
        );
      }
    }
    return resultado;
  }

  static String _fmtNum(double v) {
    final fixed = v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
    }
    return '$buffer,$decPart';
  }

  static void _set(Sheet sheet, int col, int row, String text,
      {bool bold = false, bool center = false, int? fontSize}) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(
      bold: bold,
      horizontalAlign:
          center ? HorizontalAlign.Center : HorizontalAlign.Left,
      fontSize: fontSize,
    );
  }

  static void _setDataCell(Sheet sheet, int col, int row, String text, CellStyle style) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(text);
    cell.cellStyle = style;
  }

  static String _sufijoArchivo() {
    final n = DateTime.now();
    return '_${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}_${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
  }
}
