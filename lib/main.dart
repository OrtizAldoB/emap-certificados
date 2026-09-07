import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'database/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar la base de datos local.
  await DatabaseHelper.instance.init();

  // Configurar ventana de escritorio.
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 760),
    minimumSize: Size(1100, 680),
    center: true,
    title: 'EMAP - Sistema de Certificación de Aportaciones',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const EmapApp());
}
