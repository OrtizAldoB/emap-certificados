import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/usuario.dart';
import '../../widgets/confirm_dialog.dart';
import '../../repositories/auth_repository.dart';

class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final _repo = AuthRepository.instance;
  List<Usuario> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() => setState(() => _usuarios = _repo.listUsuarios());

  Future<void> _nuevo() async {
    await showDialog(context: context, builder: (_) => _UsuarioFormDialog());
    _cargar();
  }

  Future<void> _editar(Usuario u) async {
    await showDialog(context: context, builder: (_) => _UsuarioFormDialog(usuario: u));
    _cargar();
  }

  Future<void> _eliminar(Usuario u) async {
    if (u.username == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede eliminar el usuario admin.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(titulo: 'Eliminar usuario', mensaje: '¿Desea eliminar al usuario ${u.username}?'),
    );
    if (ok == true) {
      _repo.eliminarUsuario(u.id!);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('USUARIOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Gestión de usuarios y roles (solo administrador)', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _nuevo,
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo usuario'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Rol')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: _usuarios.map((u) => DataRow(cells: [
                    DataCell(Text(u.username)),
                    DataCell(Text(u.nombre)),
                    DataCell(_rolChip(u.rol)),
                    DataCell(u.activo ? const Text('Activo', style: TextStyle(color: Colors.green)) : const Text('Inactivo', style: TextStyle(color: Colors.red))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _editar(u)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _eliminar(u)),
                    ])),
                  ])).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rolChip(String rol) {
    final color = rol == 'ADMINISTRADOR' ? AppTheme.primary : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(rol, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _UsuarioFormDialog extends StatefulWidget {
  final Usuario? usuario;
  const _UsuarioFormDialog({this.usuario});

  @override
  State<_UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<_UsuarioFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _nombre;
  late final TextEditingController _password;
  String _rol = 'OPERADOR';
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.usuario?.username ?? '');
    _nombre = TextEditingController(text: widget.usuario?.nombre ?? '');
    _password = TextEditingController();
    _rol = widget.usuario?.rol ?? 'OPERADOR';
    _activo = widget.usuario?.activo ?? true;
  }

  @override
  void dispose() {
    _username.dispose();
    _nombre.dispose();
    _password.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final u = widget.usuario;
    final repo = AuthRepository.instance;
    if (u == null) {
      repo.crearUsuario(Usuario(
        username: _username.text.trim(),
        passwordHash: _password.text,
        nombre: _nombre.text.trim(),
        rol: _rol,
      ));
    } else {
      repo.actualizarUsuario(u.id!, _nombre.text.trim(), _rol,
          nuevaPassword: _password.text, activo: _activo);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.usuario != null;
    return AlertDialog(
      title: Text(editando ? 'Editar usuario' : 'Nuevo usuario'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!editando)
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre completo', isDense: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: editando ? 'Nueva contraseña (opcional)' : 'Contraseña',
                  isDense: true,
                ),
                obscureText: true,
                validator: editando ? null : (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'OPERADOR', child: Text('OPERADOR')),
                  DropdownMenuItem(value: 'ADMINISTRADOR', child: Text('ADMINISTRADOR')),
                ],
                onChanged: (v) => setState(() => _rol = v!),
              ),
              if (editando) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}