import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../providers/session_provider.dart';
import 'dashboard/dashboard_view.dart';
import 'trabajadores/trabajadores_view.dart';
import 'documentos/documentos_view.dart';
import 'aportaciones/aportaciones_view.dart';
import 'certificados/certificados_view.dart';
import 'reportes/reportes_view.dart';
import 'usuarios/usuarios_view.dart';
import 'configuracion/configuracion_view.dart';
import 'auditoria/auditoria_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _views = [
    const DashboardView(),
    const TrabajadoresView(),
    const DocumentosView(),
    const AportacionesView(),
    const CertificadosView(),
    const ReportesView(),
    const UsuariosView(),
    const ConfiguracionView(),
    const AuditoriaView(),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final esAdmin = session.esAdmin;

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context, session, esAdmin),
          Expanded(
            child: SafeArea(child: _views[_index]),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, SessionProvider session, bool esAdmin) {
    final items = <({int idx, IconData icon, String label})>[
      (idx: 0, icon: Icons.dashboard_outlined, label: 'Dashboard'),
      (idx: 1, icon: Icons.people_outline, label: 'Trabajadores'),
      (idx: 2, icon: Icons.description_outlined, label: 'Documentos'),
      (idx: 3, icon: Icons.receipt_long_outlined, label: 'Aportaciones'),
      (idx: 4, icon: Icons.badge_outlined, label: 'Certificados'),
      (idx: 5, icon: Icons.bar_chart_outlined, label: 'Reportes'),
      if (esAdmin) (idx: 6, icon: Icons.admin_panel_settings_outlined, label: 'Usuarios'),
      if (esAdmin) (idx: 7, icon: Icons.settings_outlined, label: 'Configuración'),
      (idx: 8, icon: Icons.history, label: 'Auditoría'),
    ];

    return Container(
      width: 210,
      color: AppTheme.sidebar,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 16),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.apartment, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EMAP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Aportaciones', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: items.map((it) {
                final selected = _index == it.idx;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: selected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(it.icon, color: selected ? Colors.white : Colors.white70, size: 20),
                      title: Text(it.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          )),
                      onTap: () => setState(() => _index = it.idx),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.user?.nombre ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      Text(session.user?.rol ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                  tooltip: 'Cerrar sesión',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text('¿Desea cerrar la sesión?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(c);
                              context.read<SessionProvider>().logout();
                            },
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
