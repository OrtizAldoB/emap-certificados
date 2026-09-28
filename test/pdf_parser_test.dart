import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:emap/models/registro_extraido.dart';
import 'package:emap/services/export_service.dart';
import 'package:emap/utils/pdf_parser.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PdfParser', () {
    test('convierte numeros latinos correctamente', () {
      expect(PdfParser.num('6.800,55'), 6800.55);
      expect(PdfParser.num('5,817.67'), 5817.67);
      expect(PdfParser.num('680,06'), 680.06);
      expect(PdfParser.num('0,00'), 0.0);
      expect(PdfParser.num('34,00'), 34.0);
      expect(PdfParser.num('30'), 30.0);
      expect(PdfParser.num('45.0383'), 45.0383);
      expect(PdfParser.num('-0.75'), -0.75);
    });

    test('convierte enteros con separador de miles sin inventar decimales', () {
      expect(PdfParser.num('6.800'), 6800.0);
      expect(PdfParser.num('5.028'), 5028.0);
      expect(PdfParser.num('1.242.177,44'), 1242177.44);
      expect(PdfParser.num('1,200,000'), 1200000.0);
      expect(PdfParser.num('4.576'), 4576.0);
    });

    test('detecta periodo Feb-2026', () {
      final p = PdfParser.parsePeriod('Feb-2026');
      expect(p, isNotNull);
      expect(p!.mes, 2);
      expect(p.anio, 2026);
    });

    test('extrae movimientos de una fila real de la tabla del PDF', () {
      final texto = '''
ESTADO DE AHORRO PREVISIONAL
Nombres y Apellidos: KEVIN VLADIMIR ARI LIMACHI
Documento de Identidad: I 12718109 CUA: 49026112
MOVIMIENTO
CORPORACION MINERA DE BOLIVIA 5,817.67 Abr-2024 15/05/2024 30 581.77 0.00 0.00 29.09 610.86 835.3647 0.7312
Cobro de comisión Abr-2024 17/05/2024 0.00 0.00 0.00 -29.09 -29.09 835.4359 -0.0348
CORPORACION MINERA DE BOLIVIA 6,800.55 Feb-2026 16/03/2026 30 680.06 0.00 0.00 34.00 714.06 906.2041 0.7880
''';
      final r = PdfParser.parse(texto);
      expect(r.movimientos, hasLength(2));
      final m = r.movimientos[0];
      expect(m.empleador, 'CORPORACION MINERA DE BOLIVIA');
      expect(m.mes, 4);
      expect(m.anio, 2024);
      expect(m.totalGanado, 5817.67);
      expect(m.diasTrabajados, 30);
      expect(m.cotizacionMensual, 581.77);
      expect(m.comision, 29.09);
      expect(m.totalAportes, 610.86);
      expect(m.fechaPago, '2024-05-15');
      expect(m.requiereRevision, isFalse);
    });

    test('extrae datos del asegurado del encabezado real', () {
      final texto = '''
ESTADO DE AHORRO PREVISIONAL
INFORMACIÓN DEL ASEGURADO
Nombres y Apellidos: KEVIN VLADIMIR ARI LIMACHI
Documento de Identidad: I 12718109 CUA: 49026112
INFORMACIÓN DEL ESTADO DE AHORRO
Periodo del
Estado de Ahorro 04/2023 a 08/2026
Número del
Estado de Ahorro EAP26082114250005109
Fecha de Emisión
del Estado de Ahorro 21/08/2026
MOVIMIENTO
CORPORACION MINERA DE BOLIVIA 6,800.55 Feb-2026 16/03/2026 30 680.06 0.00 0.00 34.00 714.06 906.2041 0.7880
''';
      final r = PdfParser.parse(texto);
      expect(r.asegurado['nombres'], 'KEVIN VLADIMIR');
      expect(r.asegurado['apellidos'], 'ARI LIMACHI');
      expect(r.asegurado['ci'], '12718109');
      expect(r.asegurado['cua'], '49026112');
      expect(r.asegurado['periodo'], '04/2023 a 08/2026');
      expect(r.asegurado['numero'], 'EAP26082114250005109');
      expect(r.asegurado['fechaEmision'], '2026-08-21');
      expect(r.movimientos, hasLength(1));
    });

    test('extrae movimientos de un texto de ejemplo (formato por bloques)', () {
      final texto = '''
ESTADO DE AHORRO PREVISIONAL
ENTIDAD MUNICIPAL DE ASEO POTOSI
Feb-2026 6.800,55 30 680,06 0,00 0,00 34,00 714,06
MOVIMIENTO
ENTIDAD MUNICIPAL DE ASEO POTOSI
Feb-2026
6.800,55
30
680,06
714,06
''';
      final r = PdfParser.parse(texto);
      expect(r.movimientos, isNotEmpty);
      final m = r.movimientos.first;
      expect(m.mes, 2);
      expect(m.anio, 2026);
    });

    test('extrae aportes AFP y liquido pagable', () {
      final texto = '''
ESTADO DE AHORRO PREVISIONAL
MOVIMIENTO
ENTIDAD MUNICIPAL DE ASEO POTOSI
Mar-2026
Total ganado: 6.800,55
Aporte AFP: 680,06
Comision: 34,00
Liquido pagable: 6.086,49
Dias trabajados: 30
''';
      final r = PdfParser.parse(texto);
      expect(r.movimientos, isNotEmpty);
      final m = r.movimientos.first;
      expect(m.aporteAfp, 680.06);
      expect(m.liquidoPagable, 6086.49);
      expect(m.diasTrabajados, 30);
    });

    test('marca cobro de comision como COMISION', () {
      expect(PdfParser.isCommission('Cobro de comision Feb-2025'), isTrue);
      expect(PdfParser.isCommission('Aporte laboral normal'), isFalse);
    });

    test('parsea el texto real del PDF de prueba sin inventar datos', () {
      final texto = File(
        'test/fixtures/certificado2.txt',
      ).readAsStringSync();
      final r = PdfParser.parse(texto);

      expect(r.movimientos, hasLength(47));

      final julio = r.movimientos
          .where((m) => m.anio == 2023 && m.mes == 7)
          .toList();
      expect(julio, hasLength(2));
      expect(julio[0].totalGanado, 551.13);
      expect(julio[0].diasTrabajados, 7);
      expect(julio[0].cotizacionMensual, 55.11);
      expect(julio[1].totalGanado, 1942.44);
      expect(julio[1].diasTrabajados, 17);
      expect(julio[1].cotizacionMensual, 194.24);

      final enero2024 = r.movimientos
          .where((m) => m.anio == 2024 && m.mes == 1)
          .toList();
      expect(enero2024, hasLength(2));
      expect(enero2024[0].totalGanado, 3642.08);
      expect(enero2024[1].totalGanado, 108.92);

      final abril2023 = r.movimientos
          .where((m) => m.anio == 2023 && m.mes == 4)
          .toList();
      expect(abril2023, hasLength(1));
      expect(abril2023.single.totalGanado, 1987.50);
      expect(abril2023.single.diasTrabajados, 25);
    });
  });

  group('RegistroExtraido', () {
    test('muestra el nombre del mes', () {
      expect(RegistroExtraido(mes: 1, anio: 2026).mesNombre, 'Enero');
      expect(RegistroExtraido(mes: 12, anio: 2026).mesNombre, 'Diciembre');
    });

    test('limita los días trabajados a 30', () {
      final registro = RegistroExtraido(mes: 2, anio: 2026, diasTrabajados: 45);
      final historico = RegistroExtraido.fromJson({
        'mes': 2,
        'anio': 2026,
        'diasTrabajados': 31,
      });

      expect(registro.diasTrabajados, 30);
      expect(historico.diasTrabajados, 30);
    });
  });

  group('Resumen de aportes', () {
    test('acumula días entre meses hasta completar 30', () {
      final resumen = ExportService.calcularResumenAportes([
        RegistroExtraido(mes: 1, anio: 2026, diasTrabajados: 27),
        RegistroExtraido(mes: 2, anio: 2026, diasTrabajados: 27),
        RegistroExtraido(mes: 3, anio: 2026, diasTrabajados: 6),
      ]);

      expect(resumen.cotizaciones, 2);
      expect(resumen.diasPendientes, 0);
      expect(resumen.anios.single.cotizaciones, 2);
    });

    test('muestra como pendientes los días que no completan 30', () {
      final resumen = ExportService.calcularResumenAportes([
        RegistroExtraido(mes: 12, anio: 2025, diasTrabajados: 27),
      ]);

      expect(resumen.cotizaciones, 0);
      expect(resumen.diasPendientes, 27);
      expect(resumen.anios.single.diasPendientes, 27);
    });

    test('no arrastra los días pendientes entre años', () {
      final resumen = ExportService.calcularResumenAportes([
        RegistroExtraido(mes: 1, anio: 2026, diasTrabajados: 3),
        RegistroExtraido(mes: 12, anio: 2025, diasTrabajados: 27),
      ]);

      expect(resumen.cotizaciones, 0);
      expect(resumen.diasPendientes, 3);
      expect(resumen.anios[0].anio, 2025);
      expect(resumen.anios[0].cotizaciones, 0);
      expect(resumen.anios[0].diasPendientes, 27);
      expect(resumen.anios[1].anio, 2026);
      expect(resumen.anios[1].cotizaciones, 0);
      expect(resumen.anios[1].diasPendientes, 3);
    });

    test('exporta meses como nombres e incluye el logo1', () async {
      final bytes = await ExportService.generarXlsxBytes([
        RegistroExtraido(
          nombres: 'PRUEBA',
          ci: '1234567',
          empleador: 'ENTIDAD MUNICIPAL DE ASEO POTOSI',
          mes: 1,
          anio: 2026,
          diasTrabajados: 27,
        ),
      ]);
      final archivo = ZipDecoder().decodeBytes(bytes);
      final excel = Excel.decodeBytes(bytes);
      final mes =
          excel['Certificado']
                  .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 9))
                  .value
              as TextCellValue;

      expect(mes.value.text, 'Enero');
      expect(archivo.findFile('xl/media/logo1.png'), isNotNull);
      expect(archivo.findFile('xl/media/logo2.png'), isNull);
      expect(archivo.findFile('xl/drawings/drawing1.xml'), isNotNull);
      expect(archivo.findFile('xl/drawings/drawing2.xml'), isNull);
      expect(
        archivo.findFile('xl/drawings/_rels/drawing1.xml.rels'),
        isNotNull,
      );

      String readXml(String path) {
        return utf8.decode(archivo.findFile(path)!.content as List<int>);
      }

      final sheetXml = readXml('xl/worksheets/sheet1.xml');
      final drawingXml = readXml('xl/drawings/drawing1.xml');
      final drawingRels = readXml('xl/drawings/_rels/drawing1.xml.rels');
      expect(RegExp(r'<drawing\b').allMatches(sheetXml).length, 1);
      expect(drawingXml, contains('r:embed="rIdLogo1"'));
      expect(drawingXml, isNot(contains('r:embed="rIdLogo2"')));
      expect(drawingRels, contains('Target="../media/logo1.png"'));
      expect(drawingRels, isNot(contains('Target="../media/logo2.png"')));
    });
  });
}
