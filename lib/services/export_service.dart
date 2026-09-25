import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../models/registro_extraido.dart';

class ResumenAnualAportes {
  final int anio;
  final String desde;
  final String hasta;
  final int cotizaciones;
  final int diasPendientes;

  const ResumenAnualAportes({
    required this.anio,
    required this.desde,
    required this.hasta,
    required this.cotizaciones,
    required this.diasPendientes,
  });
}

class ResumenCertificadoAportes {
  final List<ResumenAnualAportes> anios;
  final int cotizaciones;
  final int diasPendientes;
  final int aniosCompletos;
  final int mesesResiduales;

  const ResumenCertificadoAportes({
    required this.anios,
    required this.cotizaciones,
    required this.diasPendientes,
    required this.aniosCompletos,
    required this.mesesResiduales,
  });

  bool get tieneDatos => anios.isNotEmpty;
}

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

    final bytes = await generarXlsxBytes(registros);
    var ruta = destino;
    if (!ruta.toLowerCase().endsWith('.xlsx')) ruta += '.xlsx';
    File(ruta).writeAsBytesSync(bytes);
    return ruta;
  }

  static Future<List<int>> generarXlsxBytes(
    List<RegistroExtraido> registros,
  ) async {
    final excel = _buildExcel(registros);
    return _agregarLogos(excel.encode() ?? <int>[]);
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
      leftBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      rightBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      topBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
    );

    final dataStyle = CellStyle(
      leftBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      rightBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      topBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
    );

    final boldStyle = CellStyle(
      bold: true,
      leftBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      rightBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      topBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('000000'),
      ),
    );

    int row = 1;

    _set(sheet, 0, row, 'EMAP/RR.HH./${DateTime.now().year}', bold: true);
    row += 2;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    _set(
      sheet,
      0,
      row,
      'CERTIFICADO DE APORTACIONES',
      bold: true,
      center: true,
      fontSize: 14,
    );
    row += 2;

    _set(sheet, 0, row, 'DATOS PERSONALES:', bold: true);
    _set(sheet, 3, row, nombre, bold: true);
    row++;
    _set(sheet, 0, row, 'C.I.:');
    _set(sheet, 1, row, ci);
    _set(sheet, 3, row, 'ITEM:');
    row += 2;

    const dataHeaders = [
      'AÑO',
      'MES',
      'TOTAL GANADO',
      'APORTES A.F.P.',
      'LÍQUIDO PAGABLE',
      'DÍAS TRABAJADOS',
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
        _setDataCell(sheet, 1, row, RegistroExtraido.nombreMes(mes), dataStyle);
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
    _set(
      sheet,
      0,
      row,
      'CERTIFICADO DE APORTACIONES',
      bold: true,
      center: true,
      fontSize: 12,
    );
    row++;

    const sumHeaders = [
      'AÑO',
      'DESDE',
      'HASTA',
      'NUMERO DE COTIZACIONES',
      'APORTE EN',
    ];
    for (var c = 0; c < sumHeaders.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
      );
      cell.value = TextCellValue(sumHeaders[c]);
      cell.cellStyle = headerStyle;
    }
    row++;

    final resumen = calcularResumenAportes(registros);

    for (final item in resumen.anios) {
      _setDataCell(sheet, 0, row, '${item.anio}', dataStyle);
      _setDataCell(sheet, 1, row, item.desde, dataStyle);
      _setDataCell(sheet, 2, row, item.hasta, dataStyle);
      _setDataCell(
        sheet,
        3,
        row,
        '${item.cotizaciones} ${item.cotizaciones == 1 ? 'MES' : 'MESES'}',
        dataStyle,
      );
      _setDataCell(
        sheet,
        4,
        row,
        item.diasPendientes > 0
            ? '${item.diasPendientes} ${item.diasPendientes == 1 ? 'DÍA' : 'DÍAS'}'
            : '',
        dataStyle,
      );
      row++;
    }

    final totalDiasAll = resumen.diasPendientes;
    final aniosTotal = resumen.aniosCompletos;
    final mesesTotal = resumen.mesesResiduales;

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
    _set(
      sheet,
      0,
      row,
      'EL FUNCIONARIO $nombre, trabaja $totalLargo',
      bold: true,
    );
    row += 2;

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(
      sheet,
      0,
      row,
      'ES CUANTO CERTIFICO PARA FINES CONSIGUIENTES DEL INTERESADO',
    );
    row += 2;

    final ahora = DateTime.now();
    const mesesNom = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(
      sheet,
      0,
      row,
      'Potosí, ${ahora.day} de ${mesesNom[ahora.month - 1]} de ${ahora.year}',
    );
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
    _set(
      sheet,
      0,
      row,
      'ENCARGADO DE ARCHIVOS EMAP',
      bold: false,
      fontSize: 8,
      center: true,
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    _set(
      sheet,
      4,
      row,
      'ENCARGADO DE PLANILLAS EMAP',
      bold: false,
      fontSize: 8,
      center: true,
    );
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
    _set(
      sheet,
      2,
      row,
      'DIR. ADM. Y FINANCIERA EMAP',
      bold: false,
      fontSize: 8,
      center: true,
    );

    return excel;
  }

  static ResumenCertificadoAportes calcularResumenAportes(
    List<RegistroExtraido> registros,
  ) {
    final agrupados = _agrupar(registros);
    final anios = agrupados.keys.toList()..sort();
    final filas = <ResumenAnualAportes>[];
    var pendientes = 0;
    var totalCotizaciones = 0;

    for (final anio in anios) {
      final meses = agrupados[anio]!.keys.toList()..sort();
      final mesesConDias = meses
          .where((mes) => agrupados[anio]![mes]!.diasTrabajados > 0)
          .toList();
      if (mesesConDias.isEmpty) continue;

      var cotizacionesAnio = 0;
      for (final mes in mesesConDias) {
        final dias = agrupados[anio]![mes]!.diasTrabajados;
        final acumulado = pendientes + dias;
        cotizacionesAnio += acumulado ~/ 30;
        pendientes = acumulado % 30;
      }

      totalCotizaciones += cotizacionesAnio;
      filas.add(
        ResumenAnualAportes(
          anio: anio,
          desde: RegistroExtraido.nombreMes(mesesConDias.first),
          hasta: RegistroExtraido.nombreMes(mesesConDias.last),
          cotizaciones: cotizacionesAnio,
          diasPendientes: pendientes,
        ),
      );
    }

    return ResumenCertificadoAportes(
      anios: filas,
      cotizaciones: totalCotizaciones,
      diasPendientes: pendientes,
      aniosCompletos: totalCotizaciones ~/ 12,
      mesesResiduales: totalCotizaciones % 12,
    );
  }

  static Map<int, Map<int, RegistroExtraido>> _agrupar(
    List<RegistroExtraido> registros,
  ) {
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
          diasTrabajados: (prev.diasTrabajados + r.diasTrabajados) > 30
              ? 30
              : prev.diasTrabajados + r.diasTrabajados,
          fechaProceso: r.fechaProceso,
        );
      }
    }
    return resultado;
  }

  static Future<List<int>> _agregarLogos(List<int> bytes) async {
    const configuracion = [
      (
        ruta: 'assets/logos/logo1.png',
        archivo: 'xl/media/logo1.png',
        columnaDesde: 0,
        columnaHasta: 2,
      ),
      (
        ruta: 'assets/logos/logo2.png',
        archivo: 'xl/media/logo2.png',
        columnaDesde: 4,
        columnaHasta: 6,
      ),
    ];

    final logos =
        <
          ({
            String archivo,
            int columnaDesde,
            int columnaHasta,
            Uint8List contenido,
          })
        >[];

    for (final logo in configuracion) {
      try {
        final data = await rootBundle.load(logo.ruta);
        logos.add((
          archivo: logo.archivo,
          columnaDesde: logo.columnaDesde,
          columnaHasta: logo.columnaHasta,
          contenido: Uint8List.view(
            data.buffer,
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        ));
      } catch (_) {}
    }

    if (logos.isEmpty) {
      return bytes;
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    const sheetPath = 'xl/worksheets/sheet1.xml';
    if (archive.findFile(sheetPath) == null) {
      return bytes;
    }

    final existingDrawingPath = _existingDrawingPath(archive);
    final drawingPath = existingDrawingPath ?? _nextDrawingPath(archive);
    var drawingXml = existingDrawingPath == null
        ? ''
        : _leerXml(archive, drawingPath);
    if (existingDrawingPath != null && drawingXml.isEmpty) {
      return bytes;
    }

    final drawingRelsPath =
        'xl/drawings/_rels/${drawingPath.split('/').last}.rels';
    var drawingRels = _leerXml(archive, drawingRelsPath);
    if (drawingRels.isEmpty) {
      drawingRels =
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>';
    }

    _asegurarDrawingEnHoja(archive, sheetPath, drawingPath);

    final ids = RegExp(
      r'<xdr:cNvPr\s+id="(\d+)"',
    ).allMatches(drawingXml).map((match) => int.parse(match.group(1)!));
    final firstDrawingId = ids.isEmpty
        ? 1
        : ids.reduce((a, b) => a > b ? a : b) + 1;
    final anchors = <String>[];

    for (var i = 0; i < logos.length; i++) {
      final logo = logos[i];
      var relId = 'rIdLogo${i + 1}';
      while (drawingRels.contains('Id="$relId"')) {
        relId = '${relId}_';
      }
      drawingRels = drawingRels.replaceFirst(
        '</Relationships>',
        '<Relationship Id="$relId" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
            'Target="../media/${logo.archivo.split('/').last}"/>'
            '</Relationships>',
      );
      anchors.add(
        _anchorLogo(
          id: firstDrawingId + i,
          relId: relId,
          columnaDesde: logo.columnaDesde,
          columnaHasta: logo.columnaHasta,
        ),
      );
      archive.addFile(
        ArchiveFile(logo.archivo, logo.contenido.length, logo.contenido),
      );
    }

    if (drawingXml.isEmpty) {
      drawingXml =
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
          'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '${anchors.join()}</xdr:wsDr>';
    } else if (drawingXml.contains('</xdr:wsDr>')) {
      drawingXml = drawingXml.replaceFirst(
        '</xdr:wsDr>',
        '${anchors.join()}</xdr:wsDr>',
      );
    } else {
      drawingXml = drawingXml.replaceFirst(
        '/>',
        '>${anchors.join()}</xdr:wsDr>',
      );
    }

    _reemplazarXml(archive, drawingPath, drawingXml);
    _reemplazarXml(archive, drawingRelsPath, drawingRels);

    var contentTypes = _leerXml(archive, '[Content_Types].xml');
    if (!contentTypes.contains('Extension="png"')) {
      contentTypes = contentTypes.replaceFirst(
        '</Types>',
        '<Default Extension="png" ContentType="image/png"/></Types>',
      );
    }
    if (existingDrawingPath == null) {
      contentTypes = contentTypes.replaceFirst(
        '</Types>',
        '<Override PartName="/$drawingPath" '
            'ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>',
      );
    }
    _reemplazarXml(archive, '[Content_Types].xml', contentTypes);

    return ZipEncoder().encode(archive) ?? bytes;
  }

  static void _asegurarDrawingEnHoja(
    Archive archive,
    String sheetPath,
    String drawingPath,
  ) {
    var sheetXml = _leerXml(archive, sheetPath);
    if (!sheetXml.contains('xmlns:r=')) {
      sheetXml = sheetXml.replaceFirst(
        '<worksheet',
        '<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"',
      );
    }

    final sheetRelsPath =
        'xl/worksheets/_rels/${sheetPath.split('/').last}.rels';
    var sheetRels = _leerXml(archive, sheetRelsPath);
    if (sheetRels.isEmpty) {
      sheetRels =
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>';
    }

    if (!sheetXml.contains('<drawing ')) {
      final target = '../drawings/${drawingPath.split('/').last}';
      final relation = RegExp(
        '<Relationship\\b(?=[^>]*\\bType="[^"]*/drawing")'
        '(?=[^>]*\\bTarget="${RegExp.escape(target)}")'
        '[^>]*\\bId="([^"]+)"',
      ).firstMatch(sheetRels);
      var relId = relation?.group(1);
      if (relId == null) {
        final ids = RegExp(
          r'Id="rId(\d+)"',
        ).allMatches(sheetRels).map((match) => int.parse(match.group(1)!));
        relId =
            'rId${ids.isEmpty ? 1 : ids.reduce((a, b) => a > b ? a : b) + 1}';
        sheetRels = sheetRels.replaceFirst(
          '</Relationships>',
          '<Relationship Id="$relId" '
              'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" '
              'Target="$target"/></Relationships>',
        );
      }
      sheetXml = sheetXml.replaceFirst(
        '</worksheet>',
        '<drawing r:id="$relId"/></worksheet>',
      );
    }

    _reemplazarXml(archive, sheetPath, sheetXml);
    _reemplazarXml(archive, sheetRelsPath, sheetRels);
  }

  static String? _existingDrawingPath(Archive archive) {
    final sheetRels = _leerXml(archive, 'xl/worksheets/_rels/sheet1.xml.rels');
    final match = RegExp(
      r'<Relationship\b[^>]*Type="[^"]*/drawing"[^>]*Target="\.\./drawings/([^"]+)"',
    ).firstMatch(sheetRels);
    if (match == null) return null;
    final path = 'xl/drawings/${match.group(1)}';
    return archive.findFile(path) == null ? null : path;
  }

  static String _nextDrawingPath(Archive archive) {
    var number = 1;
    while (archive.findFile('xl/drawings/drawing$number.xml') != null) {
      number++;
    }
    return 'xl/drawings/drawing$number.xml';
  }

  static String _anchorLogo({
    required int id,
    required String relId,
    required int columnaDesde,
    required int columnaHasta,
  }) {
    return '<xdr:twoCellAnchor>'
        '<xdr:from><xdr:col>$columnaDesde</xdr:col><xdr:colOff>0</xdr:colOff>'
        '<xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>'
        '<xdr:to><xdr:col>$columnaHasta</xdr:col><xdr:colOff>0</xdr:colOff>'
        '<xdr:row>2</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>'
        '<xdr:pic><xdr:nvPicPr><xdr:cNvPr id="$id" name="Logo $id"/>'
        '<xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>'
        '<xdr:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/>'
        '</a:stretch></xdr:blipFill><xdr:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="0" cy="0"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/>'
        '</a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:twoCellAnchor>';
  }

  static String _leerXml(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) return '';
    final content = file.content;
    if (content is Uint8List) return utf8.decode(content);
    if (content is List<int>) {
      return utf8.decode(content);
    }
    return '';
  }

  static void _reemplazarXml(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
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

  static void _set(
    Sheet sheet,
    int col,
    int row,
    String text, {
    bool bold = false,
    bool center = false,
    int? fontSize,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(
      bold: bold,
      horizontalAlign: center ? HorizontalAlign.Center : HorizontalAlign.Left,
      fontSize: fontSize,
    );
  }

  static void _setDataCell(
    Sheet sheet,
    int col,
    int row,
    String text,
    CellStyle style,
  ) {
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
