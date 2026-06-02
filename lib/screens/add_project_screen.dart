// =========================================================
// screens/add_project_screen.dart - Form buat proyek baru
// =========================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/database_helper.dart';
import '../models/project.dart';
import '../services/sync_service.dart';

class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key});

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _lokasiController = TextEditingController();
  final _deskripsiController = TextEditingController();

  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();

  DateTime _tanggalMulai = DateTime.now();
  DateTime? _tanggalSelesai;
  bool _isSaving = false;
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    // Pastikan locale id_ID selalu siap, meski main() belum dipanggil
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _lokasiController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  /// Format tanggal dengan aman — pakai locale id_ID jika sudah siap
  String _formatTanggal(DateTime dt) {
    if (_localeReady) {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
    }
    // Fallback sementara sebelum locale siap
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  Future<void> _pilihTanggal({bool isSelesai = false}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isSelesai ? (_tanggalSelesai ?? _tanggalMulai) : _tanggalMulai,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
      helpText: isSelesai ? 'Pilih Tanggal Selesai' : 'Pilih Tanggal Mulai',
      confirmText: 'Pilih',
      cancelText: 'Batal',
    );

    if (picked != null) {
      setState(() {
        if (isSelesai) {
          _tanggalSelesai = picked;
        } else {
          _tanggalMulai = picked;
          // Reset tanggal selesai jika lebih awal dari mulai
          if (_tanggalSelesai != null && _tanggalSelesai!.isBefore(picked)) {
            _tanggalSelesai = null;
          }
        }
      });
    }
  }

  Future<void> _simpanProyek() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? '';

      // Buat device ID baru jika belum ada
      if (deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }

      // Buat proyek baru dengan UUID unik
      final project = Project(
        id: const Uuid().v4(),
        namaProyek: _namaController.text.trim(),
        lokasi: _lokasiController.text.trim(),
        deskripsi: _deskripsiController.text.trim().isEmpty
            ? null
            : _deskripsiController.text.trim(),
        tanggalMulai: DateFormat('yyyy-MM-dd').format(_tanggalMulai),
        tanggalSelesai: _tanggalSelesai != null
            ? DateFormat('yyyy-MM-dd').format(_tanggalSelesai!)
            : null,
        createdByDevice: deviceId,
        createdAt: DateTime.now().toIso8601String(),
        syncedToServer: false,
      );

      // Simpan ke database lokal
      await _db.insertProject(project);

      // Cek koneksi dan push ke server jika online
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = !connectivity.contains(ConnectivityResult.none);

      String snackMessage;
      if (isOnline && await _syncService.isConfigured()) {
        final pushed = await _syncService.pushProject(project.id);
        snackMessage = pushed
            ? '✅ Proyek berhasil dibuat & tersimpan di server.\n'
                'Minta anggota tim untuk ambil proyek dari server.'
            : '✅ Proyek berhasil dibuat (offline). Sync manual diperlukan.';
      } else {
        snackMessage = '✅ Proyek berhasil dibuat (offline).\n'
            'Sync ke server saat ada koneksi internet.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMessage),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Kembali ke HomeScreen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan proyek: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Proyek Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Setelah dibuat, anggota tim lain bisa mengambil proyek ini dari server.',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nama Proyek
              const Text(
                'Nama Proyek *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Restorasi Mangrove Teluk Adang 2025',
                  prefixIcon: Icon(Icons.folder),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama proyek tidak boleh kosong';
                  }
                  if (val.trim().length < 5) {
                    return 'Nama proyek minimal 5 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Lokasi/Kawasan
              const Text(
                'Lokasi/Kawasan *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lokasiController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: CA Teluk Adang, Kab. Paser',
                  prefixIcon: Icon(Icons.location_on),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lokasi tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tanggal Mulai
              const Text(
                'Tanggal Mulai *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pilihTanggal(),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _formatTanggal(_tanggalMulai),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tanggal Selesai (opsional)
              const Text(
                'Tanggal Selesai (opsional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pilihTanggal(isSelesai: true),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.event_available),
                    suffixIcon: _tanggalSelesai != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _tanggalSelesai = null);
                            },
                          )
                        : null,
                  ),
                  child: Text(
                    _tanggalSelesai != null
                        ? _formatTanggal(_tanggalSelesai!)
                        : 'Belum ditentukan',
                    style: TextStyle(
                      fontSize: 16,
                      color: _tanggalSelesai != null
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Deskripsi
              const Text(
                'Deskripsi (opsional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deskripsiController,
                decoration: const InputDecoration(
                  hintText: 'Keterangan tambahan tentang proyek ini...',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // Tombol simpan
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _simpanProyek,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Proyek'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
