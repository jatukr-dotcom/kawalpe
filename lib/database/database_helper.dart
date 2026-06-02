// =========================================================
// database/database_helper.dart - Helper SQLite lokal
// =========================================================
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/project.dart';
import '../models/planting_point.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// Dapatkan instance database, buat jika belum ada
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kawal_pe.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Migrasi database antar versi
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Tambah kolom penanggungjawab ke tabel projects
      await db.execute(
        'ALTER TABLE projects ADD COLUMN penanggungjawab TEXT'
      );
    }
  }

  /// Buat tabel saat pertama kali membuka database
  Future<void> _onCreate(Database db, int version) async {
    // Tabel proyek
    await db.execute('''
      CREATE TABLE projects (
        id                TEXT PRIMARY KEY,
        nama_proyek       TEXT NOT NULL,
        lokasi            TEXT NOT NULL,
        deskripsi         TEXT,
        tanggal_mulai     TEXT NOT NULL,
        tanggal_selesai   TEXT,
        created_by_device TEXT NOT NULL,
        created_at        TEXT NOT NULL,
        synced_to_server  INTEGER DEFAULT 0
      )
    ''');

    // Tabel titik tanam
    await db.execute('''
      CREATE TABLE planting_points (
        id              TEXT PRIMARY KEY,
        project_id      TEXT NOT NULL,
        latitude        REAL NOT NULL,
        longitude       REAL NOT NULL,
        accuracy        REAL,
        spesies         TEXT NOT NULL,
        kondisi         TEXT NOT NULL,
        catatan         TEXT,
        foto_local_path TEXT,
        foto_cloud_url  TEXT,
        device_id       TEXT NOT NULL,
        timestamp       TEXT NOT NULL,
        synced          INTEGER DEFAULT 0,
        sync_attempt    INTEGER DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects(id)
      )
    ''');

    // Index untuk performa query
    await db.execute(
        'CREATE INDEX idx_points_project ON planting_points(project_id)');
    await db.execute(
        'CREATE INDEX idx_points_synced ON planting_points(synced)');
  }

  // =========================================================
  // OPERASI PROYEK
  // =========================================================

  /// Simpan proyek baru ke database lokal
  Future<void> insertProject(Project project) async {
    final db = await database;
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil semua proyek dengan statistik titik
  Future<List<Project>> getAllProjects() async {
    final db = await database;

    // Query join untuk mendapatkan jumlah titik per proyek
    final result = await db.rawQuery('''
      SELECT 
        p.*,
        COUNT(pp.id) as jumlah_titik,
        SUM(CASE WHEN pp.synced = 0 THEN 1 ELSE 0 END) as jumlah_belum_sync
      FROM projects p
      LEFT JOIN planting_points pp ON p.id = pp.project_id
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''');

    return result.map((map) {
      final project = Project.fromMap(map);
      project.jumlahTitik = (map['jumlah_titik'] as int?) ?? 0;
      project.jumlahBelumSync = (map['jumlah_belum_sync'] as int?) ?? 0;
      return project;
    }).toList();
  }

  /// Ambil satu proyek berdasarkan ID
  Future<Project?> getProjectById(String id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        p.*,
        COUNT(pp.id) as jumlah_titik,
        SUM(CASE WHEN pp.synced = 0 THEN 1 ELSE 0 END) as jumlah_belum_sync
      FROM projects p
      LEFT JOIN planting_points pp ON p.id = pp.project_id
      WHERE p.id = ?
      GROUP BY p.id
    ''', [id]);

    if (result.isEmpty) return null;
    final project = Project.fromMap(result.first);
    project.jumlahTitik = (result.first['jumlah_titik'] as int?) ?? 0;
    project.jumlahBelumSync = (result.first['jumlah_belum_sync'] as int?) ?? 0;
    return project;
  }

  /// Tandai proyek sudah sync ke server
  Future<void> markProjectSynced(String projectId) async {
    final db = await database;
    await db.update(
      'projects',
      {'synced_to_server': 1},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  /// Hapus proyek dan semua titiknya
  Future<void> deleteProject(String projectId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'planting_points',
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      await txn.delete(
        'projects',
        where: 'id = ?',
        whereArgs: [projectId],
      );
    });
  }

  /// Cek apakah proyek sudah ada di lokal
  Future<bool> projectExists(String projectId) async {
    final db = await database;
    final result = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // =========================================================
  // OPERASI TITIK TANAM
  // =========================================================

  /// Simpan titik tanam baru
  Future<void> insertPoint(PlantingPoint point) async {
    final db = await database;
    await db.insert(
      'planting_points',
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil semua titik dalam proyek (max 100 terbaru)
  Future<List<PlantingPoint>> getPointsByProject(String projectId,
      {int limit = 100}) async {
    final db = await database;
    final result = await db.query(
      'planting_points',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((map) => PlantingPoint.fromMap(map)).toList();
  }

  /// Ambil titik yang belum tersync (untuk upload)
  Future<List<PlantingPoint>> getUnsyncedPoints({String? projectId}) async {
    final db = await database;
    String where = 'synced = 0';
    List<dynamic> whereArgs = [];

    if (projectId != null) {
      where += ' AND project_id = ?';
      whereArgs.add(projectId);
    }

    final result = await db.query(
      'planting_points',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp ASC',
    );
    return result.map((map) => PlantingPoint.fromMap(map)).toList();
  }

  /// Tandai titik sudah tersync, update URL foto cloud
  Future<void> markPointSynced(String pointId, {String? fotoCloudUrl}) async {
    final db = await database;
    final updateMap = <String, dynamic>{'synced': 1};
    if (fotoCloudUrl != null) {
      updateMap['foto_cloud_url'] = fotoCloudUrl;
    }
    await db.update(
      'planting_points',
      updateMap,
      where: 'id = ?',
      whereArgs: [pointId],
    );
  }

  /// Tambah hitungan percobaan sync yang gagal
  Future<void> incrementSyncAttempt(String pointId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE planting_points SET sync_attempt = sync_attempt + 1 WHERE id = ?',
      [pointId],
    );
  }

  /// Hapus satu titik tanam
  Future<void> deletePoint(String pointId) async {
    final db = await database;
    await db.delete(
      'planting_points',
      where: 'id = ?',
      whereArgs: [pointId],
    );
  }

  // =========================================================
  // STATISTIK GLOBAL
  // =========================================================

  /// Ambil statistik global untuk halaman utama
  Future<Map<String, int>> getGlobalStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT p.id) as total_proyek,
        COUNT(pp.id) as total_titik,
        SUM(CASE WHEN pp.synced = 0 THEN 1 ELSE 0 END) as belum_sync
      FROM projects p
      LEFT JOIN planting_points pp ON p.id = pp.project_id
    ''');

    if (result.isEmpty) return {'total_proyek': 0, 'total_titik': 0, 'belum_sync': 0};

    return {
      'total_proyek': (result.first['total_proyek'] as int?) ?? 0,
      'total_titik': (result.first['total_titik'] as int?) ?? 0,
      'belum_sync': (result.first['belum_sync'] as int?) ?? 0,
    };
  }

  /// Hitung total titik belum sync (untuk badge di AppBar)
  Future<int> countUnsyncedTotal() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM planting_points WHERE synced = 0',
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
