import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/theme.dart';
import '../../database/database_helper.dart';
import '../../models/documento.dart';
import '../../models/trabajador.dart';
import '../../repositories/documento_repository.dart';
import '../../repositories/trabajador_repository.dart';
import '../../services/pdf_processing_service.dart';
import '../../utils/audit.dart';
import 'revision_view.dart';

class DocumentosView extends StatefulWidget {
  final int? trabajadorPreseleccionado;
  const DocumentosView({super.key, this.trabajadorPreseleccionado});

  @override
  State<DocumentosView> createState() => _DocumentosViewState();
}

class _DocumentosViewState extends State<DocumentosView> {
  final _repo = DocumentoRepository();
  final _trabRepo = TrabajadorRepository();
  final _pdfService = PdfProcessingService();
  int? _trabajadorId;
  List<Trabajador> _trabajadores = [];
  List<Documento> _documentos = [];
  bool _procesando = false;
  bool _dragOver = false;

  @override
  void initState() {
    super.initState();
    _trabajadorId = widget.trabajadorPreseleccionado;
    _trabajadores = _trabRepo.listar();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _documentos = _repo.listar();
    });
  }

  Future<void> _seleccionarPdf() async {
    if (_trabajadorId == null) {
      _notify('Seleccione un trabajador primero.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    final archivo = File(result.files.single.path!);
    if (!await _esPdfValido(archivo, result.files.single.name)) return;
    await _procesarArchivo(archivo, result.files.single.name);
  }

  Future<bool> _esPdfValido(File archivo, String nombre) async {
    if (!nombre.toLowerCase().endsWith('.pdf')) {
      _notify('Solo se permiten archivos PDF.');
      return false;
    }
    if (!await archivo.exists()) {
      _notify('El archivo no existe.');
      return false;
    }
    final sizeMb = await archivo.length() / (1024 * 1024);
    final maxMb = double.tryParse(
            DatabaseHelper.instance.db
                .select("SELECT valor FROM configuracion WHERE clave='max_pdf_mb'")
                .first
                .toMap()['valor'] as String) ??
        20;
    if (sizeMb > maxMb) {
      _notify('El archivo supera el límite de $maxMb MB.');
      return false;
    }
    return true;
  }

  Future<void> _procesarArchivo(File archivo, String nombre) async {
    setState(() => _procesando = true);
    try {
      // Copiar a la carpeta de datos.
      final dirPdf = p.join(DatabaseHelper.instance.dataDir, 'pdfs');
      if (!Directory(dirPdf).existsSync()) Directory(dirPdf).createSync(recursive: true);
      final destino = p.join(dirPdf, '${DateTime.now().millisecondsSinceEpoch}_$nombre');
      await archivo.copy(destino);

      final bytes = await File(destino).readAsBytes();
      final hash = SecurityUtils.sha256File(bytes);

      // Deteccion de duplicado.
      if (_repo.documentoYaRegistrado(hash)) {
        setState(() => _procesando = false);
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text('Documento aparentemente duplicado'),
              content: Text('Este documento aparentemente ya fue registrado en el sistema.'),
            ),
          );
        }
        return;
      }

      // Registrar documento.
      final doc = _repo.registrar(
        trabajadorId: _trabajadorId!,
        filename: nombre,
        ruta: destino,
        hash: hash,
        size: await archivo.length(),
      );
      if (doc == null) {
        _notify('Documento aparentemente duplicado. No se registró.');
        return;
      }

      _repo.actualizarEstado(doc.id!, 'PROCESANDO');
      Audit.log('PROCESAR_DOCUMENTO', entidad: 'documentos', entidadId: doc.id, detalle: 'Procesando PDF $nombre');
      _cargar();

      // Verificar si es escaneado (sin texto seleccionable).
      final escaneado = await _pdfService.esEscaneado(destino);
      if (escaneado) {
        _repo.actualizarEstado(doc.id!, 'REQUIERE_REVISION');
        _notify('El PDF parece estar escaneado (sin texto seleccionable). No se pueden extraer datos automáticamente. Requiere revisión manual.');
        Audit.log('PDF_ESCANEADO', entidad: 'documentos', entidadId: doc.id, detalle: 'PDF escaneado, requiere revision manual');
        _cargar();
        return;
      }

      // Procesar PDF.
      final resultado = await _pdfService.parsePdfFile(destino);
      if (resultado.movimientos.isEmpty) {
        _repo.actualizarEstado(doc.id!, 'ERROR');
        _notify('No se pudieron identificar movimientos en el PDF. Revise el documento.');
        Audit.log('PDF_ERROR', entidad: 'documentos', entidadId: doc.id, detalle: 'No se identificaron movimientos');
        _cargar();
        return;
      }

      _repo.actualizarEstado(doc.id!, 'PROCESADO');
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RevisionView(docId: doc.id!, trabajadorId: _trabajadorId!, resultado: resultado),
        ));
      }
    } catch (e) {
      _notify('Error al procesar el PDF: $e');
      Audit.log('PDF_ERROR', entidad: 'documentos', detalle: 'Error: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
      _cargar();
    }
  }

  Future<void> _reabrirRevision(Documento doc) async {
    final estado = _repo.getEstadoAhorroByDocumento(doc.id!);
    if (estado == null) {
      _notify('Este documento aún no tiene estado de ahorro procesado.');
      return;
    }
    if (estado.rawText.isEmpty) {
      _notify('No hay texto extraído para este documento.');
      return;
    }
    final resultado = await _pdfService.parsePdfFile(doc.ruta);
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RevisionView(
          docId: doc.id!,
          trabajadorId: doc.trabajadorId,
          resultado: resultado,
          estadoAhorroId: estado.id,
        ),
      ));
    }
  }

  void _notify(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DOCUMENTOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Estados de Ahorro Previsional de la Gestora', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _trabajadorId,
                  decoration: const InputDecoration(labelText: 'Trabajador'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-- Seleccionar trabajador --')),
                    ..._trabajadores.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombreCompleto))),
                  ],
                  onChanged: (v) => setState(() => _trabajadorId = v),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _procesando ? null : _seleccionarPdf,
                icon: _procesando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: const Text('SUBIR PDF'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDropZone(),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _documentos.isEmpty
                  ? const Center(child: Text('No hay documentos subidos.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Trabajador')),
                          DataColumn(label: Text('Archivo')),
                          DataColumn(label: Text('Tamaño')),
                          DataColumn(label: Text('Fecha carga')),
                          DataColumn(label: Text('Estado')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: _documentos.map((d) {
                          final trab = _trabRepo.getById(d.trabajadorId);
                          return DataRow(cells: [
                            DataCell(Text(trab?.nombreCompleto ?? 'id ${d.trabajadorId}')),
                            DataCell(Text(d.filename, overflow: TextOverflow.ellipsis)),
                            DataCell(Text(_fmtSize(d.fileSize))),
                            DataCell(Text(d.uploadedAt)),
                            DataCell(_estadoChip(d.estado)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (d.estado == 'PROCESADO' || d.estado == 'REQUIERE_REVISION')
                                  IconButton(
                                    icon: const Icon(Icons.task_alt, size: 18, color: AppTheme.primary),
                                    tooltip: 'Revisar datos',
                                    onPressed: () => _reabrirRevision(d),
                                  ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
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
        onTap: _procesando ? null : _seleccionarPdf,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 90,
          decoration: BoxDecoration(
            border: Border.all(
              color: _dragOver ? AppTheme.primary : Colors.grey,
              width: _dragOver ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _dragOver ? AppTheme.primary.withValues(alpha: 0.05) : null,
          ),
          child: Center(
            child: _procesando
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(width: 12),
                    Text('Procesando PDF...'),
                  ])
                : Text('Arrastre y suelte un PDF aquí, o haga clic para seleccionar',
                    style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      ),
    );
  }

  Future<void> _recibirArchivos(List<DropItem> archivos) async {
    setState(() => _dragOver = false);
    if (_trabajadorId == null) {
      _notify('Seleccione un trabajador primero.');
      return;
    }
    if (archivos.isEmpty) return;
    final item = archivos.first;
    final archivo = File(item.path);
    if (!await _esPdfValido(archivo, item.name)) return;
    await _procesarArchivo(archivo, item.name);
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _estadoChip(String estado) {
    final colores = {
      'PENDIENTE': Colors.orange,
      'PROCESANDO': Colors.blue,
      'PROCESADO': Colors.green,
      'REQUIERE_REVISION': Colors.amber,
      'ERROR': Colors.red,
    };
    final color = colores[estado] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(estado.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
