// =========================================================
// screens/detail_screen.dart - Detail titik tanam
// =========================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'package:intl/intl.dart';

import '../models/planting_point.dart';
import '../models/project.dart';

class DetailScreen extends StatelessWidget {
  final PlantingPoint point;
  final Project project;

  const DetailScreen({
    super.key,
    required this.point,
    required this.project,
  });

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
                    _buildInfoRow(Icons.folder, 'Nama', project.namaProyek),
                    _buildInfoRow(Icons.location_on, 'Lokasi', project.lokasi),
                  ]),
                  const SizedBox(height: 16),

                  // Koordinat
                  _buildSectionTitle('Koordinat GPS'),
                  _buildInfoCard([
                    _buildInfoRow(
                        Icons.my_location, 'Latitude',
                        '${point.latitude.toStringAsFixed(6)}°'),
                    _buildInfoRow(
                        Icons.my_location, 'Longitude',
                        '${point.longitude.toStringAsFixed(6)}°'),
                    if (point.accuracy != null)
                      _buildInfoRow(
                          Icons.gps_fixed, 'Akurasi',
                          '${point.accuracy!.toStringAsFixed(1)} meter'),
                  ]),
                  const SizedBox(height: 16),

                  // Data Tanaman
                  _buildSectionTitle('Data Tanaman'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.park, 'Spesies', point.spesies),
                    _buildKondisiRow(point.kondisi),
                    if (point.catatan != null && point.catatan!.isNotEmpty)
                      _buildInfoRow(Icons.notes, 'Catatan', point.catatan!),
                  ]),
                  const SizedBox(height: 16),

                  // Metadata rekaman
                  _buildSectionTitle('Informasi Rekaman'),
                  _buildInfoCard([
                    _buildInfoRow(
                        Icons.access_time, 'Waktu',
                        _formatTimestamp(point.timestamp)),
                    _buildInfoRow(
                        Icons.phone_android, 'Device ID',
                        point.deviceId.substring(0, 16) + '...'),
                    if (point.fotoCloudUrl != null)
                      _buildInfoRow(
                          Icons.cloud_done, 'Foto Cloud', 'Tersimpan di Cloudinary'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoto() {
    if (point.fotoLocalPath != null) {
      return SizedBox(
        width: double.infinity,
        child: Image.file(
          File(point.fotoLocalPath!),
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
        color: point.synced ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: point.synced ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            point.synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
            color: point.synced ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            point.synced
                ? '✅ Data sudah tersinkronisasi ke server'
                : '⏳ Menunggu sinkronisasi (${point.syncAttempt} percobaan)',
            style: TextStyle(
              color: point.synced ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
              fontSize: 13,
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
        child: Column(
          children: children,
        ),
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
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKondisiRow(String kondisi) {
    Color color;
    switch (kondisi) {
      case 'Baik':
        color = Colors.green;
      case 'Sedang':
        color = Colors.orange;
      default:
        color = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.healing, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const SizedBox(
            width: 80,
            child: Text('Kondisi', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      'https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}',
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
      return DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID').format(dt) + ' WITA';
    } catch (_) {
      return ts;
    }
  }
}
