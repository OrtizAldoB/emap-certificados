import 'package:flutter/material.dart';

import '../views/procesar/procesar_view.dart';
import 'theme.dart';

class EmapApp extends StatelessWidget {
  const EmapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMAP - Extracción de Aportaciones (PDF)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ProcesarView(),
    );
  }
}