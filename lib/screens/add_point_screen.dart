import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/project.dart';
import '../models/planting_point.dart'; // class PlantingPoint
import '../services/gps_service.dart';
import '../services/camera_service.dart';
import '../services/species_service.dart'; // kDaftarKondisi, SpeciesService
import '../services/auth_service.dart';
import '../widgets/gps_accuracy_meter.dart';
import 'gps_calibration_screen.dart';

class AddPointScreen extends StatefulWidget {
  final Project project;

  const AddPointScreen({super.key, required this.project});

  @override
  State<AddPointScreen> createState() => _AddPointScreenState();
}

class _AddPointScreenState extends State<AddPointScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _db = DatabaseHelper();
  final GpsService _gpsService = GpsService();
  final CameraService _cameraService = CameraService();

  // State GPS
  Position? _currentPosition;
  double? _currentAccuracy;
  bool _gpsLocked = false;       // Apakah koordinat sudah dikunci
  bool _gpsSignalLost = false;   // Apakah sinyal GPS hilang setelah dikunci
  bool _showCalibrationButton = false; // Tampilkan tombol kalibrasi GPS

  // Timer untuk tampilkan tombol kalibrasi setelah 15 detik
  Timer? _calibrationTimer;
  int _gpsElapsedSeconds = 0;

  // Koordinat terkunci
  double? _lockedLat;
  double? _lockedLng;
  double? _lockedAccuracy;

  // Foto
  String? _fotoPath;

  // Form
  String? _selectedSpesies;
  String _kondisi = 'Sehat'; // default kondisi baru
  final _catatanController = TextEditingController();

  // Daftar spesies dari SQLite (dinamis)
  List<String> _daftarSpesies = [];

  // Info device
  String _deviceId = '';
  String _deviceName = '';

  bool _isSaving = false;

  // Moving average untuk stabilisasi akurasi
  final List<double> _accuracyBuffer = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _loadSpesies(); // Load daftar spesies dari SQLite
    _startGps();
  }

  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _deviceId = prefs.getString('device_id') ?? const Uuid().v4();
        _deviceName = prefs.getString('device_name') ?? 'HP Tidak Dikenal';
      });
    }
  }

  Future<void> _loadSpesies() async {
    final list = await SpeciesService().getDaftarSpesies();
    if (mounted) setState(() => _daftarSpesies = list);
  }

  Future<void> _startGps() async {
    // Cek permission GPS
    final permission = await _gpsService.getPermissionStatus();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showPermissionDialog();
      return;
    }

    // Cek apakah GPS aktif
    if (!await _gpsService.isGpsEnabled()) {
      _showGpsDisabledDialog();
      return;
    }

    await _gpsService.startStream();

    // Timer untuk tampilkan tombol kalibrasi setelah 15 detik
    _calibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _gpsElapsedSeconds++;
        // Tampilkan tombol kalibrasi jika setelah 15 detik akurasi masih > 5m
        if (_gpsElapsedSeconds >= 15 &&
            _currentAccuracy != null &&
            _currentAccuracy! > kGpsAkurasiMinimum &&
            !_gpsLocked) {
          _showCalibrationButton = true;
        }
        // Setelah 60 detik, tampilkan saran aktifkan "Akurasi Tinggi"
        if (_gpsElapsedSeconds == 60 &&
            _currentAccuracy != null &&
            _currentAccuracy! > kGpsAkurasiMinimum) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "⚠️ GPS belum akurat. Coba aktifkan mode lokasi 'Akurasi Tinggi' di Pengaturan HP."),
              duration: Duration(seconds: 6),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    });

    // Listen ke stream posisi
    _gpsService.positionStream.listen((position) {
      if (!mounted) return;

      // position == null berarti GPS error / sinyal hilang
      if (position == null) {
        if (_gpsLocked) {
          setState(() => _gpsSignalLost = true);
        }
        return;
      }

      // Hitung moving average akurasi (3 sample)
      _accuracyBuffer.add(position.accuracy);
      if (_accuracyBuffer.length > 3) _accuracyBuffer.removeAt(0);
      final avgAccuracy = _accuracyBuffer.isNotEmpty
          ? _accuracyBuffer.reduce((a, b) => a + b) / _accuracyBuffer.length
          : position.accuracy;

      setState(() {
        _currentPosition = position;
        _currentAccuracy = avgAccuracy;

        // Sinyal kembali — sembunyikan banner peringatan
        if (_gpsLocked && _gpsSignalLost) {
          _gpsSignalLost = false;
        }
      });
    });
  }

  /// Kunci koordinat GPS saat ini
  void _kunciKoordinat() {
    if (_currentPosition == null || !_gpsService.isAccuracyAcceptable(_currentAccuracy ?? 999)) {
      return;
    }

    setState(() {
      _gpsLocked = true;
      _lockedLat = _currentPosition!.latitude;
      _lockedLng = _currentPosition!.longitude;
      _lockedAccuracy = _currentAccuracy;
      _showCalibrationButton = false;
    });

    // Hentikan stream GPS untuk hemat baterai
    _gpsService.stopStream();
    _calibrationTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔒 Koordinat berhasil dikunci!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Buka layar kalibrasi GPS
  Future<void> _bukaKalibrasi() async {
    _gpsService.stopStream();
    _calibrationTimer?.cancel();

    final result = await Navigator.push<GpsCalibrationResult?>(
      context,
      MaterialPageRoute(builder: (_) => const GpsCalibrationScreen()),
    );

    if (result != null && mounted) {
      // Gunakan koordinat hasil kalibrasi
      setState(() {
        _gpsLocked = true;
        _lockedLat = result.latitude;
        _lockedLng = result.longitude;
        _lockedAccuracy = result.accuracy;
        _currentAccuracy = result.accuracy;
        _showCalibrationButton = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Koordinat dikunci dari kalibrasi!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Kalibrasi dibatalkan → resume stream
      _startGps();
    }
  }

  /// Ambil foto dan tambahkan overlay geotag
  Future<void> _ambilFoto() async {
    // Cek permission kamera
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Izin Kamera Diperlukan'),
            content: const Text(
                'Aplikasi memerlukan akses kamera untuk mengambil foto tanaman.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (_lockedLat == null) {
      _showSnackBar('Kunci koordinat GPS terlebih dahulu!', isError: true);
      return;
    }

    final currentUser = AuthService().currentUser;
    final namaOperator = currentUser != null
        ? '${currentUser.nama} (@${currentUser.username})'
        : _deviceName; // fallback ke nama device jika belum login

    final path = await _cameraService.takePhoto(
      latitude: _lockedLat!,
      longitude: _lockedLng!,
      timestamp: DateTime.now(),
      namaProyek: widget.project.namaProyek,
      namaDevice: namaOperator,
    );

    if (path != null && mounted) {
      setState(() => _fotoPath = path);
    }
  }

  /// Simpan titik tanam ke database lokal
  Future<void> _simpanTitik() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpesies == null || _selectedSpesies!.trim().isEmpty) {
      _showSnackBar('Pilih spesies tanaman terlebih dahulu!', isError: true);
      return;
    }

    if (!_gpsLocked || _lockedLat == null) {
      _showSnackBar('Kunci koordinat GPS terlebih dahulu!', isError: true);
      return;
    }

    if (_fotoPath == null) {
      _showSnackBar('Ambil foto tanaman terlebih dahulu!', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUsername = AuthService().currentUser?.username;
      final point = PlantingPoint(
        id: const Uuid().v4(),
        projectId: widget.project.id,
        latitude: _lockedLat!,
        longitude: _lockedLng!,
        accuracy: _lockedAccuracy,
        spesies: _selectedSpesies!,
        kondisi: _kondisi,
        catatan: _catatanController.text.trim().isEmpty
            ? null
            : _catatanController.text.trim(),
        fotoLocalPath: _fotoPath,
        deviceId: _deviceId,
        recordedBy: currentUsername, // simpan username petugas
        timestamp: DateTime.now().toIso8601String(),
        synced: false,
        syncAttempt: 0,
      );

      await _db.insertPoint(point);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Titik tanam berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Gagal menyimpan titik: $e', isError: true);
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin GPS Diperlukan'),
        content: const Text(
            'Aplikasi memerlukan akses lokasi untuk merekam koordinat titik tanam.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _gpsService.openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GPS Tidak Aktif'),
        content: const Text(
            'GPS tidak tersedia. Aktifkan lokasi di Pengaturan HP untuk merekam koordinat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _gpsService.openLocationSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2E7D32),
      ),
    );
  }

  bool get _canSave =>
      _gpsLocked && _fotoPath != null && _selectedSpesies != null;

  @override
  void dispose() {
    _calibrationTimer?.cancel();
    _gpsService.stopStream();
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekam Titik Tanam'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. Info Proyek
              _buildProyekInfo(),
              const SizedBox(height: 16),

              // 1. GPS Card
              _buildGpsCard(),
              const SizedBox(height: 16),

              // 2. Foto Section
              _buildFotoSection(),
              const SizedBox(height: 16),

              // 3. Form Section
              _buildFormSection(),
              const SizedBox(height: 24),

              // 4. Tombol Simpan
              _buildTombolSimpan(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // === 0. Info Proyek ===
  Widget _buildProyekInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open, color: Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.project.namaProyek,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  widget.project.lokasi,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === 1. GPS Card ===
  Widget _buildGpsCard() {
    final canLock = _currentAccuracy != null &&
        _gpsService.isAccuracyAcceptable(_currentAccuracy!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gps_fixed, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'Koordinat GPS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Banner sinyal GPS hilang (edge case 4)
            if (_gpsSignalLost)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '⚠️ Sinyal GPS hilang. Koordinat terakhir dipertahankan.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ),

            // Koordinat saat ini
            if (_gpsLocked) ...[
              Text(
                'Lat: ${_lockedLat!.toStringAsFixed(6)}°',
                style: const TextStyle(
                    fontSize: 15, fontFamily: 'monospace'),
              ),
              Text(
                'Lng: ${_lockedLng!.toStringAsFixed(6)}°',
                style: const TextStyle(
                    fontSize: 15, fontFamily: 'monospace'),
              ),
            ] else if (_currentPosition != null) ...[
              Text(
                'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}°',
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}°',
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade600,
                ),
              ),
            ] else
              const Text(
                'Mencari posisi...',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 12),

            // GPS Accuracy Meter
            GpsAccuracyMeter(
              accuracy: _currentAccuracy,
              isLocked: _gpsLocked,
            ),
            const SizedBox(height: 12),

            // Tombol Kunci Koordinat
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_gpsLocked || !canLock) ? null : _kunciKoordinat,
                icon: Icon(_gpsLocked ? Icons.lock : Icons.lock_open),
                label: Text(
                  _gpsLocked ? '🔒 Koordinat Terkunci' : '🔒 Kunci Koordinat',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gpsLocked
                      ? Colors.green
                      : (canLock ? const Color(0xFF2E7D32) : Colors.grey),
                  disabledBackgroundColor:
                      _gpsLocked ? Colors.green : Colors.grey.shade300,
                  disabledForegroundColor:
                      _gpsLocked ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ),

            // Helper text
            const SizedBox(height: 6),
            Text(
              _gpsLocked
                  ? '✅ Koordinat GPS sudah terkunci'
                  : 'Akurasi harus ≤5m untuk mengunci koordinat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _gpsLocked ? Colors.green : Colors.orange,
              ),
            ),

            // Tombol Kalibrasi GPS (muncul setelah 15 detik)
            if (_showCalibrationButton && !_gpsLocked) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _bukaKalibrasi,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('🔧 Kalibrasi GPS'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    foregroundColor: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // === 2. Foto Section ===
  Widget _buildFotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.photo_camera, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'Foto Tanaman',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_fotoPath == null)
              // Belum ada foto → tombol ambil foto besar
              GestureDetector(
                onTap: _gpsLocked ? _ambilFoto : () {
                  _showSnackBar('Kunci koordinat GPS terlebih dahulu!', isError: true);
                },
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: _gpsLocked
                        ? Colors.grey.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _gpsLocked
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade400,
                      style: BorderStyle.solid,
                      width: _gpsLocked ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: _gpsLocked
                            ? const Color(0xFF2E7D32)
                            : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _gpsLocked
                            ? '📷 Ambil Foto'
                            : 'Kunci GPS dulu sebelum foto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _gpsLocked
                              ? const Color(0xFF2E7D32)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Foto sudah ada → preview dengan overlay
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_fotoPath!),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Tombol ambil ulang
              OutlinedButton.icon(
                onPressed: _ambilFoto,
                icon: const Icon(Icons.refresh),
                label: const Text('Ambil Ulang'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // === 3. Form Section ===
  Widget _buildFormSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.eco, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'Data Tanaman',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dropdown Spesies — dari SQLite (dinamis)
            const Text('Spesies *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _daftarSpesies.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedSpesies,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Pilih spesies tanaman',
                      prefixIcon: Icon(Icons.park),
                    ),
                    items: _daftarSpesies.map((spesies) {
                      return DropdownMenuItem(
                        value: spesies,
                        child: Text(
                          spesies,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedSpesies = val),
                    validator: (val) =>
                        val == null ? 'Pilih spesies tanaman' : null,
                  ),
            const SizedBox(height: 16),

            // Pilihan Kondisi Tanaman
            const Text('Kondisi *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: kDaftarKondisi.map((kondisi) {
                final Map<String, Color> colors = {
                  'Sehat': const Color(0xFF2E7D32),
                  'Merana': const Color(0xFFF57F17),
                  'Mati': const Color(0xFFB71C1C),
                };
                final Map<String, IconData> icons = {
                  'Sehat': Icons.eco,
                  'Merana': Icons.warning_amber,
                  'Mati': Icons.cancel,
                };
                final color = colors[kondisi] ?? Colors.grey;
                final isSelected = _kondisi == kondisi;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _kondisi = kondisi),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            icons[kondisi],
                            size: 20,
                            color: isSelected ? Colors.white : color,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            kondisi,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSelected ? Colors.white : color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Catatan
            const Text('Catatan (opsional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _catatanController,
              decoration: const InputDecoration(
                hintText: 'Keterangan tambahan (tinggi pohon, hambatan, dll.)',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  // === 4. Tombol Simpan ===
  Widget _buildTombolSimpan() {
    return Column(
      children: [
        // Checklist persyaratan
        _buildChecklist(),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: (_canSave && !_isSaving) ? _simpanTitik : null,
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
            label: Text(_isSaving ? 'Menyimpan...' : '💾 Simpan Titik'),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Persyaratan sebelum simpan:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildCheckItem('GPS terkunci (akurasi ≤5m)', _gpsLocked),
          _buildCheckItem('Foto sudah diambil', _fotoPath != null),
          _buildCheckItem('Spesies dipilih', _selectedSpesies != null),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isChecked ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isChecked ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
