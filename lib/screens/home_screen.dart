// =========================================================
// screens/home_screen.dart - Halaman utama daftar proyek
// =========================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/project.dart';
import '../services/sync_service.dart';
import '../widgets/connectivity_badge.dart';
import '../widgets/project_card.dart';
import 'add_project_screen.dart';
import 'project_screen.dart';
import 'settings_screen.dart';
import 'species_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();

  List<Project> _projects = [];
  Map<String, int> _globalStats = {'total_proyek': 0, 'total_titik': 0, 'belum_sync': 0};
  bool _isLoading = false;
  bool _isOnline = false;
  String _deviceId = '';
  String _deviceName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkConnectivity();
    _loadDeviceInfo();
    // Dengarkan perubahan koneksi
    Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = !results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id') ?? '';
      _deviceName = prefs.getString('device_name') ?? 'HP Tidak Dikenal';
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
      final projects = await _db.getAllProjects();
      final stats = await _db.getGlobalStats();

      // Cek storage HP (edge case 9)
      await _checkStorageWarning();

      if (mounted) {
        setState(() {
          _projects = projects;
          _globalStats = stats;
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

  /// Cek apakah storage hampir penuh (< 50MB)
  Future<void> _checkStorageWarning() async {
    try {
      final directory = Directory('/storage/emulated/0');
      final stat = await directory.stat();
      // Estimasi: jika total < 500MB, anggap hampir penuh
      // Implementasi lengkap butuh platform channel, ini perkiraan
    } catch (_) {}
  }

  /// Ambil proyek dari server (Supabase)
  Future<void> _fetchProjectsFromServer() async {
    if (!_isOnline) {
      _showSnackBar('Tidak ada koneksi internet.', isError: true);
      return;
    }

    if (!await _syncService.isConfigured()) {
      _showSnackBar('Konfigurasi server belum lengkap. Buka Pengaturan.', isError: true);
      return;
    }

    // Tampilkan loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mengambil daftar proyek...'),
          ],
        ),
      ),
    );

    try {
      // Fetch proyek dari server
      final serverProjects = await _syncService.fetchProjectsFromServer();

      // Bandingkan dengan proyek lokal
      final localIds = _projects.map((p) => p.id).toSet();
      final newProjects = serverProjects
          .where((p) => !localIds.contains(p.id))
          .toList();

      if (!mounted) return;
      Navigator.of(context).pop(); // Tutup loading dialog

      if (newProjects.isEmpty) {
        _showSnackBar('Tidak ada proyek baru di server. Semua proyek sudah ada di HP ini.');
        return;
      }

      // Tampilkan BottomSheet daftar proyek baru
      _showProjectSelectionSheet(newProjects);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Tutup loading dialog
        _showSnackBar('Gagal mengambil proyek dari server: $e', isError: true);
      }
    }
  }

  /// Tampilkan BottomSheet pilihan proyek dari server
  void _showProjectSelectionSheet(List<Project> serverProjects) {
    final selectedIds = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Judul
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.cloud_download, color: Color(0xFF2E7D32)),
                    SizedBox(width: 8),
                    Text(
                      'Proyek Tersedia di Server',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Daftar proyek
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: serverProjects.length,
                  itemBuilder: (ctx, index) {
                    final project = serverProjects[index];
                    final isSelected = selectedIds.contains(project.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            selectedIds.add(project.id);
                          } else {
                            selectedIds.remove(project.id);
                          }
                        });
                      },
                      title: Text(
                        project.namaProyek,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lokasi: ${project.lokasi}'),
                          Text('Dibuat: ${project.createdAt.substring(0, 10)}'),
                        ],
                      ),
                      activeColor: const Color(0xFF2E7D32),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
              // Tombol simpan
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: ElevatedButton.icon(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          Navigator.of(ctx).pop();
                          await _downloadSelectedProjects(
                            serverProjects
                                .where((p) => selectedIds.contains(p.id))
                                .toList(),
                          );
                        },
                  icon: const Icon(Icons.download),
                  label: Text(
                    selectedIds.isEmpty
                        ? 'Pilih proyek terlebih dahulu'
                        : 'Simpan ke HP (${selectedIds.length})',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Download dan simpan proyek yang dipilih
  Future<void> _downloadSelectedProjects(List<Project> projects) async {
    int success = 0;
    for (final project in projects) {
      final ok = await _syncService.downloadProject(project.id);
      if (ok) success++;
    }

    await _loadData(); // Refresh daftar

    if (mounted) {
      _showSnackBar(
        success == projects.length
            ? '✅ $success proyek disimpan. Siap dipakai offline.'
            : '$success dari ${projects.length} proyek berhasil disimpan.',
        isError: success < projects.length,
      );
    }
  }

  /// Sync semua data yang belum tersync
  Future<void> _syncAll() async {
    if (!_isOnline) {
      _showSnackBar('Tidak ada koneksi internet.', isError: true);
      return;
    }

    if (!await _syncService.isConfigured()) {
      _showSnackBar('Konfigurasi server belum lengkap. Buka Pengaturan.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _syncService.pushPoints();
      await _loadData();

      if (mounted) {
        if (result.hasErrors) {
          _showSyncResultDialog(result);
        } else if (result.success > 0) {
          _showSnackBar('✅ ${result.success} titik berhasil disync!');
        } else {
          _showSnackBar('Semua data sudah tersync.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal sync: $e', isError: true);
      }
    }
  }

  /// Tampilkan dialog hasil sync yang sebagian gagal (edge case 8)
  void _showSyncResultDialog(dynamic result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasil Sinkronisasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Berhasil: ${result.success} titik'),
            Text('❌ Gagal: ${result.failed} titik',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            const Text('Titik yang gagal akan dicoba lagi saat sync berikutnya.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncAll(); // Retry
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi dan hapus proyek (edge case 11)
  Future<void> _confirmDeleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Proyek?'),
        content: Text(
          'Proyek "${project.namaProyek}" memiliki ${project.jumlahTitik} titik. '
          'Semua data titik akan ikut terhapus dari HP ini. Yakin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteProject(project.id);
      await _loadData();
      if (mounted) {
        _showSnackBar('Proyek berhasil dihapus.');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _globalStats['belum_sync']! > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kawal PE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Monitor Pemulihan Ekosistem', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          // Connectivity badge
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: ConnectivityBadge(),
          ),
          // Ambil proyek dari server
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Ambil Proyek dari Server',
            onPressed: _isOnline ? _fetchProjectsFromServer : null,
          ),
          // Sync semua pending
          if (hasPending && _isOnline)
            IconButton(
              icon: Badge(
                label: Text('${_globalStats['belum_sync']}'),
                child: const Icon(Icons.cloud_upload),
              ),
              tooltip: 'Sync Semua Data',
              onPressed: _syncAll,
            ),
          // Settings + menu lainnya
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu Lainnya',
            onSelected: (value) async {
              if (value == 'species') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SpeciesScreen()),
                );
              } else if (value == 'settings') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                _loadData();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'species',
                child: Row(
                  children: [
                    Icon(Icons.local_florist, color: Color(0xFF2E7D32)),
                    SizedBox(width: 8),
                    Text('Kelola Jenis Tanaman'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Pengaturan'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Card statistik global
                  SliverToBoxAdapter(
                    child: _buildStatsCard(),
                  ),

                  // Daftar proyek atau tampilan kosong
                  if (_projects.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final project = _projects[index];
                          return ProjectCard(
                            project: project,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProjectScreen(project: project),
                                ),
                              );
                              _loadData(); // Refresh setelah kembali
                            },
                            onDelete: () => _confirmDeleteProject(project),
                          );
                        },
                        childCount: _projects.length,
                      ),
                    ),

                  // Padding bawah untuk FAB
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProjectScreen()),
          );
          _loadData(); // Refresh setelah tambah proyek
        },
        icon: const Icon(Icons.add),
        label: const Text('Buat Proyek Baru'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.folder,
              label: 'Proyek',
              value: '${_globalStats['total_proyek']}',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: _buildStatItem(
              icon: Icons.eco,
              label: 'Total Titik',
              value: '${_globalStats['total_titik']}',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: _buildStatItem(
              icon: Icons.cloud_upload_outlined,
              label: 'Belum Sync',
              value: '${_globalStats['belum_sync']}',
              valueColor: _globalStats['belum_sync']! > 0
                  ? Colors.yellow.shade300
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forest, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Belum ada proyek',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat proyek baru atau ambil proyek dari server untuk mulai merekam titik tanam.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProjectScreen()),
                );
                _loadData();
              },
              icon: const Icon(Icons.add),
              label: const Text('Buat Proyek Baru'),
            ),
            if (_isOnline) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _fetchProjectsFromServer,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Ambil dari Server'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  foregroundColor: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
