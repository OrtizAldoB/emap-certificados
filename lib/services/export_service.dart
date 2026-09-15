import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/registro_extraido.dart';

/// Genera el archivo .xlsx con los datos extraidos de los PDFs.
class ExportService {
  static String _num(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);

  /// Pide al usuario donde guardar y escribe el .xlsx.
  /// Devuelve la ruta del archivo generado, o null si se cancelo.
  static Future<String?> exportarXlsx(
    List<RegistroExtraido> registros,
    String nombreBase,
  ) async {
    if (registros.isEmpty) return null;

    final sugerido = '$nombreBase${_sufijoArchivo()}.xlsx';
    final destino = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar archivo Excel',
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
    final sheet = excel['Aportaciones'];
    sheet.setDefaultColumnWidth(18);

    int row = 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue('ENTIDAD MUNICIPAL DE ASEO POTOSÍ');
    row++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue('REGISTRO DE APORTACIONES - ESTADOS DE AHORRO PREVISIONAL');
    row += 2;

    const headers = ['AÑO', 'MES', 'TOTAL GANADO', 'APORTES A.F.P.', 'LIQUIDO PAGABLE', 'DIAS TRABAJADOS'];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('DCE6D1'),
        rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
        bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('000000')),
      );
    }
    row++;

    for (final r in registros) {
      final cRow = row;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: cRow)).value = TextCellValue('${r.anio}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: cRow)).value = TextCellValue('${r.mes}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: cRow)).value = TextCellValue(_num(r.totalGanado));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: cRow)).value = TextCellValue(_num(r.aportesAfp));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: cRow)).value = TextCellValue(_num(r.liquidoPagable));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: cRow)).value = TextCellValue('${r.diasTrabajados}');
      row++;
    }

    double g = 0, a = 0, l = 0;
    int d = 0;
    for (final r in registros) {
      g += r.totalGanado;
      a += r.aportesAfp;
      l += r.liquidoPagable;
      d += r.diasTrabajados;
    }
    row++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('TOTAL');
    final cTotG = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)); cTotG.value = TextCellValue(_num(g)); cTotG.cellStyle = CellStyle(bold: true);
    final cTotA = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)); cTotA.value = TextCellValue(_num(a)); cTotA.cellStyle = CellStyle(bold: true);
    final cTotL = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)); cTotL.value = TextCellValue(_num(l)); cTotL.cellStyle = CellStyle(bold: true);
    final cTotD = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)); cTotD.value = TextCellValue('$d'); cTotD.cellStyle = CellStyle(bold: true);

    return excel;
  }

  static String _sufijoArchivo() {
    final n = DateTime.now();
    return '_${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}_${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
  }
}