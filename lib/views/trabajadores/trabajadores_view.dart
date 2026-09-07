import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/trabajador.dart';
import '../../repositories/trabajador_repository.dart';
import '../../providers/session_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../aportaciones/aportaciones_view.dart';

class TrabajadoresView extends StatefulWidget {
  const TrabajadoresView({super.key});

  @override
  State<TrabajadoresView> createState() => _TrabajadoresViewState();
}

class _TrabajadoresViewState extends State<TrabajadoresView> {
  final _repo = TrabajadorRepository();
  final _busqueda = TextEditingController();
  List<Trabajador> _list = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _cargar() {
    setState(() {
      _list = _repo.listar(query: _query);
    });
  }

  Future<void> _nuevo() async {
    final nuevo = await showDialog<Trabajador>(
      context: context,
      builder: (_) => TrabajadorFormDialog(),
    );
    if (nuevo != null) _cargar();
  }

  Future<void> _editar(Trabajador t) async {
    final actualizado = await showDialog<Trabajador>(
      context: context,
      builder: (_) => TrabajadorFormDialog(trabajador: t),
    );
    if (actualizado != null) _cargar();
  }

  Future<void> _eliminar(Trabajador t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmDialog(
        titulo: 'Eliminar trabajador',
        mensaje: '¿Desea eliminar este trabajador? No se puede eliminar si tiene documentos.',
      ),
    );
    if (ok == true) {
      final r = _repo.eliminar(t.id!);
      if (!r && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar: el trabajador tiene documentos asociados.')),
        );
      }
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = context.watch<SessionProvider>().esAdmin;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TRABAJADORES', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busqueda,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, C.I. o CUA...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    _query = v;
                    _cargar();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _nuevo,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo trabajador'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _list.isEmpty
                  ? const Center(child: Text('No hay trabajadores registrados.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Nombre completo')),
                          DataColumn(label: Text('C.I.')),
                          DataColumn(label: Text('CUA')),
                          DataColumn(label: Text('Cargo')),
                          DataColumn(label: Text('Área')),
                          DataColumn(label: Text('Estado')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: _list.map((t) => DataRow(cells: [
                          DataCell(Text(t.nombreCompleto)),
                          DataCell(Text(t.ci)),
                          DataCell(Text(t.cua)),
                          DataCell(Text(t.cargo)),
                          DataCell(Text(t.area)),
                          DataCell(_estadoChip(t.estado)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Editar',
                                onPressed: () => _editar(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Eliminar',
                                onPressed: esAdmin ? () => _eliminar(t) : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                tooltip: 'Ver aportaciones',
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => AportacionesView.init(t.id!),
                                  ));
                                },
                              ),
                            ],
                          )),
                        ])).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final color = estado == 'ACTIVO' ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(estado, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class TrabajadorFormDialog extends StatefulWidget {
  final Trabajador? trabajador;
  const TrabajadorFormDialog({super.key, this.trabajador});

  @override
  State<TrabajadorFormDialog> createState() => _TrabajadorFormDialogState();
}

class _TrabajadorFormDialogState extends State<TrabajadorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombres;
  late final TextEditingController _ap;
  late final TextEditingController _am;
  late final TextEditingController _ci;
  late final TextEditingController _cua;
  late final TextEditingController _cargo;
  late final TextEditingController _area;
  String _estado = 'ACTIVO';

  @override
  void initState() {
    super.initState();
    final t = widget.trabajador;
    _nombres = TextEditingController(text: t?.nombres ?? '');
    _ap = TextEditingController(text: t?.apellidoPaterno ?? '');
    _am = TextEditingController(text: t?.apellidoMaterno ?? '');
    _ci = TextEditingController(text: t?.ci ?? '');
    _cua = TextEditingController(text: t?.cua ?? '');
    _cargo = TextEditingController(text: t?.cargo ?? '');
    _area = TextEditingController(text: t?.area ?? '');
    _estado = t?.estado ?? 'ACTIVO';
  }

  @override
  void dispose() {
    _nombres.dispose(); _ap.dispose(); _am.dispose();
    _ci.dispose(); _cua.dispose(); _cargo.dispose(); _area.dispose();
    super.dispose();
  }

  String _nombreCompleto() =>
      '${_nombres.text.trim()} ${_ap.text.trim()} ${_am.text.trim()}'.trim();

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final t = Trabajador(
      id: widget.trabajador?.id,
      nombres: _nombres.text.trim(),
      apellidoPaterno: _ap.text.trim(),
      apellidoMaterno: _am.text.trim(),
      nombreCompleto: _nombreCompleto(),
      ci: _ci.text.trim(),
      cua: _cua.text.trim(),
      cargo: _cargo.text.trim(),
      area: _area.text.trim(),
      estado: _estado,
    );
    final repo = TrabajadorRepository();
    if (t.id == null) {
      repo.crear(t);
    } else {
      repo.actualizar(t);
    }
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.trabajador == null ? 'Nuevo trabajador' : 'Editar trabajador'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_nombres, 'Nombres', required: true),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_ap, 'Apellido paterno', required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_am, 'Apellido materno')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_ci, 'C.I.', required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_cua, 'CUA')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_cargo, 'Cargo')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_area, 'Área')),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: ['ACTIVO', 'INACTIVO'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _estado = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {bool required = false}) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
            : null,
      );
}
