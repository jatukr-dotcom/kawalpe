// =========================================================
// screens/settings_screen.dart - Pengaturan Supabase, Cloudinary, dan Device
// =========================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/sync_service.dart';
import '../services/auth_service.dart';
import 'manage_server_projects_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final SyncService _syncService = SyncService();

  // Controller settings
  final _supabaseUrlController = TextEditingController();
  final _supabaseAnonKeyController = TextEditingController();
  final _cloudinaryCloudNameController = TextEditingController();
  final _cloudinaryUploadPresetController = TextEditingController();
  final _deviceNameController = TextEditingController();

  // Info read-only
  String _deviceId = '';
  String _appVersion = '1.0.0';

  bool _isSaving = false;
  bool _isSyncing = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Generate device ID jika belum ada
    String deviceId = prefs.getString('device_id') ?? '';
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    setState(() {
      _supabaseUrlController.text = prefs.getString('supabase_url') ?? '';
      _supabaseAnonKeyController.text = prefs.getString('supabase_anon_key') ?? '';
      _cloudinaryCloudNameController.text = prefs.getString('cloudinary_cloud_name') ?? '';
      _cloudinaryUploadPresetController.text = prefs.getString('cloudinary_upload_preset') ?? '';
      _deviceNameController.text = prefs.getString('device_name') ?? '';
      _deviceId = deviceId;
    });

    // Ambil versi app
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {}
  }

  Future<void> _sinkronisasiPengguna() async {
    if (!await _syncService.isOnline()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada koneksi internet.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final count = await _syncService.syncUsers();
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? '✅ $count pengguna berhasil disinkronkan.'
                  : 'Semua pengguna sudah sinkron.',
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal sinkronisasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _simpanPengaturan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('supabase_url', _supabaseUrlController.text.trim());
      await prefs.setString('supabase_anon_key', _supabaseAnonKeyController.text.trim());
      await prefs.setString('cloudinary_cloud_name', _cloudinaryCloudNameController.text.trim());
      await prefs.setString('cloudinary_upload_preset', _cloudinaryUploadPresetController.text.trim());
      await prefs.setString('device_name', _deviceNameController.text.trim());

      // Reinisialisasi Supabase dengan URL dan key baru
      if (_supabaseUrlController.text.trim().isNotEmpty &&
          _supabaseAnonKeyController.text.trim().isNotEmpty) {
        await _syncService.reinitializeSupabase(
          url: _supabaseUrlController.text.trim(),
          anonKey: _supabaseAnonKeyController.text.trim(),
        );
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pengaturan berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    _cloudinaryCloudNameController.dispose();
    _cloudinaryUploadPresetController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === Supabase ===
              _buildSectionHeader(
                icon: Icons.cloud,
                title: 'Konfigurasi Supabase',
                subtitle: 'Untuk sinkronisasi data ke cloud',
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _supabaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Supabase URL',
                  hintText: 'https://xxxx.supabase.co',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                validator: (val) {
                  if (val != null && val.isNotEmpty && !val.startsWith('https://')) {
                    return 'URL harus diawali dengan https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _supabaseAnonKeyController,
                decoration: InputDecoration(
                  labelText: 'Supabase Anon Key',
                  hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6Ikp...',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                obscureText: _obscureKey,
              ),
              const SizedBox(height: 20),

              // === Cloudinary ===
              _buildSectionHeader(
                icon: Icons.photo_library,
                title: 'Konfigurasi Cloudinary',
                subtitle: 'Untuk penyimpanan foto di cloud',
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _cloudinaryCloudNameController,
                decoration: const InputDecoration(
                  labelText: 'Cloud Name',
                  hintText: 'Contoh: my-cloud-name',
                  prefixIcon: Icon(Icons.cloud_circle),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _cloudinaryUploadPresetController,
                decoration: const InputDecoration(
                  labelText: 'Upload Preset (Unsigned)',
                  hintText: 'Contoh: kawal_pe_preset',
                  prefixIcon: Icon(Icons.upload_file),
                ),
              ),
              const SizedBox(height: 20),

              // === Device Info ===
              _buildSectionHeader(
                icon: Icons.phone_android,
                title: 'Informasi Perangkat',
                subtitle: 'Identitas HP di lapangan',
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Perangkat',
                  hintText: 'Contoh: HP Tim A',
                  prefixIcon: Icon(Icons.badge),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama perangkat tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Device ID (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device ID (auto-generate)',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _deviceId.isEmpty ? 'Belum tersedia' : _deviceId,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _deviceId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Device ID disalin!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Versi App
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Versi Aplikasi:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _appVersion,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Panduan cepat
              _buildPanduanCard(),
              const SizedBox(height: 24),

              // Tombol simpan
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _simpanPengaturan,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Pengaturan'),
                ),
              ),
              const SizedBox(height: 12),

              // Tombol sinkronisasi pengguna
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _sinkronisasiPengguna,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    _isSyncing ? 'Menyinkronkan...' : 'Sinkronisasi Pengguna',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                  ),
                ),
              ),
              
              // Tombol Kelola Proyek Server - hanya untuk admin
              if (AuthService().isAdmin) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageServerProjectsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.cloud_off),
                    label: const Text('Kelola Proyek Server'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPanduanCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Text(
                  'Panduan Mendapatkan Konfigurasi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Supabase:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Text(
              '1. Buka supabase.com → buat project baru\n'
              '2. Settings > API > Copy Project URL & anon key',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cloudinary:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Text(
              '1. Buka cloudinary.com → buat akun gratis\n'
              '2. Settings > Upload > Add upload preset\n'
              '3. Pilih "Unsigned" → copy Cloud Name & Preset Name',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
