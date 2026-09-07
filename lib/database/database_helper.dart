import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Convierte una fila de sqlite3 (que implementa `Map<String, dynamic>`) a `Map<String, Object?>`.
Map<String, Object?> rowMap(dynamic row) => Map<String, Object?>.from(row as Map<String, dynamic>);

/// Extension para que las filas de sqlite3 (`Map<String, dynamic>`) tengan conversión a `Map<String, Object?>`.
extension RowToMapX on Map<String, dynamic> {
  Map<String, Object?> toMap() => Map<String, Object?>.from(this);
}

/// Gestiona la base de datos SQLite local de EMAP.
/// Todo se almacena localmente en un archivo .db en la carpeta de datos.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;
  String? _dbPath;
  String? _dataDir;

  String get dbPath => _dbPath ?? 'emap.db';
  String get dataDir => _dataDir ?? 'data';

  Database get db {
    if (_db == null) {
      throw StateError('Base de datos no inicializada. Llame a init() primero.');
    }
    return _db!;
  }

  Future<void> init() async {
    if (_db != null) return;
    // Usamos un directorio de datos estable y accesible.
    final documentsDir = await getApplicationDocumentsDirectory();
    _dataDir = p.join(documentsDir.path, 'EMAP');
    if (!Directory(_dataDir!).existsSync()) {
      Directory(_dataDir!).createSync(recursive: true);
    }
    _dbPath = p.join(_dataDir!, 'emap.db');
    _db = sqlite3.open(_dbPath!);
    _db!.execute('PRAGMA foreign_keys = ON;');
    _db!.execute('PRAGMA journal_mode = WAL;');
    _createSchema();
    _seed();
  }

  void _createSchema() {
    db.execute('''
    CREATE TABLE IF NOT EXISTS usuarios (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      nombre TEXT NOT NULL,
      rol TEXT NOT NULL DEFAULT 'OPERADOR',
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS trabajadores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombres TEXT NOT NULL,
      apellido_paterno TEXT NOT NULL,
      apellido_materno TEXT NOT NULL DEFAULT '',
      nombre_completo TEXT NOT NULL,
      ci TEXT NOT NULL,
      cua TEXT NOT NULL DEFAULT '',
      cargo TEXT NOT NULL DEFAULT '',
      area TEXT NOT NULL DEFAULT '',
      estado TEXT NOT NULL DEFAULT 'ACTIVO',
      created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS documentos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trabajador_id INTEGER NOT NULL,
      filename TEXT NOT NULL,
      file_hash TEXT NOT NULL DEFAULT '',
      file_size INTEGER NOT NULL DEFAULT 0,
      ruta TEXT NOT NULL DEFAULT '',
      estado TEXT NOT NULL DEFAULT 'PENDIENTE',
      uploaded_by INTEGER,
      uploaded_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id),
      FOREIGN KEY (uploaded_by) REFERENCES usuarios(id)
    );

    CREATE TABLE IF NOT EXISTS estados_ahorro (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      documento_id INTEGER NOT NULL,
      trabajador_id INTEGER NOT NULL,
      numero_estado TEXT DEFAULT '',
      periodo TEXT DEFAULT '',
      fecha_emision TEXT DEFAULT '',
      estado TEXT NOT NULL DEFAULT 'REQUIERE_REVISION',
      raw_text TEXT DEFAULT '',
      created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (documento_id) REFERENCES documentos(id),
      FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id)
    );

    CREATE TABLE IF NOT EXISTS movimientos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      estado_ahorro_id INTEGER NOT NULL,
      trabajador_id INTEGER NOT NULL,
      anio INTEGER NOT NULL,
      mes INTEGER NOT NULL,
      empleador TEXT NOT NULL DEFAULT '',
      tipo_movimiento TEXT NOT NULL DEFAULT 'APORTE_LABORAL',
      total_ganado REAL NOT NULL DEFAULT 0,
      dias_trabajados INTEGER NOT NULL DEFAULT 0,
      cotizacion_mensual REAL NOT NULL DEFAULT 0,
      aporte_voluntario REAL NOT NULL DEFAULT 0,
      aporte_beneficio_social REAL NOT NULL DEFAULT 0,
      comision REAL NOT NULL DEFAULT 0,
      total_aportes REAL NOT NULL DEFAULT 0,
      valor_cuota REAL NOT NULL DEFAULT 0,
      total_numero_cuotas REAL NOT NULL DEFAULT 0,
      fecha_pago TEXT DEFAULT '',
      afp REAL NOT NULL DEFAULT 0,
      liquido_pagable REAL NOT NULL DEFAULT 0,
      original_total_ganado REAL,
      original_afp REAL,
      original_liquido REAL,
      original_dias INTEGER,
      requiere_revision INTEGER NOT NULL DEFAULT 0,
      revision_nota TEXT DEFAULT '',
      created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (estado_ahorro_id) REFERENCES estados_ahorro(id),
      FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id)
    );

    CREATE TABLE IF NOT EXISTS correcciones_movimiento (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      movimiento_id INTEGER NOT NULL,
      campo TEXT NOT NULL,
      valor_original TEXT NOT NULL DEFAULT '',
      valor_nuevo TEXT NOT NULL DEFAULT '',
      usuario_id INTEGER,
      usuario_nombre TEXT DEFAULT '',
      fecha TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (movimiento_id) REFERENCES movimientos(id)
    );

    CREATE TABLE IF NOT EXISTS certificados (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trabajador_id INTEGER NOT NULL,
      numero TEXT DEFAULT '',
      fecha_desde TEXT DEFAULT '',
      fecha_hasta TEXT DEFAULT '',
      total_ganado REAL NOT NULL DEFAULT 0,
      total_afp REAL NOT NULL DEFAULT 0,
      total_liquido REAL NOT NULL DEFAULT 0,
      total_dias INTEGER NOT NULL DEFAULT 0,
      generado_por INTEGER,
      created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id),
      FOREIGN KEY (generado_por) REFERENCES usuarios(id)
    );

    CREATE TABLE IF NOT EXISTS auditoria (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER,
      usuario_nombre TEXT DEFAULT '',
      accion TEXT NOT NULL,
      entidad TEXT DEFAULT '',
      entidad_id INTEGER,
      detalle TEXT DEFAULT '',
      fecha TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
    );

    CREATE TABLE IF NOT EXISTS configuracion (
      clave TEXT PRIMARY KEY,
      valor TEXT NOT NULL DEFAULT '',
      descripcion TEXT DEFAULT '',
      solo_admin INTEGER NOT NULL DEFAULT 1,
      updated_by INTEGER,
      updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
    );
    ''');
  }

  void _seed() {
    final row = db.select('SELECT id FROM usuarios WHERE username = ?', ['admin']);
    if (row.isEmpty) {
      db.execute(
        "INSERT INTO usuarios (username, password_hash, nombre, rol) VALUES (?,?,?,?)",
        ['admin', SecurityUtils.hashPassword('admin123'), 'Administrador', 'ADMINISTRADOR'],
      );
    }

    final defs = <List<Object?>>[
      ['afp_campo', 'TOTAL_APORTES', 'Campo del documento que se usa como APORTES A.F.P.', 1],
      ['liquido_formula', 'MANUAL', 'Forma de calcular liquido pagable: MANUAL | TOTAL_GANADO_MENOS_AFP | LIBRE', 1],
      ['entidad_nombre', 'ENTIDAD MUNICIPAL DE ASEO POTOSÍ', 'Nombre institucional para certificados', 1],
      ['entidad_ciudad', 'Potosí - Bolivia', 'Ciudad institucional', 1],
      ['max_pdf_mb', '20', 'Tamaño maximo permitido de PDF en MB', 0],
      ['trabajador_ruta_pdf', '', 'Carpeta donde se guardan los PDF (vacio = carpeta de datos EMAP)', 0],
    ];
    final existing = db.select('SELECT clave FROM configuracion');
    final keys = existing.map((e) => e['clave'] as String).toSet();
    for (final d in defs) {
      if (!keys.contains(d[0])) {
        db.execute(
          'INSERT INTO configuracion (clave, valor, descripcion, solo_admin) VALUES (?,?,?,?)',
          d,
        );
      }
    }
  }

  void close() => _db?.dispose();
}

/// Utilidades de seguridad local (hash de contraseñas).
class SecurityUtils {
  static String hashPassword(String password) {
    final bytes = utf8.encode('emap_salt::$password');
    final digest = sha256.convert(bytes);
    return 'v1_${digest.toString()}';
  }

  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }

  static String sha256File(List<int> data) {
    return sha256.convert(data).toString();
  }
}
