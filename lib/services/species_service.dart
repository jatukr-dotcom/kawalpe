// =========================================================
// services/species_service.dart - Manajemen daftar spesies tanaman
// =========================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menyimpan dan mengelola daftar spesies secara dinamis
class SpeciesService {
  static const String _key = 'daftar_spesies';

  /// Daftar default spesies mangrove
  static const List<String> _defaultSpesies = [
    'Rhizophora mucronata',
    'Avicennia marina',
    'Sonneratia alba',
    'Bruguiera gymnorrhiza',
    'Nypa fruticans',
  ];

  /// Ambil daftar spesies (default + tambahan user)
  Future<List<String>> getDaftarSpesies() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return List.from(_defaultSpesies);
    final decoded = List<String>.from(jsonDecode(stored) as List);
    // Gabungkan default yang belum ada + spesies user
    final all = <String>{..._defaultSpesies, ...decoded};
    return all.toList()..sort();
  }

  /// Tambah spesies baru
  Future<bool> tambahSpesies(String nama) async {
    final namaClean = nama.trim();
    if (namaClean.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final list = stored != null
        ? List<String>.from(jsonDecode(stored) as List)
        : <String>[];

    if (list.contains(namaClean) || _defaultSpesies.contains(namaClean)) {
      return false; // sudah ada
    }

    list.add(namaClean);
    await prefs.setString(_key, jsonEncode(list));
    return true;
  }

  /// Hapus spesies (hanya yang ditambahkan user, bukan default)
  Future<bool> hapusSpesies(String nama) async {
    if (_defaultSpesies.contains(nama)) return false; // tidak bisa hapus default

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return false;

    final list = List<String>.from(jsonDecode(stored) as List);
    final removed = list.remove(nama);
    if (removed) {
      await prefs.setString(_key, jsonEncode(list));
    }
    return removed;
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
      return {'icon': Icons.eco, 'color': const Color(0xFF2E7D32), 'label': 'Sehat'};
    case 'Merana':
      return {'icon': Icons.warning_amber, 'color': const Color(0xFFF57F17), 'label': 'Merana'};
    case 'Mati':
      return {'icon': Icons.cancel, 'color': const Color(0xFFB71C1C), 'label': 'Mati'};
    default:
      return {'icon': Icons.help_outline, 'color': Colors.grey, 'label': kondisi};
  }
}
