import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/database_helper.dart';
import '../models/project.dart';
import '../models/planting_point.dart';
import '../services/sync_service.dart';
import '../widgets/connectivity_badge.dart';
import 'add_point_screen.dart';
import 'detail_screen.dart';

class ProjectScreen extends StatefulWidget {
  final Project project;

  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();

  List<PlantingPoint> _points = [];
  Project? _project;
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadData();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = !results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final points = await _db.getPointsByProject(widget.project.id);
      final project = await _db.getProjectById(widget.project.id);
      if (mounted) {
        setState(() {
          _points = points;
          _project = project ?? widget.project;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal memuat data: $e', isError: true);
      }
    }
  }

  Future<void> _syncProject() async {
    if (!_isOnline) {
      _showSnackBar('Tidak ada koneksi internet.', isError: true);
      return;
    }

    if (!await _syncService.isConfigured()) {
      _showSnackBar('Konfigurasi server belum lengkap. Buka Pengaturan.', isError: true);
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final result = await _syncService.pushPoints(projectId: widget.project.id);
      await _loadData();

      if (mounted) {
        setState(() => _isSyncing = false);
        if (result.hasErrors) {
          _showSnackBar(
            '${result.success} berhasil, ${result.failed} gagal',
            isError: true,
          );
        } else if (result.success > 0) {
          _showSnackBar('✅ ${result.success} titik berhasil disync!');
        } else {
          _showSnackBar('Semua titik sudah tersync.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        _showSnackBar('Gagal sync: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project!;
    final synced = project.jumlahTitik - project.jumlahBelumSync;
    final hasPending = project.jumlahBelumSync > 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.namaProyek,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Detail Proyek',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          const ConnectivityBadge(),
          const SizedBox(width: 4),
          // Tombol sync proyek ini saja
          if (hasPending && _isOnline)
            _isSyncing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Badge(
                      label: Text('${project.jumlahBelumSync}'),
                      child: const Icon(Icons.cloud_upload),
                    ),
                    tooltip: 'Sync Proyek Ini',
                    onPressed: _syncProject,
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Sub-header info proyek
                  SliverToBoxAdapter(
                    child: _buildProjectInfo(project),
                  ),

                  // Card statistik proyek
                  SliverToBoxAdapter(
                    child: _buildStatsCard(project, synced),
                  ),

                  // Daftar titik atau empty state
                  if (_points.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyPointsState(),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          '${_points.length} titik terbaru (dari ${project.jumlahTitik} total)',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final point = _points[index];
                          return _buildPointTile(point);
                        },
                        childCount: _points.length,
                      ),
                    ),
                  ],

                  // Padding FAB
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPointScreen(project: project),
            ),
          );
          _loadData(); // Refresh setelah tambah titik
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Rekam Titik Baru'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildProjectInfo(Project project) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1B5E20).withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  project.lokasi,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Mulai: ${project.tanggalMulai}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (project.tanggalSelesai != null) ...[
                const Text(' • ', style: TextStyle(color: Colors.grey)),
                Text(
                  'Selesai: ${project.tanggalSelesai}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ],
          ),
          if (project.deskripsi != null && project.deskripsi!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              project.deskripsi!,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard(Project project, int synced) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('Total', '${project.jumlahTitik}', Icons.eco, Colors.blue),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildStat('Tersync', '$synced', Icons.cloud_done, Colors.green),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildStat(
            'Pending',
            '${project.jumlahBelumSync}',
            Icons.cloud_upload_outlined,
            project.jumlahBelumSync > 0 ? Colors.orange : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPointTile(PlantingPoint point) {
    Color kondisiColor;
    switch (point.kondisi) {
      case 'Baik':
        kondisiColor = Colors.green;
      case 'Sedang':
        kondisiColor = Colors.orange;
      default:
        kondisiColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(point: point, project: _project!),
          ),
        ),
        leading: _buildThumbnail(point),
        title: Text(
          point.koordinatSingkat,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    point.spesies,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kondisiColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    point.kondisi,
                    style: TextStyle(
                        fontSize: 11,
                        color: kondisiColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(point.timestamp),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Icon(
          point.synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
          color: point.synced ? Colors.green : Colors.orange,
          size: 20,
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildThumbnail(PlantingPoint point) {
    if (point.fotoLocalPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(point.fotoLocalPath!),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderThumb(),
        ),
      );
    }
    return _buildPlaceholderThumb();
  }

  Widget _buildPlaceholderThumb() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.eco, color: Colors.grey, size: 24),
    );
  }

  Widget _buildEmptyPointsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_location_alt, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Belum ada titik tanam',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap tombol "Rekam Titik Baru" untuk mulai merekam posisi tanaman.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.day.toString().padLeft(2, '0')} '
          '${_bulanIndonesia(dt.month)} ${dt.year}, '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  String _bulanIndonesia(int month) {
    const bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return bulan[month];
  }
}
