import 'package:flutter/material.dart';

import '../../repositories/auditoria_repository.dart';

class AuditoriaView extends StatefulWidget {
  const AuditoriaView({super.key});

  @override
  State<AuditoriaView> createState() => _AuditoriaViewState();
}

class _AuditoriaViewState extends State<AuditoriaView> {
  final _repo = AuditoriaRepository();
  List<Auditoria> _list = [];
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _list = _repo.listar(usuario: _filtro);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AUDITORÍA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Registro de acciones del sistema', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filtrar por usuario...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    _filtro = v;
                    _cargar();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: _list.isEmpty
                  ? const Center(child: Text('Sin registros.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Fecha')),
                          DataColumn(label: Text('Usuario')),
                          DataColumn(label: Text('Acción')),
                          DataColumn(label: Text('Entidad')),
                          DataColumn(label: Text('Detalle')),
                        ],
                        rows: _list.map((a) => DataRow(cells: [
                          DataCell(Text(a.fecha, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(a.usuarioNombre ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(a.accion, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataCell(Text(a.entidad, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(a.detalle, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        ])).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}