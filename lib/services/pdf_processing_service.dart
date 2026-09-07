import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../utils/pdf_parser.dart';

/// Extrae el texto de un PDF (via Pdfium dentro de la app) y lo analiza.
class PdfProcessingService {
  /// Devuelve el texto completo extraido del PDF.
  Future<String> extractText(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      final sb = StringBuffer();
      for (var i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        final text = await page.loadText();
        if (text != null) sb.writeln(text.fullText);
      }
      return sb.toString();
    } finally {
      await doc.dispose();
    }
  }

  /// Lee y analiza un PDF, devolviendo resultado estructurado.
  Future<ParsedResult> parsePdfFile(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw Exception('El archivo no existe: $filePath');
    }
    final text = await extractText(filePath);
    return PdfParser.parse(text);
  }

  /// Detecta si el PDF contiene poco texto (posible documento escaneado -> requiere OCR/manual).
  Future<bool> esEscaneado(String filePath) async {
    final text = await extractText(filePath);
    final useful = text.replaceAll(RegExp(r'\s+'), '').length;
    return useful < 40;
  }
}