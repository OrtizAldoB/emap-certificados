import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/registro_extraido.dart';
import '../../services/export_service.dart';
import '../../services/historial_service.dart';
import '../../services/pdf_processing_service.dart';

class ProcesarView extends StatefulWidget {
  const ProcesarView({super.key});

  @override
  State<ProcesarView> createState() => _ProcesarViewState();
}

class _ProcesarViewState extends State<ProcesarView> {
  final _pdfService = PdfProcessingService();
  final _historial = HistorialService();

  List<RegistroExtraido> _registros = [];
  bool _procesando = false;
  bool _dragOver = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final regs = await _historial.cargar();
    if (mounted) setState(() => _registros = regs);
  }

  Future<void> _seleccionarPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    await _procesarArchivos(result.files
        .map((f) => (archivo: File(f.path!), nombre: f.name))
        .toList());
  }

  Future<void> _recibirArchivos(List<DropItem> archivos) async {
    setState(() => _dragOver = false);
    if (archivos.isEmpty) return;
    await _procesarArchivos(archivos
        .where((f) => f.name.toLowerCase().endsWith('.pdf'))
        .map((f) => (archivo: File(f.path), nombre: f.name))
        .toList());
  }

  Future<void> _procesarArchivos(
      List<({File archivo, String nombre})> archivos) async {
    setState(() {
      _procesando = true;
      _error = '';
    });
    try {
      final nuevos = <RegistroExtraido>[];
      for (final item in archivos) {
        final resultado = await _pdfService.parsePdfFile(item.archivo.path);
        if (resultado.movimientos.isEmpty) {
          _error += '• ${item.nombre}: no se identificaron movimientos.\n';
          continue;
        }
        final asegurado = resultado.asegurado;
        final fecha = DateTime.now();
        for (final m in resultado.movimientos) {
          final aportesAfpCalc = m.totalGanado * 0.1271;
          final liquidoPagableCalc = m.totalGanado - aportesAfpCalc;
          nuevos.add(RegistroExtraido(
            archivo: item.nombre,
            ci: asegurado['ci'] ?? '',
            nombres:
                '${asegurado['nombres'] ?? ''} ${asegurado['apellidos'] ?? ''}'.trim(),
            cua: asegurado['cua'] ?? '',
            empleador: m.empleador,
            mes: m.mes,
            anio: m.anio,
            totalGanado: m.totalGanado,
            aportesAfp: aportesAfpCalc,
            liquidoPagable: liquidoPagableCalc,
            diasTrabajados: m.diasTrabajados,
            fechaProceso:
                '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
          ));
        }
      }
      if (nuevos.isNotEmpty) {
        _registros.insertAll(0, nuevos);
        await _historial.guardar(_registros);
        if (mounted) setState(() {});
      }
      if (_error.isNotEmpty) {
        if (mounted) _notify(_error.trim());
      }
    } catch (e) {
      if (mounted) _notify('Error al procesar PDF: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _exportarExcel() async {
    final ruta = await ExportService.exportarXlsx(_registros, 'EMAP_Aportes');
    if (ruta != null && mounted) {
      _notify('Excel generado: $ruta');
    }
  }

  Future<void> _limpiar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: Text('¿Eliminar los ${_registros.length} registro(s) de la lista?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Limpiar')),
        ],
      ),
    );
    if (ok != true) return;
    _registros.clear();
    await _historial.guardar(_registros);
    if (mounted) setState(() {});
  }

  void _notify(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _registros.fold<double>(
        0, (a, r) => a + r.liquidoPagable);
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMAP - Extracción de Aportaciones (PDF)'),
        actions: [
          if (_registros.isNotEmpty)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _procesando ? null : _exportarExcel,
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('EXPORTAR EXCEL (.xlsx)'),
            ),
          if (_registros.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Limpiar historial',
              onPressed: _procesando ? null : _limpiar,
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sube uno o varios archivos PDF (Estados de Ahorro Previsional). '
              'Se extraerán: año, mes, total ganado, aportes AFP, líquido pagable y días trabajados.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildDropZone(),
            const SizedBox(height: 16),
            if (_registros.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Aún no hay datos extraídos.\nArrastre los PDFs arriba o haga clic en la zona.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                children: [
                                  const Text('DATOS EXTRAÍDOS',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const Spacer(),
                                  Text(
                                    '${_registros.length} registro(s) | Total líquido: Bs. ${_fmtNum(total)}',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('ARCHIVO')),
                                      DataColumn(label: Text('C.I.')),
                                      DataColumn(label: Text('TRABAJADOR/A')),
                                      DataColumn(label: Text('EMPLEADOR')),
                                      DataColumn(label: Text('AÑO')),
                                      DataColumn(label: Text('MES')),
                                      DataColumn(label: Text('TOTAL GANADO')),
                                      DataColumn(label: Text('APORTES AFP')),
                                      DataColumn(label: Text('LÍQUIDO PAGABLE')),
                                      DataColumn(label: Text('DÍAS')),
                                    ],
                                    rows: _registros.map((r) {
                                      return DataRow(cells: [
                                        DataCell(Text(r.archivo,
                                            overflow: TextOverflow.ellipsis)),
                                        DataCell(Text(r.ci)),
                                        DataCell(Text(r.nombres.isEmpty
                                            ? '—'
                                            : r.nombres)),
                                        DataCell(Text(r.empleador,
                                            overflow: TextOverflow.ellipsis)),
                                        DataCell(Text('${r.anio}')),
                                        DataCell(Text('${r.mes}')),
                                        DataCell(Text(_fmtNum(r.totalGanado))),
                                        DataCell(Text(_fmtNum(r.aportesAfp))),
                                        DataCell(Text(
                                            _fmtNum(r.liquidoPagable))),
                                        DataCell(Text('${r.diasTrabajados}')),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCertificadoAportes(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificadoAportes() {
    final Map<String, ({int dias, int mesMin, int mesMax})> porMes = {};
    for (final r in _registros) {
      if (r.diasTrabajados <= 0) continue;
      final key = '${r.anio}_${r.mes.toString().padLeft(2, '0')}';
      final prev = porMes[key];
      if (prev == null) {
        porMes[key] = (dias: r.diasTrabajados, mesMin: r.mes, mesMax: r.mes);
      } else {
        porMes[key] = (
          dias: r.diasTrabajados > prev.dias ? r.diasTrabajados : prev.dias,
          mesMin: prev.mesMin,
          mesMax: prev.mesMax,
        );
      }
    }

    final Map<int, List<({int mes, int dias})>> porAnio = {};
    for (final entry in porMes.entries) {
      final parts = entry.key.split('_');
      final anio = int.parse(parts[0]);
      final mes = int.parse(parts[1]);
      porAnio.putIfAbsent(anio, () => []).add((mes: mes, dias: entry.value.dias));
    }

    final anios = porAnio.keys.toList()..sort();

    int totalMeses = 0;
    int totalDias = 0;

    final filas = <DataRow>[];

    for (final anio in anios) {
      final mesesData = porAnio[anio]!..sort((a, b) => a.mes.compareTo(b.mes));

      final desde = RegistroExtraido(mes: mesesData.first.mes, anio: anio).mesNombre;
      final hasta = RegistroExtraido(mes: mesesData.last.mes, anio: anio).mesNombre;

      int diasAnio = 0;
      for (final m in mesesData) {
        diasAnio += m.dias;
      }

      final meses = diasAnio ~/ 30;
      final dias = diasAnio % 30;

      totalMeses += meses;
      totalDias += dias;

      filas.add(DataRow(cells: [
        DataCell(Text('$anio')),
        DataCell(Text(desde)),
        DataCell(Text(hasta)),
        DataCell(Text('$meses MESES')),
        DataCell(Text(dias > 0 ? '$dias DIAS' : '')),
      ]));
    }

    totalMeses += totalDias ~/ 30;
    totalDias = totalDias % 30;

    final aniosTotal = totalMeses ~/ 12;
    final mesesTotal = totalMeses % 12;

    String totalStr = '';
    if (aniosTotal > 0) {
      totalStr += '$aniosTotal AÑO${aniosTotal > 1 ? 'S' : ''}';
    }
    if (mesesTotal > 0) {
      if (totalStr.isNotEmpty) totalStr += ', ';
      totalStr += '$mesesTotal MES${mesesTotal > 1 ? 'ES' : ''}';
    }
    if (totalDias > 0) {
      if (totalStr.isNotEmpty) totalStr += ' Y ';
      totalStr += '$totalDias DÍA${totalDias > 1 ? 'S' : ''}';
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'CERTIFICADO DE APORTES',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('AÑO')),
                DataColumn(label: Text('DESDE')),
                DataColumn(label: Text('HASTA')),
                DataColumn(label: Text('NUMERO DE COTIZACIONES')),
                DataColumn(label: Text('APORTES EN')),
              ],
              rows: [
                ...filas,
                DataRow(cells: [
                  const DataCell(Text('TOTAL',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(Text('$totalMeses MESES',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(totalDias > 0 ? '$totalDias DIAS' : '',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'TOTAL: $totalStr',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: _procesando ? null : (details) => _recibirArchivos(details.files),
      child: InkWell(
        onTap: _procesando ? null : _seleccionarPdfs,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 110,
          decoration: BoxDecoration(
            border: Border.all(
              color: _dragOver ? AppTheme.primary : Colors.grey,
              width: _dragOver ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _dragOver
                ? AppTheme.primary.withValues(alpha: 0.05)
                : Colors.grey.shade50,
          ),
          child: Center(
            child: _procesando
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(width: 12),
                    Text('Extrayendo datos de los PDFs...'),
                  ])
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file, color: AppTheme.primary, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'Arrastra y suelta los PDFs aquí, o haz clic para seleccionarlos',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}