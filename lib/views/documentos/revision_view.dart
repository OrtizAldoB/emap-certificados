import 'package:flutter/material.dart';

import '../../models/movimiento.dart';
import '../../repositories/documento_repository.dart';
import '../../utils/pdf_parser.dart';

class _FilaEditable {
  int? id; // id de movimiento si ya existe en BD
  late int mes;
  late int anio;
  late String empleador;
  late String tipoMovimiento;
  late TextEditingController totalGanado;
  late TextEditingController dias;
  late TextEditingController afp;
  late TextEditingController liquido;
  late bool requiereRevision;
  final double? originalTotalGanado;
  final double? originalDias;

  _FilaEditable.fromParsed(ParsedPayment m, this.originalTotalGanado, this.originalDias)
      : mes = m.mes,
        anio = m.anio,
        empleador = m.empleador,
        tipoMovimiento = m.tipoMovimiento,
        requiereRevision = m.requiereRevision {
    totalGanado = TextEditingController(text: _fmtNum(m.totalGanado));
    dias = TextEditingController(text: '${m.diasTrabajados}');
    afp = TextEditingController(text: _fmtNum(m.totalAportes));
    liquido = TextEditingController(text: _fmtNum(0));
  }

  _FilaEditable.fromMovimiento(Movimiento m)
      : id = m.id,
        mes = m.mes,
        anio = m.anio,
        empleador = m.empleador,
        tipoMovimiento = m.tipoMovimiento,
        requiereRevision = m.requiereRevision,
        originalTotalGanado = m.originalTotalGanado,
        originalDias = m.originalDias?.toDouble() {
    totalGanado = TextEditingController(text: _fmtNum(m.totalGanado));
    dias = TextEditingController(text: '${m.diasTrabajados}');
    afp = TextEditingController(text: _fmtNum(m.afp));
    liquido = TextEditingController(text: _fmtNum(m.liquidoPagable));
  }

  static String _fmtNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void dispose() {
    totalGanado.dispose();
    dias.dispose();
    afp.dispose();
    liquido.dispose();
  }
}

class RevisionView extends StatefulWidget {
  final int docId;
  final int trabajadorId;
  final ParsedResult resultado;
  final int? estadoAhorroId;

  const RevisionView({
    super.key,
    required this.docId,
    required this.trabajadorId,
    required this.resultado,
    this.estadoAhorroId,
  });

  @override
  State<RevisionView> createState() => _RevisionViewState();
}

class _RevisionViewState extends State<RevisionView> {
  final _docRepo = DocumentoRepository();
  late final List<_FilaEditable> _filas;
  int? _estadoAhorroId;
  String? _warnMultiples;

