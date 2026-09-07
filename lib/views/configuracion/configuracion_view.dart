import 'package:flutter/material.dart';

import '../../repositories/configuracion_repository.dart';

class ConfiguracionView extends StatefulWidget {
  const ConfiguracionView({super.key});

  @override
  State<ConfiguracionView> createState() => _ConfiguracionViewState();
}

class _ConfiguracionViewState extends State<ConfiguracionView> {
  final _repo = ConfiguracionRepository();
  late Map<String, String> _config;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _afpCampo;
  late TextEditingController _liquidoFormula;
  late TextEditingController _entidadNombre;
  late TextEditingController _entidadCiudad;
  late TextEditingController _maxPdf;
  late TextEditingController _rutaPdf;

  @override
  void initState() {
    super.initState();
    _config = _repo.obtenerTodas();
    _afpCampo = TextEditingController(text: _config['afp_campo'] ?? 'TOTAL_APORTES');
    _liquidoFormula = TextEditingController(text: _config['liquido_formula'] ?? 'MANUAL');
    _entidadNombre = TextEditingController(text: _config['entidad_nombre'] ?? '');
    _entidadCiudad = TextEditingController(text: _config['entidad_ciudad'] ?? '');
    _maxPdf = TextEditingController(text: _config['max_pdf_mb'] ?? '20');
    _rutaPdf = TextEditingController(text: _config['trabajador_ruta_pdf'] ?? '');
  }

  @override
  void dispose() {
    _afpCampo.dispose(); _liquidoFormula.dispose(); _entidadNombre.dispose();
    _entidadCiudad.dispose(); _maxPdf.dispose(); _rutaPdf.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    _repo.set('afp_campo', _afpCampo.text);
    _repo.set('liquido_formula', _liquidoFormula.text);
    _repo.set('entidad_nombre', _entidadNombre.text);
    _repo.set('entidad_ciudad', _entidadCiudad.text);
    _repo.set('max_pdf_mb', _maxPdf.text, soloAdmin: false);
    _repo.set('trabajador_ruta_pdf', _rutaPdf.text, soloAdmin: false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración guardada.')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONFIGURACIÓN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Parámetros del sistema (solo administrador)', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _afpCampo.text,
                      decoration: const InputDecoration(labelText: 'Campo usado como APORTES A.F.P.'),
                      items: const [
                        DropdownMenuItem(value: 'TOTAL_APORTES', child: Text('Total Aportes')),
                        DropdownMenuItem(value: 'COTIZACION_MENSUAL', child: Text('Cotización Mensual')),
                        DropdownMenuItem(value: 'APORTE_VOLUNTARIO', child: Text('Aporte Voluntario')),
                        DropdownMenuItem(value: 'COMISION', child: Text('Comisión')),
                      ],
                      onChanged: (v) => setState(() => _afpCampo.text = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _liquidoFormula.text,
                      decoration: const InputDecoration(labelText: 'Fórmula líquido pagable'),
                      items: const [
                        DropdownMenuItem(value: 'MANUAL', child: Text('Manual (el operador ingresa el valor)')),
                        DropdownMenuItem(value: 'TOTAL_GANADO_MENOS_AFP', child: Text('Total ganado - AFP')),
                      ],
                      onChanged: (v) => setState(() => _liquidoFormula.text = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _entidadNombre,
                      decoration: const InputDecoration(labelText: 'Nombre institucional'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _entidadCiudad,
                      decoration: const InputDecoration(labelText: 'Ciudad'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxPdf,
                      decoration: const InputDecoration(labelText: 'Tamaño máximo de PDF (MB)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Debe ser un número' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rutaPdf,
                      decoration: const InputDecoration(
                        labelText: 'Carpeta de almacenamiento de PDF/exportaciones',
                        hintText: 'Dejar vacío para usar la carpeta de datos de EMAP',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _guardar,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar configuración'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}