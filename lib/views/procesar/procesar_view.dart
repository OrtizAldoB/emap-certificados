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
    await _procesarArchivos(
      result.files
          .map((f) => (archivo: File(f.path!), nombre: f.name))
          .toList(),
    );
  }

  Future<void> _recibirArchivos(List<DropItem> archivos) async {
    setState(() => _dragOver = false);
    if (archivos.isEmpty) return;
    await _procesarArchivos(
      archivos
          .where((f) => f.name.toLowerCase().endsWith('.pdf'))
          .map((f) => (archivo: File(f.path), nombre: f.name))
          .toList(),
    );
  }

  Future<void> _procesarArchivos(
    List<({File archivo, String nombre})> archivos,
  ) async {
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
        for (final movimiento in resultado.movimientos) {
          final aportesAfp = movimiento.totalGanado * 0.1271;
          nuevos.add(
            RegistroExtraido(
              archivo: item.nombre,
              ci: asegurado['ci'] ?? '',
              nombres:
                  '${asegurado['nombres'] ?? ''} ${asegurado['apellidos'] ?? ''}'
                      .trim(),
              cua: asegurado['cua'] ?? '',
              empleador: movimiento.empleador,
              mes: movimiento.mes,
              anio: movimiento.anio,
              totalGanado: movimiento.totalGanado,
              aportesAfp: aportesAfp,
              liquidoPagable: movimiento.totalGanado - aportesAfp,
              diasTrabajados: movimiento.diasTrabajados,
              fechaProceso:
                  '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
            ),
          );
        }
      }
      if (nuevos.isNotEmpty) {
        _registros.insertAll(0, nuevos);
        await _historial.guardar(_registros);
        if (mounted) setState(() {});
      }
      if (_error.isNotEmpty && mounted) _notify(_error.trim());
    } catch (e) {
      if (mounted) _notify('Error al procesar PDF: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _exportarExcel() async {
    final ruta = await ExportService.exportarXlsx(_registros, 'EMAP_Aportes');
    if (ruta != null && mounted) _notify('Excel generado: $ruta');
  }

  Future<void> _limpiar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: Text(
          '¿Eliminar los ${_registros.length} registro(s) de la lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _registros.clear();
    await _historial.guardar(_registros);
    if (mounted) setState(() {});
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final totalLiquido = _registros.fold<double>(
      0,
      (total, registro) => total + registro.liquidoPagable,
    );
    final resumen = ExportService.calcularResumenAportes(_registros);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Row(
          children: [
            _buildLogo('logo1.png'),
            const SizedBox(width: 8),
            _buildLogo('logo2.png'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('EMAP · Certificados de aportes'),
                  Text(
                    'Extracción y consolidación de Estados de Ahorro',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_registros.isNotEmpty)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryDark,
              ),
              onPressed: _procesando ? null : _exportarExcel,
              icon: const Icon(Icons.table_chart_outlined, size: 19),
              label: const Text('EXPORTAR EXCEL'),
            ),
          if (_registros.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpiar historial',
              onPressed: _procesando ? null : _limpiar,
            ),
          const SizedBox(width: 14),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          children: [
            _buildHeader(totalLiquido, resumen),
            const SizedBox(height: 14),
            _buildDropZone(),
            const SizedBox(height: 14),
            Expanded(
              child: _registros.isEmpty
                  ? _buildEmptyState()
                  : _buildResults(totalLiquido, resumen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(String fileName) {
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Image.asset(
        'assets/logos/$fileName',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.account_balance_outlined, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildHeader(double totalLiquido, ResumenCertificadoAportes resumen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241B5E20),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Panel de aportes previsionales',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Líquido acumulado: Bs. ${_fmtNum(totalLiquido)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildMetric('REGISTROS', '${_registros.length}'),
          const SizedBox(width: 8),
          _buildMetric('COTIZACIONES', '${resumen.cotizaciones}'),
          const SizedBox(width: 8),
          _buildMetric('DÍAS PENDIENTES', '${resumen.diasPendientes}'),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tu historial está vacío',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                'Arrastra uno o varios PDF o selecciona los archivos para comenzar.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(double totalLiquido, ResumenCertificadoAportes resumen) {
    return Column(
      children: [
        Expanded(flex: 5, child: _buildDataCard(totalLiquido)),
        const SizedBox(height: 12),
        SizedBox(height: 210, child: _buildCertificadoAportes(resumen)),
      ],
    );
  }

  Widget _buildDataCard(double totalLiquido) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCFA),
              border: Border(bottom: BorderSide(color: Color(0xFFE1E8E1))),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DATOS EXTRAÍDOS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Detalle de los aportes registrados',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_registros.length} registro(s) · Total líquido: Bs. ${_fmtNum(totalLiquido)}',
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
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
                  rows: _registros.map((registro) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            registro.archivo,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(Text(registro.ci)),
                        DataCell(
                          Text(
                            registro.nombres.isEmpty ? '—' : registro.nombres,
                          ),
                        ),
                        DataCell(
                          Text(
                            registro.empleador,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(Text('${registro.anio}')),
                        DataCell(Text(registro.mesNombre)),
                        DataCell(Text(_fmtNum(registro.totalGanado))),
                        DataCell(Text(_fmtNum(registro.aportesAfp))),
                        DataCell(Text(_fmtNum(registro.liquidoPagable))),
                        DataCell(Text('${registro.diasTrabajados}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificadoAportes(ResumenCertificadoAportes resumen) {
    if (!resumen.tieneDatos) {
      return Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy_outlined,
                color: Colors.grey.shade500,
                size: 34,
              ),
              const SizedBox(height: 10),
              const Text(
                'No hay días trabajados para calcular cotizaciones',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Los aportes se calcularán cuando exista un período con días.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final totalDescripcion = _descripcionTotal(resumen);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F6EE),
              border: Border(bottom: BorderSide(color: Color(0xFFDCE8D9))),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
                SizedBox(width: 9),
                Text(
                  'CERTIFICADO DE APORTES',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                Spacer(),
                Text(
                  '1 cotización = 30 días',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('AÑO')),
                  DataColumn(label: Text('DESDE')),
                  DataColumn(label: Text('HASTA')),
                  DataColumn(label: Text('NÚMERO DE COTIZACIONES')),
                  DataColumn(label: Text('APORTES EN')),
                ],
                rows: [
                  ...resumen.anios.map(
                    (item) => DataRow(
                      cells: [
                        DataCell(Text('${item.anio}')),
                        DataCell(Text(item.desde)),
                        DataCell(Text(item.hasta)),
                        DataCell(
                          Text(
                            '${item.cotizaciones} ${item.cotizaciones == 1 ? 'MES' : 'MESES'}',
                          ),
                        ),
                        DataCell(
                          Text(
                            item.diasPendientes > 0
                                ? '${item.diasPendientes} ${item.diasPendientes == 1 ? 'DÍA' : 'DÍAS'}'
                                : '—',
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataRow(
                    cells: [
                      const DataCell(
                        Text(
                          'TOTAL',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      DataCell(
                        Text(
                          '${resumen.cotizaciones} ${resumen.cotizaciones == 1 ? 'MES' : 'MESES'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(
                        Text(
                          resumen.diasPendientes > 0
                              ? '${resumen.diasPendientes} ${resumen.diasPendientes == 1 ? 'DÍA' : 'DÍAS'}'
                              : '—',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
            color: const Color(0xFFFAFCFA),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 15,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Los días pendientes se muestran en APORTES EN y continúan en el siguiente período.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Total: $totalDescripcion',
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _descripcionTotal(ResumenCertificadoAportes resumen) {
    final partes = <String>[];
    if (resumen.aniosCompletos > 0) {
      partes.add(
        '${resumen.aniosCompletos} ${resumen.aniosCompletos == 1 ? 'año' : 'años'}',
      );
    }
    if (resumen.mesesResiduales > 0) {
      partes.add(
        '${resumen.mesesResiduales} ${resumen.mesesResiduales == 1 ? 'mes' : 'meses'}',
      );
    }
    if (resumen.diasPendientes > 0) {
      partes.add(
        '${resumen.diasPendientes} ${resumen.diasPendientes == 1 ? 'día' : 'días'}',
      );
    }
    return partes.isEmpty ? 'sin cotizaciones completas' : partes.join(', ');
  }

  Widget _buildDropZone() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: _procesando
          ? null
          : (details) => _recibirArchivos(details.files),
      child: MouseRegion(
        cursor: _procesando
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: InkWell(
          onTap: _procesando ? null : _seleccionarPdfs,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(
                color: _dragOver ? AppTheme.primary : const Color(0xFFD8E1D7),
                width: _dragOver ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: _dragOver
                    ? [
                        AppTheme.primary.withValues(alpha: 0.10),
                        const Color(0xFFF8FBF7),
                      ]
                    : const [Colors.white, Color(0xFFF7FAF6)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _procesando
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.primary,
                          ),
                        )
                      : const Icon(
                          Icons.cloud_upload_outlined,
                          color: AppTheme.primary,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _procesando
                            ? 'Procesando archivos PDF...'
                            : 'Arrastra y suelta tus archivos PDF',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _procesando
                            ? 'Extrayendo-mes, importes y días trabajados'
                            : 'También puedes hacer clic para seleccionarlos',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'SELECCIONAR PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtNum(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    final buffer = StringBuffer();
    for (var i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) buffer.write('.');
      buffer.write(integerPart[i]);
    }
    return '$buffer,$decimalPart';
  }
}