  @override
  void initState() {
    super.initState();
    _estadoAhorroId = widget.estadoAhorroId;

    // Cargar movimientos existentes si re-abriendo revision.
    final existentes = _estadoAhorroId != null
        ? _docRepo.listarMovimientos(estadoAhorroId: _estadoAhorroId)
        : <Movimiento>[];

    if (existentes.isNotEmpty) {
      _filas = existentes.map((m) => _FilaEditable.fromMovimiento(m)).toList();
    } else {
      _filas = widget.resultado.movimientos
          .map((m) => _FilaEditable.fromParsed(m, m.totalGanado, m.diasTrabajados.toDouble()))
          .toList();
    }

    // Advertencia por multiples movimientos del mismo periodo.
    final conteo = <String, int>{};
    for (final f in _filas) {
      final k = '${f.anio}-${f.mes}';
      conteo[k] = (conteo[k] ?? 0) + 1;
    }
    final multi = conteo.entries.where((e) => e.value > 1).toList();
    if (multi.isNotEmpty) {
      _warnMultiples = 'Existen varios movimientos para el mismo periodo. Revise los datos antes de continuar.';
    }
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final caso = _estadoAhorroId ?? _docRepo.crearEstadoAhorro(widget.docId, widget.trabajadorId,
        periodo: widget.resultado.asegurado['periodo'] ?? '',
        fechaEmision: widget.resultado.asegurado['fechaEmision'] ?? '',
        numero: widget.resultado.asegurado['numero'] ?? '',
        rawText: 'extraido');

    for (final f in _filas) {
      final totalGanado = double.tryParse(f.totalGanado.text.replaceAll(',', '.')) ?? 0;
      final dias = int.tryParse(f.dias.text) ?? 0;
      final afpVal = double.tryParse(f.afp.text.replaceAll(',', '.')) ?? 0;
      final liquidoVal = double.tryParse(f.liquido.text.replaceAll(',', '.')) ?? 0;

      if (f.id == null) {
        _docRepo.guardarMovimiento(Movimiento(
          estadoAhorroId: caso,
          trabajadorId: widget.trabajadorId,
          anio: f.anio,
          mes: f.mes,
          empleador: f.empleador,
          tipoMovimiento: f.tipoMovimiento,
          totalGanado: totalGanado,
          diasTrabajados: dias,
          afp: afpVal,
          liquidoPagable: liquidoVal,
          originalTotalGanado: f.originalTotalGanado,
          originalDias: f.originalDias?.toInt(),
          requiereRevision: f.requiereRevision,
        ));
      } else {
        _docRepo.actualizarMovimiento(Movimiento(
          id: f.id,
          estadoAhorroId: 0,
          trabajadorId: widget.trabajadorId,
          anio: f.anio,
          mes: f.mes,
          totalGanado: totalGanado,
          diasTrabajados: dias,
          afp: afpVal,
          liquidoPagable: liquidoVal,
          requiereRevision: f.requiereRevision,
        ));
      }
    }

    _docRepo.actualizarEstado(widget.docId, 'PROCESADO');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos guardados correctamente.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asegurado = widget.resultado.asegurado;
    return Scaffold(
      appBar: AppBar(
        title: const Text('REVISIÓN DE DATOS EXTRAÍDOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAsegurado(asegurado),
            if (_warnMultiples != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_warnMultiples!, style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(child: _buildTabla()),
            const SizedBox(height: 12),
            _buildBotones(),
          ],
        ),
      ),
    );
  }

  Widget _buildAsegurado(Map<String, String> a) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _info('C.I.', a['ci'] ?? ''),
            _info('CUA', a['cua'] ?? ''),
            _info('Nº Estado', a['numero'] ?? ''),
            _info('Periodo', a['periodo'] ?? ''),
            _info('Fecha emisión', a['fechaEmision'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(valor.isEmpty ? 'No identificado' : valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valor.isEmpty ? Colors.red : Colors.black,
              )),
        ],
      );

  Widget _buildTabla() {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Año')),
              DataColumn(label: Text('Mes')),
              DataColumn(label: Text('Empleador')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Total ganado')),
              DataColumn(label: Text('AFP')),
              DataColumn(label: Text('Líquido pagable')),
              DataColumn(label: Text('Días')),
              DataColumn(label: Text('Estado')),
            ],
            rows: _filas.map((f) {
              final tieneGanado = double.tryParse(f.totalGanado.text.replaceAll(',', '.')) ?? 0;
              final indicador = f.requiereRevision || tieneGanado == 0
                  ? const Text('⚠', style: TextStyle(color: Colors.orange))
                  : const Text('✓', style: TextStyle(color: Colors.green));
              return DataRow(cells: [
                DataCell(_numField(f.anio.toString(), (v) {})),
                DataCell(Text(PdfParser.mesNombre(f.mes))),
                DataCell(Text(f.empleador.isEmpty ? '—' : f.empleador, overflow: TextOverflow.ellipsis)),
                DataCell(Text(f.tipoMovimiento)),
                DataCell(SizedBox(width: 110, child: TextField(controller: f.totalGanado, decoration: const InputDecoration(isDense: true)))),
                DataCell(SizedBox(width: 110, child: TextField(controller: f.afp, decoration: const InputDecoration(isDense: true)))),
                DataCell(SizedBox(width: 110, child: TextField(controller: f.liquido, decoration: const InputDecoration(isDense: true)))),
                DataCell(SizedBox(width: 70, child: TextField(controller: f.dias, decoration: const InputDecoration(isDense: true)))),
                DataCell(indicador),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _numField(String texto, ValueChanged<String> onChanged) => Text(
        texto,
        style: const TextStyle(fontSize: 13),
      );

  Widget _buildBotones() {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.save),
          label: const Text('GUARDAR'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.cancel),
          label: const Text('CANCELAR'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.replay),
          label: const Text('VOLVER A PROCESAR'),
        ),
      ],
    );
  }
}
