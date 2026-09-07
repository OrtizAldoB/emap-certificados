import 'package:flutter/material.dart';

import '../../models/trabajador.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/documento_repository.dart';
import '../../repositories/trabajador_repository.dart';

class ReportesView extends StatefulWidget {
  const ReportesView({super.key});

  @override
  State<ReportesView> createState() => _ReportesViewState();
}

class _ReportesViewState extends State<ReportesView> {
  final _trabRepo = TrabajadorRepository();
  final _docRepo = DocumentoRepository();
  final _dashRepo = DashboardRepository();
  List<String> _alertas = [];
  int? _trabajadorId;
  List<Trabajador> _trabajadores = [];

  @override
  void initState() {
    super.initState();
    _trabajadores = _trabRepo.listar();
  }

  void _analizar() {
    final alertas = <String>[];
    final anioActual = DateTime.now().year;

    if (_trabajadorId != null) {
      // Periodos faltantes en el ultimo año (y anteriores incompletos).
      for (var anio = anioActual - 1; anio <= anioActual; anio++) {
        final faltantes = _dashRepo.detectarPeriodosFaltantes(_trabajadorId!, anio, anio);
        for (final f in faltantes.take(6)) {
          alertas.add('⚠ Posible periodo faltante: $f.');
        }
      }

      // Datos faltantes (movimientos sin total ganado).
      final movs = _docRepo.listarMovimientos(trabajadorId: _trabajadorId);
      for (final m in movs) {
        if (m.requiereRevision && m.totalGanado == 0) {
          alertas.add('⚠ No se pudo identificar el total ganado para ${m.mesNombre} ${m.anio}. (Requiere revisión)');
        }
        if (m.diasTrabajados == 0) {
          alertas.add('⚠ No se pudo identificar los días trabajados para ${m.mesNombre} ${m.anio}.');
        }
      }
    }

    // Documentos duplicados (por hash).
    final hashes = <String, int>{};
    for (final d in _docRepo.listar()) {
      if (d.fileHash.isNotEmpty) {
        hashes[d.fileHash] = (hashes[d.fileHash] ?? 0) + 1;
      }
    }
    for (final e in hashes.entries) {
      if (e.value > 1) {
        alertas.add('⚠ Se detectaron ${e.value} documentos con el mismo contenido (posible duplicado).');
      }
    }

    if (alertas.isEmpty) {
      alertas.add('No se detectaron alertas.');
    }

    setState(() => _alertas = alertas);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REPORTES Y ALERTAS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Detección de posibles periodos faltantes, documentos duplicados y datos faltantes',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _trabajadorId,
                  decoration: const InputDecoration(labelText: 'Trabajador'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-- Analizar todos --')),
                    ..._trabajadores.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombreCompleto))),
                  ],
                  onChanged: (v) => setState(() => _trabajadorId = v),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _analizar,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Analizar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _alertas.isEmpty
                  ? const Center(child: Text('Seleccione un trabajador y presione Analizar.'))
                  : ListView.builder(
                      itemCount: _alertas.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: Icon(
                          _alertas[i].startsWith('No se detectaron') ? Icons.check_circle : Icons.warning_amber,
                          color: _alertas[i].startsWith('No se detectaron') ? Colors.green : Colors.orange,
                        ),
                        title: Text(_alertas[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}