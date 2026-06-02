// =========================================================
// services/auth_service.dart - Autentikasi offline berbasis SQLite
// =========================================================
import 'dart:convert';
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

  /// Hash password dengan username sebagai salt
  static String hashPassword(String username, String password) {
    final input = '$username:$password:kawal_pe_2024';
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
    final hash = hashPassword(username.trim().toLowerCase(), password);
    final db = DatabaseHelper();
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
    final hash = hashPassword(usernameTarget.toLowerCase(), passwordBaru);
    final db = DatabaseHelper();
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

    final user = AppUser(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      nama: nama.trim(),
      username: username.trim().toLowerCase(),
      passwordHash: hashPassword(username.trim().toLowerCase(), password),
      role: role,
      createdAt: DateTime.now().toIso8601String(),
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
