// =========================================================
// models/app_user.dart - Model pengguna aplikasi
// =========================================================

class AppUser {
  final String id;
  final String nama;
  final String username;
  final String passwordHash;
  final String role; // 'admin' | 'user'
  final String createdAt;
  final String? salt; // Salt unik per-user untuk hashing password

  AppUser({
    required this.id,
    required this.nama,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
    this.salt,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      nama: map['nama'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      role: map['role'] as String,
      createdAt: map['created_at'] as String,
      salt: map['salt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'created_at': createdAt,
      'salt': salt,
    };
  }
}
