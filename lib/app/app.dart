import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import 'theme.dart';
import '../views/login/login_view.dart';
import '../views/main_shell.dart';

class EmapApp extends StatelessWidget {
  const EmapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionProvider(),
      child: MaterialApp(
        title: 'EMAP - Sistema de Certificación de Aportaciones',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _RootView(),
      ),
    );
  }
}

class _RootView extends StatelessWidget {
  const _RootView();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return session.isLoggedIn ? const MainShell() : const LoginView();
  }
}
