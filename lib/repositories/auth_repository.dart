import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../utils/audit.dart';

class AuthRepository {
  AuthRepository._internal();
  static final AuthRepository instance = AuthRepository._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  Usuario? _currentUser;

  Usuario? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  /// Intenta iniciar sesion con las credenciales locales.
  bool login(String username, String password) {
    final rows = _db.db.select(
      'SELECT * FROM usuarios WHERE username = ? AND activo = 1',
      [username],
    );
    if (rows.isEmpty) return false;
    final user = Usuario.fromRow(rows.first.toMap());
    if (!SecurityUtils.verifyPassword(password, user.passwordHash)) return false;
    _currentUser = user;
    Audit.log('INICIO_SESION', entidad: 'usuarios', entidadId: user.id, detalle: 'El usuario ${user.username} inició sesión');
    return true;
  }

  void logout() {
    final u = _currentUser;
    if (u != null) {
      Audit.log('CIERRE_SESION', entidad: 'usuarios', entidadId: u.id, detalle: 'El usuario ${u.username} cerró sesión');
    }
    _currentUser = null;
  }

  // ---- Gestion de usuarios (SOLO ADMIN) ----

  List<Usuario> listUsuarios() {
    return _db.db
        .select('SELECT * FROM usuarios ORDER BY nombre')
        .map((r) => Usuario.fromRow(r.toMap()))
        .toList();
  }

  bool crearUsuario(Usuario u) {
    try {
      _db.db.execute(
        'INSERT INTO usuarios (username, password_hash, nombre, rol) VALUES (?,?,?,?)',
        [u.username, SecurityUtils.hashPassword(u.passwordHash), u.nombre, u.rol],
      );
      Audit.log('CREAR_USUARIO', entidad: 'usuarios', detalle: 'Creó el usuario ${u.username}');
      return true;
    } catch (_) {
      return false;
    }
  }

  void actualizarUsuario(int id, String nombre, String rol, {String? nuevaPassword, bool? activo}) {
    if (nuevaPassword != null && nuevaPassword.isNotEmpty) {
      _db.db.execute(
        'UPDATE usuarios SET nombre=?, rol=?, password_hash=? WHERE id=?',
        [nombre, rol, SecurityUtils.hashPassword(nuevaPassword), id],
      );
    } else {
      _db.db.execute('UPDATE usuarios SET nombre=?, rol=? WHERE id=?', [nombre, rol, id]);
    }
    if (activo != null) {
      _db.db.execute('UPDATE usuarios SET activo=? WHERE id=?', [activo ? 1 : 0, id]);
    }
    Audit.log('EDITAR_USUARIO', entidad: 'usuarios', entidadId: id, detalle: 'Editó el usuario id=$id');
  }

  void eliminarUsuario(int id) {
    _db.db.execute('DELETE FROM usuarios WHERE id=?', [id]);
    Audit.log('ELIMINAR_USUARIO', entidad: 'usuarios', entidadId: id, detalle: 'Eliminó el usuario id=$id');
  }
}
