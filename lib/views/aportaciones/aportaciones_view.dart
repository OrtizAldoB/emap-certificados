import 'package:flutter/material.dart';

import '../../models/movimiento.dart';
import '../../models/trabajador.dart';
import '../../repositories/documento_repository.dart';
import '../../repositories/trabajador_repository.dart';
import '../../services/export_service.dart';
import '../../utils/pdf_parser.dart';

class AportacionesView extends StatefulWidget {
  final int? trabajadorId;
  const AportacionesView({super.key, this.trabajadorId});
  const AportacionesView.init(int trabajadorId) : this(trabajadorId: trabajadorId);

  @override
  State<AportacionesView> createState() => _AportacionesViewState();
}

class _AportacionesViewState extends State<AportacionesView> {
  final _docRepo = DocumentoRepository();
  final _trabRepo = TrabajadorRepository();
  int? _trabajadorId;
  List<Trabajador> _trabajadores = [];
  List<Movimiento> _movimientos = [];
  int? _anioFiltro;
  int? _mesFiltro;

  @override
  void initState() {
    super.initState();
    _trabajadorId = widget.trabajadorId;
    _trabajadores = _trabRepo.listar();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _movimientos = _trabajadorId == null
          ? []
          : _docRepo.listarMovimientos(trabajadorId: _trabajadorId, anio: _anioFiltro, mes: _mesFiltro);
    });
  }

  Future<void> _exportarExcel() async {
    if (_movimientos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos para exportar.')));
      return;
    }
    final trab = _trabRepo.getById(_trabajadorId!);
    final ruta = await ExportService.exportarExcel(_movimientos, 'Historial_Aportaciones_${trab?.nombreCompleto.replaceAll(' ', '_') ?? ''}');
    if (mounted && ruta != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel generado: $ruta')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HISTORIAL DE APORTACIONES')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _trabajadorId,
                    decoration: const InputDecoration(labelText: 'Trabajador'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Seleccionar --')),
                      ..._trabajadores.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombreCompleto))),
                    ],
                    onChanged: (v) {
                      setState(() => _trabajadorId = v);
                      _cargar();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _anioFiltro,
                    decoration: const InputDecoration(labelText: 'Año'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...List.generate(15, (i) => DateTime.now().year - i)
                          .map((a) => DropdownMenuItem(value: a, child: Text('$a'))),
                    ],
                    onChanged: (v) {
                      setState(() => _anioFiltro = v);
                      _cargar();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _mesFiltro,
                    decoration: const InputDecoration(labelText: 'Mes'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(value: m, child: Text(PdfParser.mesNombre(m)))),
                    ],
                    onChanged: (v) {
                      setState(() => _mesFiltro = v);
                      _cargar();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _exportarExcel,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Exportar Excel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: _movimientos.isEmpty
                    ? const Center(child: Text('Seleccione un trabajador para ver sus aportaciones.'))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Año')),
                            DataColumn(label: Text('Mes')),
                            DataColumn(label: Text('Total ganado')),
                            DataColumn(label: Text('AFP')),
                            DataColumn(label: Text('Líquido')),
                            DataColumn(label: Text('Días')),
                            DataColumn(label: Text('Estado')),
                          ],
                          rows: _movimientos.map((m) => DataRow(cells: [
                            DataCell(Text('${m.anio}')),
                            DataCell(Text(m.mesNombre)),
                            DataCell(Text(_fmt(m.totalGanado))),
                            DataCell(Text(_fmt(m.afp))),
                            DataCell(Text(_fmt(m.liquidoPagable))),
                            DataCell(Text('${m.diasTrabajados}')),
                            DataCell(m.requiereRevision
                                ? const Text('⚠', style: TextStyle(color: Colors.orange))
                                : const Text('✓', style: TextStyle(color: Colors.green))),
                          ])).toList(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}