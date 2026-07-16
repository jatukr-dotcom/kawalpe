// =========================================================
// services/sync_service.dart - Sinkronisasi data ke Supabase & Cloudinary
// =========================================================
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/database_helper.dart';
import '../models/app_user.dart';
import '../models/project.dart';
import '../models/planting_point.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper();

  // =========================================================
  // KONFIGURASI
  // =========================================================

  /// Ambil konfigurasi dari SharedPreferences
  Future<Map<String, String>> _getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'supabase_url': prefs.getString('supabase_url') ?? '',
      'supabase_anon_key': prefs.getString('supabase_anon_key') ?? '',
      'cloudinary_cloud_name': prefs.getString('cloudinary_cloud_name') ?? '',
      'cloudinary_upload_preset': prefs.getString('cloudinary_upload_preset') ?? '',
    };
  }

  /// Cek apakah konfigurasi server sudah lengkap
  Future<bool> isConfigured() async {
    final config = await _getConfig();
    return config['supabase_url']!.isNotEmpty &&
        config['supabase_anon_key']!.isNotEmpty &&
        config['cloudinary_cloud_name']!.isNotEmpty &&
        config['cloudinary_upload_preset']!.isNotEmpty;
  }

  /// Cek konektivitas internet
  Future<bool> isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return !connectivity.contains(ConnectivityResult.none);
  }

  /// Dapatkan instance Supabase client
  SupabaseClient? _getSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('SyncService: Supabase belum diinisialisasi: $e');
      return null;
    }
  }

  // =========================================================
  // PUSH: Upload ke Server
  // =========================================================

  /// Upload satu proyek ke Supabase (jika belum ada)
  Future<bool> pushProject(String projectId) async {
    final client = _getSupabaseClient();
    if (client == null) return false;

    try {
      // Ambil proyek dari DB lokal
      final project = await _db.getProjectById(projectId);
      if (project == null) return false;

      // Jika sudah sync, skip
      if (project.syncedToServer) return true;

      // Cek apakah proyek sudah ada di Supabase
      final existing = await client
          .from('projects')
          .select('id')
          .eq('id', projectId)
          .maybeSingle();

      if (existing == null) {
        // Belum ada → insert ke Supabase
        await client.from('projects').insert(project.toSupabaseMap());
      }

      // Update status lokal
      await _db.markProjectSynced(projectId);
      debugPrint('SyncService: Proyek $projectId berhasil di-push');
      return true;
    } catch (e) {
      debugPrint('SyncService: Gagal push proyek $projectId: $e');
      return false;
    }
  }

  /// Upload semua titik yang belum tersync
  ///
  /// [projectId]: jika null, upload semua proyek.
  /// Mengembalikan SyncResult dengan jumlah berhasil/gagal.
  Future<SyncResult> pushPoints({String? projectId}) async {
    final client = _getSupabaseClient();
    if (client == null) {
      return SyncResult(
        success: 0,
        failed: 0,
        errorMessages: ['Supabase belum dikonfigurasi. Buka Pengaturan.'],
      );
    }

    if (!await isOnline()) {
      return SyncResult(
        success: 0,
        failed: 0,
        errorMessages: ['Tidak ada koneksi internet.'],
      );
    }

    final config = await _getConfig();
    int successCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    // Ambil titik yang belum tersync
    final unsyncedPoints = await _db.getUnsyncedPoints(projectId: projectId);
    debugPrint('SyncService: ${unsyncedPoints.length} titik akan di-sync');

    for (final point in unsyncedPoints) {
      try {
        // 1. Push proyek dulu jika belum sync
        final projectSynced = await pushProject(point.projectId);
        if (!projectSynced) {
          await _db.incrementSyncAttempt(point.id);
          failedCount++;
          errors.add('Gagal push proyek untuk titik ${point.id}');
          continue;
        }

        // 2. Upload foto ke Cloudinary
        // Jika foto_cloud_url sudah ada (crash sebelumnya), skip upload
        String? fotoCloudUrl = point.fotoCloudUrl;
        if (fotoCloudUrl == null || fotoCloudUrl.isEmpty) {
          if (point.fotoLocalPath != null && point.fotoLocalPath!.isNotEmpty) {
            fotoCloudUrl = await _uploadToCloudinary(
              imagePath: point.fotoLocalPath!,
              projectId: point.projectId,
              config: config,
            );
          }
        } else {
          debugPrint('SyncService: Foto sudah di-upload sebelumnya, skip upload → $fotoCloudUrl');
        }

        // 3. Upsert titik ke Supabase (handle duplikat)
        final pointData = point.toSupabaseMap();
        if (fotoCloudUrl != null) {
          pointData['foto_url'] = fotoCloudUrl;
        }

        await client.from('planting_points').upsert(
          pointData,
          onConflict: 'id', // Gunakan upsert untuk handle duplikat
        );

        // 4. Baca kembali nomor_titik yang di-assign Supabase
        try {
          final returned = await client
              .from('planting_points')
              .select('nomor_titik')
              .eq('id', point.id)
              .maybeSingle();
          final nomor = returned?['nomor_titik'] as int?;
          if (nomor != null) {
            await _db.updateNomorTitik(point.id, nomor);
          }
        } catch (_) {
          // Gagal baca nomor_titik tidak fatal — sync tetap berhasil
        }

        // 5. Simpan foto_cloud_url ke SQLite SEBELUM hapus foto lokal
        // (idempoten: jika crash setelah ini, URL sudah aman di lokal)
        if (fotoCloudUrl != null) {
          await _db.saveFotoCloudUrl(point.id, fotoCloudUrl);
        }

        // 6. Update status lokal (foto_cloud_url disimpan, foto_local_path dibersihkan)
        await _db.markPointSynced(point.id, fotoCloudUrl: fotoCloudUrl);

        // 7. Hapus foto lokal setelah URL cloud sudah aman tersimpan di SQLite
        if (point.fotoLocalPath != null) {
          await _deleteLocalPhoto(point.fotoLocalPath!);
        }

        // Record SQLite TIDAK dihapus — metadata titik dipertahankan untuk
        // ditampilkan di ProjectScreen. Hanya foto fisik yang dihapus dari storage.

        successCount++;
        debugPrint('SyncService: Titik ${point.id} berhasil di-sync (foto lokal dihapus, metadata dipertahankan)');
      } catch (e) {
        // Titik gagal → increment attempt, lanjut ke titik berikutnya
        await _db.incrementSyncAttempt(point.id);
        failedCount++;
        errors.add('Titik ${point.id.substring(0, 8)}... gagal: $e');
        debugPrint('SyncService: Gagal sync titik ${point.id}: $e');
      }
    }

    return SyncResult(
      success: successCount,
      failed: failedCount,
      errorMessages: errors,
    );
  }

  /// Hapus file foto lokal setelah berhasil diupload ke Cloudinary.
  /// Menghapus dua file: foto compressed dan foto geotagged (jika ada).
  Future<void> _deleteLocalPhoto(String localPath) async {
    try {
      // Hapus file yang diberikan (biasanya _geotagged.jpg)
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('SyncService: Foto lokal dihapus → $localPath');
      }

      // Juga coba hapus versi compressed (tanpa _geotagged suffix)
      final basePath = localPath.replaceAll('_geotagged.jpg', '.jpg');
      if (basePath != localPath) {
        final baseFile = File(basePath);
        if (await baseFile.exists()) {
          await baseFile.delete();
        }
      }
    } catch (e) {
      // Gagal hapus tidak fatal — data sudah aman di cloud
      debugPrint('SyncService: Gagal hapus foto lokal: $e');
    }
  }

  /// Upload foto ke Cloudinary, kembalikan URL foto
  Future<String?> _uploadToCloudinary({
    required String imagePath,
    required String projectId,
    required Map<String, String> config,
  }) async {
    final cloudName = config['cloudinary_cloud_name'];
    final uploadPreset = config['cloudinary_upload_preset'];

    if (cloudName == null || cloudName.isEmpty ||
        uploadPreset == null || uploadPreset.isEmpty) {
      debugPrint('SyncService: Konfigurasi Cloudinary tidak lengkap');
      return null;
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      debugPrint('SyncService: File foto tidak ditemukan: $imagePath');
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'kawal_pe/$projectId';
      request.files.add(
        await http.MultipartFile.fromPath('file', imagePath),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = json['secure_url'] as String?;
        debugPrint('SyncService: Foto berhasil diupload: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('SyncService: Cloudinary error ${response.statusCode}: $responseBody');
        return null;
      }
    } catch (e) {
      debugPrint('SyncService: Gagal upload foto ke Cloudinary: $e');
      return null;
    }
  }

  // =========================================================
  // PULL: Ambil dari Server
  // =========================================================

  /// Ambil semua proyek dari Supabase untuk ditampilkan di BottomSheet
  Future<List<Project>> fetchProjectsFromServer() async {
    final client = _getSupabaseClient();
    if (client == null) return [];

    try {
      final response = await client
          .from('projects')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((map) => Project.fromSupabase(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SyncService: Gagal fetch proyek dari server: $e');
      return [];
    }
  }

  /// Simpan satu proyek dari server ke database lokal
  Future<bool> downloadProject(String projectId) async {
    final client = _getSupabaseClient();
    if (client == null) return false;

    try {
      final response = await client
          .from('projects')
          .select()
          .eq('id', projectId)
          .single();

      final project = Project.fromSupabase(response as Map<String, dynamic>);
      await _db.insertProject(project);

      debugPrint('SyncService: Proyek $projectId berhasil diunduh');
      return true;
    } catch (e) {
      debugPrint('SyncService: Gagal download proyek $projectId: $e');
      return false;
    }
  }

  // =========================================================
  // SYNC SPESIES — Dua Arah (Push + Pull)
  // =========================================================

  /// Push spesies lokal yang belum ada di Supabase
  Future<int> pushSpesies() async {
    final client = _getSupabaseClient();
    if (client == null) return 0;

    try {
      // Ambil semua spesies dari Supabase
      final serverList = await client.from('species_list').select('nama');
      final serverNamas = (serverList as List)
          .map((r) => (r as Map<String, dynamic>)['nama'] as String)
          .toSet();

      // Ambil spesies lokal kustom (bukan default)
      final localList = await _db.getAllSpesies();

      // Push yang ada di lokal tapi belum di server
      int pushed = 0;
      for (final nama in localList) {
        if (!serverNamas.contains(nama)) {
          try {
            await client.from('species_list').insert({'nama': nama});
            pushed++;
          } catch (e) {
            debugPrint('SyncService: Gagal push spesies "$nama": $e');
          }
        }
      }
      debugPrint('SyncService: $pushed spesies di-push ke server');
      return pushed;
    } catch (e) {
      debugPrint('SyncService: Gagal push spesies: $e');
      return 0;
    }
  }

  /// Pull spesies dari Supabase → merge ke SQLite lokal
  Future<int> pullSpesies() async {
    final client = _getSupabaseClient();
    if (client == null) return 0;

    try {
      // Ambil semua spesies dari Supabase
      final serverList = await client
          .from('species_list')
          .select('nama')
          .order('nama', ascending: true);

      final serverNamas = (serverList as List)
          .map((r) => (r as Map<String, dynamic>)['nama'] as String)
          .toList();

      // Ambil yang sudah ada di lokal
      final localNamas = await _db.getAllSpesies();
      final localSet = localNamas.toSet();

      // Insert yang ada di server tapi belum di lokal
      int pulled = 0;
      for (final nama in serverNamas) {
        if (!localSet.contains(nama)) {
          final ok = await _db.insertSpesies(nama);
          if (ok) pulled++;
        }
      }
      debugPrint('SyncService: $pulled spesies baru dari server');
      return pulled;
    } catch (e) {
      debugPrint('SyncService: Gagal pull spesies: $e');
      return 0;
    }
  }

  // =========================================================
  // SINKRONISASI AKUN PENGGUNA
  // =========================================================

  /// Download semua akun pengguna dari Supabase ke SQLite lokal.
  /// Dijalankan: pertama kali install, atau manual via Settings.
  /// Kembalikan jumlah akun yang berhasil diunduh.
  Future<int> pullUsers() async {
    final client = _getSupabaseClient();
    if (client == null) {
      debugPrint('SyncService pullUsers: Supabase belum dikonfigurasi');
      return 0;
    }

    try {
      final response = await client
          .from('app_users')
          .select('id, nama, username, password_hash, role, created_at, salt')
          .order('created_at');

      int count = 0;
      for (final row in response as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        // Skip jika password_hash kosong (akun belum lengkap di Supabase)
        if ((map['password_hash'] as String? ?? '').isEmpty) continue;

        final user = AppUser(
          id: map['id'] as String,
          nama: map['nama'] as String,
          username: (map['username'] as String).toLowerCase(),
          passwordHash: map['password_hash'] as String,
          role: map['role'] as String? ?? 'user',
          createdAt: map['created_at'] as String,
          salt: map['salt'] as String?,
        );
        await _db.upsertUser(user);
        count++;
      }
      debugPrint('SyncService pullUsers: $count akun diunduh dari Supabase');
      return count;
    } catch (e) {
      debugPrint('SyncService pullUsers ERROR: $e');
      return 0;
    }
  }

  /// Upload akun yang ditambahkan admin di app ke Supabase.
  /// Hanya upload akun yang belum ada di Supabase (cek by username).
  Future<int> pushUsers() async {
    final client = _getSupabaseClient();
    if (client == null) return 0;

    try {
      final localUsers = await _db.getAllUsers();
      int count = 0;
      for (final user in localUsers) {
        await client.from('app_users').upsert({
          'id': user.id,
          'nama': user.nama,
          'username': user.username,
          'password_hash': user.passwordHash,
          'role': user.role,
          'created_at': user.createdAt,
          'salt': user.salt,
        }, onConflict: 'username', ignoreDuplicates: false);
        count++;
      }
      debugPrint('SyncService pushUsers: $count akun dikirim ke Supabase');
      return count;
    } catch (e) {
      debugPrint('SyncService pushUsers ERROR: $e');
      return 0;
    }
  }

  /// Sync akun dua arah: push lokal → server, lalu pull server → lokal
  Future<int> syncUsers() async {
    if (!await isOnline()) return 0;
    await pushUsers();
    return await pullUsers();
  }

  /// Sync spesies dua arah: push lokal → server, lalu pull server → lokal
  /// Mengembalikan jumlah total spesies baru yang disync
  Future<SyncSpeciesResult> syncSpesies() async {
    if (!await isOnline()) {
      return SyncSpeciesResult(pushed: 0, pulled: 0, error: 'Tidak ada koneksi internet');
    }
    final client = _getSupabaseClient();
    if (client == null) {
      return SyncSpeciesResult(pushed: 0, pulled: 0, error: 'Supabase belum dikonfigurasi');
    }

    final pushed = await pushSpesies();
    final pulled = await pullSpesies();
    return SyncSpeciesResult(pushed: pushed, pulled: pulled);
  }

  /// Reinisialisasi Supabase dengan konfigurasi baru dari Settings
  Future<bool> reinitializeSupabase({
    required String url,
    required String anonKey,
  }) async {
    try {
      // Reset instance lama jika ada
      try {
        await Supabase.instance.dispose();
      } catch (_) {}

      await Supabase.initialize(url: url, anonKey: anonKey);
      return true;
    } catch (e) {
      debugPrint('SyncService: Gagal reinisialisasi Supabase: $e');
      return false;
    }
  }

  // =========================================================
  // HAPUS PROYEK & TITIK DARI SUPABASE
  // =========================================================

  /// Hapus proyek dan semua titiknya dari Supabase (cascade delete).
  /// PENTING: Ini menghapus data permanen dari server!
  /// 
  /// Returns: true jika berhasil, false jika gagal
  Future<bool> deleteProjectFromServer(String projectId) async {
    final client = _getSupabaseClient();
    if (client == null) {
      debugPrint('SyncService deleteProjectFromServer: Supabase belum dikonfigurasi');
      return false;
    }

    try {
      // 1. Ambil semua titik tanam untuk mendapatkan foto URLs
      final pointsResponse = await client
          .from('planting_points')
          .select('id, foto_url')
          .eq('project_id', projectId);

      final pointIds = <String>[];
      final fotoUrls = <String>[];
      
      for (final row in pointsResponse as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        pointIds.add(map['id'] as String);
        final fotoUrl = map['foto_url'] as String?;
        if (fotoUrl != null && fotoUrl.isNotEmpty) {
          fotoUrls.add(fotoUrl);
        }
      }

      debugPrint('SyncService: Akan menghapus ${pointIds.length} titik dan ${fotoUrls.length} foto');

      // 2. Hapus foto dari Cloudinary (optional - foto akan tetap ada jika gagal)
      // Note: Cloudinary tidak punya public API untuk hapus foto tanpa API key & secret
      // Foto di Cloudinary bisa dihapus manual dari dashboard atau pakai backend server
      for (final url in fotoUrls) {
        debugPrint('SyncService: Foto di Cloudinary tidak dihapus otomatis: $url');
        // TODO: Implement foto deletion via backend server if needed
      }

      // 3. Hapus titik tanam dari Supabase
      if (pointIds.isNotEmpty) {
        await client
            .from('planting_points')
            .delete()
            .eq('project_id', projectId);
        debugPrint('SyncService: ${pointIds.length} titik dihapus dari Supabase');
      }

      // 4. Hapus proyek dari Supabase
      await client
          .from('projects')
          .delete()
          .eq('id', projectId);
      
      debugPrint('SyncService: Proyek $projectId berhasil dihapus dari Supabase');
      return true;
    } catch (e) {
      debugPrint('SyncService deleteProjectFromServer ERROR: $e');
      return false;
    }
  }

  /// Ambil semua proyek dari Supabase dengan statistik titik
  /// (untuk menu Kelola Proyek Server)
  Future<List<ProjectWithStats>> fetchProjectsWithStats() async {
    final client = _getSupabaseClient();
    if (client == null) return [];

    try {
      // Ambil semua proyek
      final projectsResponse = await client
          .from('projects')
          .select()
          .order('created_at', ascending: false);

      final projects = <ProjectWithStats>[];
      
      for (final row in projectsResponse as List<dynamic>) {
        final projectMap = row as Map<String, dynamic>;
        final projectId = projectMap['id'] as String;
        
        // Hitung jumlah titik per proyek (ambil semua lalu hitung)
        final pointsResponse = await client
            .from('planting_points')
            .select('id')
            .eq('project_id', projectId);
        
        final count = (pointsResponse as List).length;
        
        projects.add(ProjectWithStats(
          project: Project.fromSupabase(projectMap),
          pointCount: count,
        ));
      }
      
      return projects;
    } catch (e) {
      debugPrint('SyncService fetchProjectsWithStats ERROR: $e');
      return [];
    }
  }
}

/// Proyek dengan statistik titik (untuk UI Kelola Proyek Server)
class ProjectWithStats {
  final Project project;
  final int pointCount;

  const ProjectWithStats({
    required this.project,
    required this.pointCount,
  });
}

/// Hasil sync spesies
class SyncSpeciesResult {
  final int pushed;
  final int pulled;
  final String? error;

  const SyncSpeciesResult({
    required this.pushed,
    required this.pulled,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasChanges => pushed > 0 || pulled > 0;

  String get ringkasan {
    if (hasError) return 'Gagal: $error';
    if (!hasChanges) return 'Semua spesies sudah sinkron';
    final parts = <String>[];
    if (pushed > 0) parts.add('$pushed dikirim');
    if (pulled > 0) parts.add('$pulled diterima');
    return parts.join(', ');
  }
}
