// =========================================================
// screens/detail_screen.dart - Detail titik tanam + Edit/Hapus
// =========================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/planting_point.dart';
import '../models/project.dart';
import '../services/auth_service.dart';
import 'edit_point_screen.dart';

class DetailScreen extends StatefulWidget {
  final PlantingPoint point;
  final Project project;

  const DetailScreen({
    super.key,
    required this.point,
    required this.project,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late PlantingPoint _point;
  final _db = DatabaseHelper();
  final _auth = AuthService();
  String? _namaPerekam; // Nama lengkap petugas pengisi

  @override
  void initState() {
    super.initState();
    _point = widget.point;
    _loadNamaPerekam();
  }

  /// Ambil nama lengkap petugas dari tabel app_users berdasarkan recorded_by
  Future<void> _loadNamaPerekam() async {
    final username = _point.recordedBy;
    if (username == null || username.isEmpty) return;
    final user = await _db.getUserByUsername(username);
    if (user != null && mounted) {
      setState(() => _namaPerekam = user.nama);
    }
  }

  /// Apakah user saat ini boleh edit/hapus titik ini?
  /// Admin bisa semua. User hanya bisa milik sendiri (cek username).
  bool get _canModify {
    if (_auth.isAdmin) return true;
    final currentUsername = _auth.currentUser?.username;
    if (currentUsername == null) return false;
    // Cek recorded_by (username), fallback ke device (data lama)
    if (_point.recordedBy != null && _point.recordedBy!.isNotEmpty) {
      return _point.recordedBy == currentUsername;
    }
    // Data lama belum punya recorded_by → tidak bisa diedit user biasa
    return false;
  }

  Future<void> _editPoint() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPointScreen(point: _point),
      ),
    );
    if (changed == true && mounted) {
      // Reload data dari DB
      final db = DatabaseHelper();
      final points = await db.getPointsByProject(_point.projectId);
      final updated = points.where((p) => p.id == _point.id).firstOrNull;
      if (updated != null && mounted) {
        setState(() => _point = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data diperbarui'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _hapusPoint() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Titik Tanam?'),
        content: Text(
          'Hapus titik di koordinat ${_point.koordinatSingkat}?\n\n'
          'Data yang sudah tersinkronisasi ke server tidak akan ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _db.deletePoint(_point.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Titik berhasil dihapus'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Titik Tanam'),
        actions: [
          // Tombol buka di Google Maps
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Buka di Google Maps',
            onPressed: () => _bukaGoogleMaps(context),
          ),
          // Edit & Hapus (hanya jika punya izin)
          if (_canModify)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _editPoint();
                if (val == 'hapus') _hapusPoint();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Data'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'hapus',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Hapus Titik',
                        style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto full width
            _buildFoto(),

            // Info detail
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status sync
                  _buildSyncStatus(),
                  const SizedBox(height: 16),

                  // Info Proyek
                  _buildSectionTitle('Proyek'),
                  _buildInfoCard([
                    _buildInfoRow(
                        Icons.folder, 'Nama', widget.project.namaProyek),
                    _buildInfoRow(
                        Icons.location_on, 'Lokasi', widget.project.lokasi),
                    if (widget.project.penanggungjawab != null)
                      _buildInfoRow(Icons.groups, 'Penanggung Jawab',
                          widget.project.penanggungjawab!),
                  ]),
                  const SizedBox(height: 16),

                  // Koordinat
                  _buildSectionTitle('Koordinat GPS'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.my_location, 'Latitude',
                        '${_point.latitude.toStringAsFixed(6)}°'),
                    _buildInfoRow(Icons.my_location, 'Longitude',
                        '${_point.longitude.toStringAsFixed(6)}°'),
                    if (_point.accuracy != null)
                      _buildInfoRow(Icons.gps_fixed, 'Akurasi',
                          '${_point.accuracy!.toStringAsFixed(1)} meter'),
                  ]),
                  const SizedBox(height: 16),

                  // Data Tanaman
                  _buildSectionTitle('Data Tanaman'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.park, 'Spesies', _point.spesies),
                    _buildKondisiRow(_point.kondisi),
                    if (_point.catatan != null && _point.catatan!.isNotEmpty)
                      _buildInfoRow(
                          Icons.notes, 'Catatan', _point.catatan!),
                  ]),
                  const SizedBox(height: 16),

                  // Metadata rekaman
                  _buildSectionTitle('Informasi Rekaman'),
                  _buildInfoCard([
                    // Nomor urut global
                    _buildInfoRow(
                      Icons.tag,
                      'No. Pohon',
                      _point.nomorTitik != null
                          ? '#${_point.nomorTitik}'
                          : '— (belum sync)',
                    ),
                    _buildInfoRow(Icons.access_time, 'Waktu',
                        _formatTimestamp(_point.timestamp)),
                    // Nama petugas pengisi
                    _buildInfoRow(
                      Icons.person_pin,
                      'Petugas',
                      _namaPerekam != null
                          ? '$_namaPerekam (@${_point.recordedBy})'
                          : (_point.recordedBy ?? 'Tidak diketahui'),
                    ),
                    _buildInfoRow(
                      Icons.phone_android,
                      'Device ID',
                      _point.deviceId.length > 16
                          ? '${_point.deviceId.substring(0, 16)}...'
                          : _point.deviceId,
                    ),
                    if (_point.fotoCloudUrl != null)
                      _buildInfoRow(Icons.cloud_done, 'Foto Cloud',
                          'Tersimpan di Cloudinary'),
                  ]),
                  const SizedBox(height: 24),

                  // Tombol Buka di Google Maps
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _bukaGoogleMaps(context),
                      icon: const Icon(Icons.directions),
                      label: const Text('Buka di Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),

                  if (_canModify) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _editPoint,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _hapusPoint,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hapus'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoto() {
    if (_point.fotoLocalPath != null) {
      return SizedBox(
        width: double.infinity,
        child: Image.file(
          File(_point.fotoLocalPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildNoPhoto(),
        ),
      );
    }
    return _buildNoPhoto();
  }

  Widget _buildNoPhoto() {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey.shade200,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Tidak ada foto', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _point.synced ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _point.synced ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _point.synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
            color: _point.synced ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _point.synced
                  ? '✅ Data sudah tersinkronisasi ke server'
                  : '⏳ Menunggu sinkronisasi (${_point.syncAttempt}x dicoba)',
              style: TextStyle(
                color: _point.synced ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildKondisiRow(String kondisi) {
    final Map<String, Color> colors = {
      'Sehat': const Color(0xFF2E7D32),
      'Merana': const Color(0xFFF57F17),
      'Mati': const Color(0xFFB71C1C),
      'Baik': const Color(0xFF2E7D32), // backward compat
      'Sedang': const Color(0xFFF57F17),
      'Buruk': const Color(0xFFB71C1C),
    };
    final color = colors[kondisi] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.healing, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const SizedBox(
            width: 100,
            child: Text('Kondisi',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              kondisi,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bukaGoogleMaps(BuildContext context) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_point.latitude},${_point.longitude}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka Google Maps.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID').format(dt) +
          ' WIB';
    } catch (_) {
      return ts;
    }
  }
}
