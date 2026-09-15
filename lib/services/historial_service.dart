import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/registro_extraido.dart';

/// Persiste las extracciones en un JSON local, para que el usuario
/// pueda visualizarlas cada vez que abre la app (no solo una vez).
class HistorialService {
  static const _fileName = 'historial_extracciones.json';

  Future<File> _archivo() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, _fileName));
  }

  /// Guarda (reemplazando) la lista completa de registros.
  Future<void> guardar(List<RegistroExtraido> registros) async {
    final file = await _archivo();
    final data = jsonEncode(registros.map((r) => r.toJson()).toList());
    await file.writeAsString(data, flush: true);
  }

  /// Carga los registros guardados.
  Future<List<RegistroExtraido>> cargar() async {
    final file = await _archivo();
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(RegistroExtraido.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}