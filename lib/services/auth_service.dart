// =========================================================
// services/auth_service.dart - Autentikasi offline berbasis SQLite
// =========================================================
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/app_user.dart';

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? _currentUser;

  /// User yang sedang login (null jika belum login)
  AppUser? get currentUser => _currentUser;

  /// True jika sudah login
  bool get isLoggedIn => _currentUser != null;

  /// True jika user yang login adalah admin
  bool get isAdmin => _currentUser?.role == 'admin';

  /// Nama user yang sedang login
  String get namaUser => _currentUser?.nama ?? 'Tamu';

  // =========================================================
  // HASHING
  // =========================================================

  /// Generate salt acak 32 karakter hex untuk user baru
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hash password menggunakan salt per-user
  /// [salt]: salt unik milik user (tersimpan di DB dan Supabase)
  /// Fallback ke salt lama jika salt null (kompatibilitas akun lama)
  static String hashPassword(String username, String password, {String? salt}) {
    final String effectiveSalt = salt ?? 'kawal_pe_2024';
    final input = '$username:$password:$effectiveSalt';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // =========================================================
  // SESI
  // =========================================================

  /// Muat sesi dari SharedPreferences saat app dibuka
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('session_user_id');
    if (userId == null) return;

    final db = DatabaseHelper();
    _currentUser = await db.getUserById(userId);
    // Jika user sudah dihapus dari DB, hapus sesi juga
    if (_currentUser == null) {
      await prefs.remove('session_user_id');
    }
  }

  /// Login dengan username dan password
  /// Mengembalikan AppUser jika berhasil, null jika gagal
  Future<AppUser?> login(String username, String password) async {
    final db = DatabaseHelper();
    // Ambil user dulu untuk mendapatkan salt-nya
    final userRecord = await db.getUserByUsername(username.trim().toLowerCase());
    if (userRecord == null) return null;

    // Hash menggunakan salt milik user (atau fallback ke salt lama)
    final hash = hashPassword(
      username.trim().toLowerCase(),
      password,
      salt: userRecord.salt,
    );

    final user = await db.getUserByCredentials(
      username.trim().toLowerCase(),
      hash,
    );

    if (user != null) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_user_id', user.id);
    }

    return user;
  }

  /// Logout — hapus sesi
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
  }

  /// Ganti password user sendiri
  Future<bool> changePassword({
    required String usernameTarget,
    required String passwordBaru,
  }) async {
    final db = DatabaseHelper();
    // Ambil user untuk mendapatkan salt-nya
    final user = await db.getUserByUsername(usernameTarget.toLowerCase());
    if (user == null) return false;

    final hash = hashPassword(
      usernameTarget.toLowerCase(),
      passwordBaru,
      salt: user.salt,
    );
    return await db.updateUserPassword(usernameTarget.toLowerCase(), hash);
  }

  // =========================================================
  // MANAJEMEN USER (Admin only)
  // =========================================================

  /// Cek apakah sudah ada user di database (untuk first-run)
  Future<bool> hasAnyUser() async {
    final db = DatabaseHelper();
    return await db.hasAnyUser();
  }

  /// Buat user baru (admin only)
  Future<AppUser?> createUser({
    required String nama,
    required String username,
    required String password,
    String role = 'user',
  }) async {
    if (!isAdmin && _currentUser != null) return null; // hanya admin

    final db = DatabaseHelper();
    // Cek apakah username sudah ada
    final existing = await db.getUserByUsername(username.trim().toLowerCase());
    if (existing != null) return null; // username sudah dipakai

    // Generate salt unik untuk user baru
    final salt = generateSalt();
    final normalizedUsername = username.trim().toLowerCase();

    final user = AppUser(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      nama: nama.trim(),
      username: normalizedUsername,
      passwordHash: hashPassword(normalizedUsername, password, salt: salt),
      role: role,
      createdAt: DateTime.now().toIso8601String(),
      salt: salt,
    );

    await db.insertUser(user);
    return user;
  }

  /// Hapus user (admin only, tidak bisa hapus diri sendiri)
  Future<bool> deleteUser(String userId) async {
    if (!isAdmin) return false;
    if (userId == _currentUser?.id) return false; // tidak bisa hapus diri sendiri
    final db = DatabaseHelper();
    return await db.deleteUser(userId);
  }

  /// Ambil semua user (admin only)
  Future<List<AppUser>> getAllUsers() async {
    if (!isAdmin) return [];
    final db = DatabaseHelper();
    return await db.getAllUsers();
  }

  /// Reset password user lain (admin only)
  Future<bool> adminResetPassword({
    required String username,
    required String passwordBaru,
  }) async {
    if (!isAdmin) return false;
    return await changePassword(
      usernameTarget: username,
      passwordBaru: passwordBaru,
    );
  }
}
