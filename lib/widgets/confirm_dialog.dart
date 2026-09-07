import 'package:flutter/material.dart';

/// Dialogo de confirmacion generico.
class ConfirmDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String textoBoton;

  const ConfirmDialog({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.textoBoton = 'Aceptar',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(textoBoton),
        ),
      ],
    );
  }
}
