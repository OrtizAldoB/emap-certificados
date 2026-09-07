import 'package:flutter_test/flutter_test.dart';
import 'package:emap/utils/pdf_parser.dart';

void main() {
  group('PdfParser', () {
    test('convierte numeros latinos correctamente', () {
      expect(PdfParser.num('6.800,55'), 6800.55);
      expect(PdfParser.num('680,06'), 680.06);
      expect(PdfParser.num('0,00'), 0.0);
      expect(PdfParser.num('34,00'), 34.0);
      expect(PdfParser.num('30'), 30.0);
    });

    test('detecta periodo Feb-2026', () {
      final p = PdfParser.parsePeriod('Feb-2026');
      expect(p, isNotNull);
      expect(p!.mes, 2);
      expect(p.anio, 2026);
    });

    test('extrae movimientos de un texto de ejemplo', () {
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

    test('marca cobro de comision como COMISION', () {
      expect(PdfParser.isCommission('Cobro de comision Feb-2025'), isTrue);
      expect(PdfParser.isCommission('Aporte laboral normal'), isFalse);
    });
  });
}
