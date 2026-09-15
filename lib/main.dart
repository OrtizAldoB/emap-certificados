import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar ventana de escritorio.
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 760),
    minimumSize: Size(1100, 680),
    center: true,
    title: 'EMAP - Extracción de Aportaciones (PDF)',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const EmapApp());
}