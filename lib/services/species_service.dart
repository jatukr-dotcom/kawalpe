// =========================================================
// services/species_service.dart - Manajemen daftar spesies (SQLite)
// =========================================================
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

/// Service untuk menyimpan dan mengelola daftar spesies secara dinamis.
/// Data disimpan di SQLite sehingga semua user pada satu perangkat
/// berbagi daftar spesies yang sama.
class SpeciesService {
  final _db = DatabaseHelper();

  /// Daftar default spesies mangrove (selalu ada, tidak bisa dihapus)
  static const List<String> _defaultSpesies = [
    'Rhizophora mucronata',
    'Avicennia marina',
    'Sonneratia alba',
    'Bruguiera gymnorrhiza',
    'Nypa fruticans',
  ];

  /// Ambil daftar spesies lengkap (default + tambahan)
  Future<List<String>> getDaftarSpesies() async {
    final custom = await _db.getAllSpesies();
    final all = <String>{..._defaultSpesies, ...custom};
    return all.toList()..sort();
  }

  /// Tambah spesies baru — return false jika sudah ada
  Future<bool> tambahSpesies(String nama) async {
    final namaClean = nama.trim();
    if (namaClean.isEmpty) return false;
    if (_defaultSpesies.contains(namaClean)) return false;
    return await _db.insertSpesies(namaClean);
  }

  /// Hapus spesies (hanya yang bukan default)
  Future<bool> hapusSpesies(String nama) async {
    if (_defaultSpesies.contains(nama)) return false;
    return await _db.deleteSpesies(nama);
  }

  /// Cek apakah spesies adalah default (tidak bisa dihapus)
  bool isDefault(String nama) => _defaultSpesies.contains(nama);
}

// =========================================================
// Kondisi tanaman yang valid
// =========================================================
const List<String> kDaftarKondisi = ['Sehat', 'Merana', 'Mati'];

/// Icon dan warna untuk setiap kondisi tanaman
Map<String, dynamic> kondisiInfo(String kondisi) {
  switch (kondisi) {
    case 'Sehat':
      return {
        'icon': Icons.eco,
        'color': const Color(0xFF2E7D32),
        'label': 'Sehat'
      };
    case 'Merana':
      return {
        'icon': Icons.warning_amber,
        'color': const Color(0xFFF57F17),
        'label': 'Merana'
      };
    case 'Mati':
      return {
        'icon': Icons.cancel,
        'color': const Color(0xFFB71C1C),
        'label': 'Mati'
      };
    default:
      return {
        'icon': Icons.help_outline,
        'color': Colors.grey,
        'label': kondisi
      };
  }
}
