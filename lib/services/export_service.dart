import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../models/movimiento.dart';
import '../models/trabajador.dart';
import '../repositories/configuracion_repository.dart';

/// Generacion de Excel (.xlsx) y PDF con apariencia institucional EMAP.
class ExportService {
  static final _config = ConfiguracionRepository();

  static Future<String?> _directorioSalida() async {
    final configDir = _config.get('trabajador_ruta_pdf', '');
    if (configDir.isNotEmpty) {
      final d = Directory(configDir);
      if (await d.exists()) return configDir;
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads.path;
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  static String _num(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);

  // ---------- EXCEL ----------

  static Future<String?> exportarExcel(
    List<Movimiento> movimientos,
    String nombreBase, {
    Trabajador? trabajador,
  }) async {
    final dir = await _directorioSalida();
    final excel = _buildExcel(movimientos, trabajador: trabajador);
    final path = p.join(dir!, '${nombreBase}_${_fechaArchivo()}.xlsx');
    final bytes = excel.encode() ?? <int>[];
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  static Excel _buildExcel(List<Movimiento> movs, {Trabajador? trabajador}) {
    final excel = Excel.createExcel();
    final sheet = excel['Certificado'];
    sheet.setDefaultColumnWidth(18);

    int row = 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue('ENTIDAD MUNICIPAL DE ASEO POTOSÍ');
    row++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue('CERTIFICADO DE APORTACIONES');
    row += 2;
    if (trabajador != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Trabajador: ${trabajador.nombreCompleto}');
      row++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('C.I.: ${trabajador.ci}     CUA: ${trabajador.cua}');
      row += 2;
    }

    const headers = ['AÑO', 'FECHA', 'TOTAL GANADO', 'APORTES A.F.P.', 'LIQUIDO PAGABLE', 'DIAS TRABAJADOS'];
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

    for (final m in movs) {
      final cRow = row;
      final fecha = '${m.mes.toString().padLeft(2, '0')}/${m.anio}';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: cRow)).value = TextCellValue('${m.anio}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: cRow)).value = TextCellValue(fecha);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: cRow)).value = TextCellValue(_num(m.totalGanado));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: cRow)).value = TextCellValue(_num(m.afp));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: cRow)).value = TextCellValue(_num(m.liquidoPagable));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: cRow)).value = TextCellValue('${m.diasTrabajados}');
      row++;
    }

    // Totales
    double g = 0, a = 0, l = 0;
    int d = 0;
    for (final m in movs) { g += m.totalGanado; a += m.afp; l += m.liquidoPagable; d += m.diasTrabajados; }
    row++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('TOTAL');
    final cTotG = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)); cTotG.value = TextCellValue(_num(g)); cTotG.cellStyle = CellStyle(bold: true);
    final cTotA = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)); cTotA.value = TextCellValue(_num(a)); cTotA.cellStyle = CellStyle(bold: true);
    final cTotL = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)); cTotL.value = TextCellValue(_num(l)); cTotL.cellStyle = CellStyle(bold: true);
    final cTotD = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)); cTotD.value = TextCellValue('$d'); cTotD.cellStyle = CellStyle(bold: true);
    row += 3;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Fecha de emisión: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');

    return excel;
  }

  // ---------- PDF ----------

  static Future<String?> exportarPdf(
    List<Movimiento> movimientos,
    String nombreBase, {
    Trabajador? trabajador,
  }) async {
    final pdfDoc = _buildPdfDocument(movimientos, trabajador: trabajador);
    final bytes = await pdfDoc.save();
    final dir = await _directorioSalida();
    final path = p.join(dir!, '${nombreBase}_${_fechaArchivo()}.pdf');
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  static Future<void> imprimirPdf(
    List<Movimiento> movimientos, {
    Trabajador? trabajador,
  }) async {
    final pdfDoc = _buildPdfDocument(movimientos, trabajador: trabajador);
    await Printing.layoutPdf(onLayout: (format) async => pdfDoc.save());
  }

  static pw.Document _buildPdfDocument(List<Movimiento> movs, {Trabajador? trabajador}) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              _config.get('entidad_nombre', 'ENTIDAD MUNICIPAL DE ASEO POTOSÍ'),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('CERTIFICADO DE APORTACIONES',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(color: PdfColors.grey),
          ],
        );
      },
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      ),
      build: (context) => [
        if (trabajador != null) ...[
          pw.Text('TRABAJADOR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Nombre: ${trabajador.nombreCompleto}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('C.I.: ${trabajador.ci}', style: const pw.TextStyle(fontSize: 11)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Cargo: ${trabajador.cargo}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Área: ${trabajador.area}', style: const pw.TextStyle(fontSize: 11)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('CUA: ${trabajador.cua}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Fecha de emisión: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const pw.TextStyle(fontSize: 11)),
          ]),
          pw.SizedBox(height: 16),
        ],
        pw.TableHelper.fromTextArray(
          headers: ['AÑO', 'FECHA', 'TOTAL GANADO', 'APORTES A.F.P.', 'LIQUIDO PAGABLE', 'DIAS'],
          data: movs.map((m) {
            final fecha = '${m.mes.toString().padLeft(2, '0')}/${m.anio}';
            return ['${m.anio}', fecha, _num(m.totalGanado), _num(m.afp), _num(m.liquidoPagable), '${m.diasTrabajados}'];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.center,
          },
        ),
        pw.SizedBox(height: 16),
        _totalesPdf(movs),
        pw.SizedBox(height: 60),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(children: [
              pw.Text('____________________________'),
              pw.Text('RESPONSABLE'),
            ]),
            pw.Column(children: [
              pw.Text('____________________________'),
              pw.Text('FIRMA Y SELLO'),
            ]),
          ],
        ),
      ],
    ));
    return doc;
  }

  static pw.Widget _totalesPdf(List<Movimiento> movs) {
    double g = 0, a = 0, l = 0;
    int d = 0;
    for (final m in movs) { g += m.totalGanado; a += m.afp; l += m.liquidoPagable; d += m.diasTrabajados; }
    final filas = <List<String>>[
      ['TOTAL GANADO:', 'Bs. ${_num(g)}'],
      ['TOTAL APORTES AFP:', 'Bs. ${_num(a)}'],
      ['TOTAL LIQUIDO PAGABLE:', 'Bs. ${_num(l)}'],
      ['TOTAL DIAS TRABAJADOS:', '$d'],
    ];
    final children = <pw.Widget>[];
    for (final f in filas) {
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(f[0], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text(f[1], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ],
        ),
      ));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _fechaArchivo() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}_${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
  }
}
