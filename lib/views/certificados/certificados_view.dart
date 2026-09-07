import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/certificado.dart';
import '../../models/movimiento.dart';
import '../../models/trabajador.dart';
import '../../repositories/certificado_repository.dart';
import '../../repositories/trabajador_repository.dart';
import '../../services/export_service.dart';
import '../../utils/audit.dart';

class CertificadosView extends StatefulWidget {
  const CertificadosView({super.key});

  @override
  State<CertificadosView> createState() => _CertificadosViewState();
}

class _CertificadosViewState extends State<CertificadosView> {
  final _certRepo = CertificadoRepository();
  final _trabRepo = TrabajadorRepository();
  int? _trabajadorId;
  DateTime? _desde;
  DateTime? _hasta;
  List<Trabajador> _trabajadores = [];
  List<Movimiento> _datos = [];

  @override
  void initState() {
    super.initState();
    _trabajadores = _trabRepo.listar();
    final now = DateTime.now();
    _hasta = now;
    _desde = DateTime(now.year, 1, 1);
  }

  void _cargarDatos() {
    if (_trabajadorId == null || _desde == null || _hasta == null) {
      setState(() => _datos = []);
      return;
    }
    final movs = _certRepo.datosParaCertificado(
      _trabajadorId!,
      anioDesde: _desde!.year,
      mesDesde: _desde!.month,
      anioHasta: _hasta!.year,
      mesHasta: _hasta!.month,
    );
    setState(() => _datos = movs);
  }

  Future<void> _fecha() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde!, end: _hasta!),
    );
    if (rango != null) {
      setState(() {
        _desde = rango.start;
        _hasta = rango.end;
      });
      _cargarDatos();
    }
  }

  Future<void> _generarCertificado() async {
    if (_trabajadorId == null) {
      _notify('Seleccione un trabajador.');
      return;
    }
    if (_datos.isEmpty) {
      _notify('No hay movimientos en el rango seleccionado.');
      return;
    }
    final totales = _certRepo.totales(_datos);
    _certRepo.guardar(Certificado(
      trabajadorId: _trabajadorId!,
      fechaDesde: DateFormat('dd/MM/yyyy').format(_desde!),
      fechaHasta: DateFormat('dd/MM/yyyy').format(_hasta!),
      totalGanado: totales['ganado']!,
      totalAfp: totales['afp']!,
      totalLiquido: totales['liquido']!,
      totalDias: totales['dias']!.toInt(),
    ));
    _cargarGenerados();
    _notify('Certificado generado y registrado.');
  }

  void _cargarGenerados() {
    // Registro de certificados (consultable si se desea ampliar).
    _trabajadorId == null ? _certRepo.listar() : _certRepo.listar(trabajadorId: _trabajadorId);
  }

  Future<void> _exportar(String tipo) async {
    if (_datos.isEmpty) {
      _notify('No hay datos para exportar.');
      return;
    }
    final trab = _trabRepo.getById(_trabajadorId!);
    final base = 'Certificado_Aportaciones_${(trab?.nombreCompleto ?? '').replaceAll(' ', '_')}';
    String? ruta;
    if (tipo == 'excel') {
      ruta = await ExportService.exportarExcel(_datos, base, trabajador: trab);
    } else {
      ruta = await ExportService.exportarPdf(_datos, base, trabajador: trab);
    }
    Audit.log('EXPORTAR_${tipo.toUpperCase()}', entidad: 'certificados', entidadId: _trabajadorId,
        detalle: 'Exportó ${tipo.toUpperCase()} de certificado');
    if (mounted && ruta != null) {
      _notify('Archivo generado: $ruta');
    }
  }

  void _notify(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CERTIFICADOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Generación de certificados de aportaciones', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _trabajadorId,
                  decoration: const InputDecoration(labelText: 'Trabajador'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-- Seleccionar --')),
                    ..._trabajadores.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombreCompleto))),
                  ],
                  onChanged: (v) {
                    setState(() => _trabajadorId = v);
                    _cargarDatos();
                    _cargarGenerados();
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _fecha,
                icon: const Icon(Icons.date_range),
                label: Text(DateFormat('dd/MM/yyyy').format(_desde!)),
              ),
              const SizedBox(width: 8),
              const Text('a'),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _fecha,
                icon: const Icon(Icons.date_range),
                label: Text(DateFormat('dd/MM/yyyy').format(_hasta!)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _generarCertificado,
                icon: const Icon(Icons.note_add),
                label: const Text('Generar certificado'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _exportar('excel'),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('GENERAR EXCEL'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _exportar('pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('GENERAR PDF'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _datos.isEmpty
                  ? const Center(child: Text('Seleccione trabajador y rango de fechas.'))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          DataTable(
                            columns: const [
                              DataColumn(label: Text('AÑO')),
                              DataColumn(label: Text('FECHA')),
                              DataColumn(label: Text('TOTAL GANADO')),
                              DataColumn(label: Text('APORTES A.F.P.')),
                              DataColumn(label: Text('LIQUIDO PAGABLE')),
                              DataColumn(label: Text('DIAS')),
                            ],
                            rows: _datos.map((m) => DataRow(cells: [
                              DataCell(Text('${m.anio}')),
                              DataCell(Text('${m.mes.toString().padLeft(2, '0')}/01/${m.anio}')),
                              DataCell(Text(_fmt(m.totalGanado))),
                              DataCell(Text(_fmt(m.afp))),
                              DataCell(Text(_fmt(m.liquidoPagable))),
                              DataCell(Text('${m.diasTrabajados}')),
                            ])).toList(),
                          ),
                          _totalesWidget(),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalesWidget() {
    final t = _certRepo.totales(_datos);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text('TOTAL GANADO: Bs. ${_fmt(t['ganado']!)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('TOTAL APORTES AFP: Bs. ${_fmt(t['afp']!)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('TOTAL LÍQUIDO PAGABLE: Bs. ${_fmt(t['liquido']!)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('TOTAL DÍAS TRABAJADOS: ${t['dias']!.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}