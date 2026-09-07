import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import '../repositories/auth_repository.dart';

/// Estado global de sesion de la aplicacion.
class SessionProvider extends ChangeNotifier {
  final AuthRepository _auth = AuthRepository.instance;

  bool get isLoggedIn => _auth.isLoggedIn;

  Usuario? get user => _auth.currentUser;

  bool get esAdmin => _auth.currentUser?.esAdministrador ?? false;

  bool login(String username, String password) {
    final ok = _auth.login(username, password);
    if (ok) notifyListeners();
    return ok;
  }

  void logout() {
    _auth.logout();
    notifyListeners();
  }
}
