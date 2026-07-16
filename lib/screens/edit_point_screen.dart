// =========================================================
// screens/edit_point_screen.dart - Edit data titik tanam
// =========================================================
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/planting_point.dart';
import '../services/species_service.dart';
import '../services/sync_service.dart';

class EditPointScreen extends StatefulWidget {
  final PlantingPoint point;

  const EditPointScreen({super.key, required this.point});

  @override
  State<EditPointScreen> createState() => _EditPointScreenState();
}

class _EditPointScreenState extends State<EditPointScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catatanCtrl = TextEditingController();
  final _tinggiCtrl = TextEditingController();
  final _kelilingCtrl = TextEditingController();
  final _db = DatabaseHelper();
  final _speciesService = SpeciesService();

  late String _spesies;
  late String _kondisi;
  double? _previewDiameter;
  List<String> _daftarSpesies = [];
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _spesies = widget.point.spesies;
    _kondisi = widget.point.kondisi;
    _catatanCtrl.text = widget.point.catatan ?? '';
    // Pre-fill tinggi jika sudah ada
    if (widget.point.tinggi != null) {
      _tinggiCtrl.text = widget.point.tinggi!.toStringAsFixed(1);
    }
    // Pre-fill keliling dari diameter balik: keliling = diameter * π
    if (widget.point.diameter != null) {
      final keliling = widget.point.diameter! * 3.14159265358979;
      _kelilingCtrl.text = keliling.toStringAsFixed(2);
      _previewDiameter = widget.point.diameter;
    }
    _loadSpesies();
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    _tinggiCtrl.dispose();
    _kelilingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSpesies() async {
    final list = await _speciesService.getDaftarSpesies();
    if (mounted) {
      setState(() {
        _daftarSpesies = list;
        // Pastikan spesies saat ini ada di daftar
        if (!_daftarSpesies.contains(_spesies)) {
          _daftarSpesies.insert(0, _spesies);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Parse tinggi (opsional)
      final double? tinggi = _tinggiCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_tinggiCtrl.text.trim().replaceAll(',', '.'));

      // Konversi keliling → diameter: d = keliling / π
      final double? diameter = _kelilingCtrl.text.trim().isEmpty
          ? null
          : PlantingPoint.kelilingToDiameter(
              double.tryParse(
                      _kelilingCtrl.text.trim().replaceAll(',', '.')) ??
                  0);

      final updated = PlantingPoint(
        id: widget.point.id,
        projectId: widget.point.projectId,
        latitude: widget.point.latitude,
        longitude: widget.point.longitude,
        accuracy: widget.point.accuracy,
        spesies: _spesies,
        kondisi: _kondisi,
        catatan: _catatanCtrl.text.trim().isEmpty
            ? null
            : _catatanCtrl.text.trim(),
        tinggi: tinggi,
        diameter: diameter,
        fotoLocalPath: widget.point.fotoLocalPath,
        fotoCloudUrl: widget.point.fotoCloudUrl,
        deviceId: widget.point.deviceId,
        timestamp: widget.point.timestamp,
        synced: false,
        syncAttempt: widget.point.syncAttempt,
      );

      await _db.updatePoint(updated);

      // Auto-sync ke Supabase jika ada internet
      String syncMsg = '';
      final syncService = SyncService();
      final isOnline = await syncService.isOnline();
      final isConfigured = await syncService.isConfigured();
      if (isOnline && isConfigured) {
        final result = await syncService.pushPoints(
          projectId: updated.projectId,
        );
        syncMsg = result.failed == 0
            ? ' & tersinkron ke server ☁️'
            : ' (sync gagal, coba manual)';
      } else {
        syncMsg = ' (akan sync saat ada internet)';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Data diperbarui$syncMsg'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // true = ada perubahan
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Data Titik'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info koordinat (tidak bisa diubah)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Koordinat: ${widget.point.koordinatLengkap}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const Icon(Icons.lock_outline,
                              size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Spesies
                    const Text(
                      'Jenis Tanaman *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _daftarSpesies.contains(_spesies)
                          ? _spesies
                          : _daftarSpesies.first,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.local_florist),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _daftarSpesies
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _spesies = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Kondisi
                    const Text(
                      'Kondisi Tanaman *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Sehat', 'Merana', 'Mati'].map((k) {
                        final isSelected = _kondisi == k;
                        final colors = {
                          'Sehat': const Color(0xFF2E7D32),
                          'Merana': const Color(0xFFF57F17),
                          'Mati': const Color(0xFFB71C1C),
                        };
                        final icons = {
                          'Sehat': Icons.eco,
                          'Merana': Icons.warning_amber,
                          'Mati': Icons.cancel,
                        };
                        final color = colors[k]!;
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () => setState(() => _kondisi = k),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color
                                      : color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : color.withOpacity(0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      icons[k],
                                      color: isSelected
                                          ? Colors.white
                                          : color,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Tinggi & Diameter
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input Tinggi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tinggi (cm)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _tinggiCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 150',
                                  prefixIcon: const Icon(Icons.height),
                                  suffixText: 'cm',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) {
                                  if (v != null && v.trim().isNotEmpty) {
                                    final n = double.tryParse(
                                        v.trim().replaceAll(',', '.'));
                                    if (n == null || n <= 0) {
                                      return 'Tidak valid';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Input Keliling → Diameter
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Keliling Batang (cm)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _kelilingCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 31.4',
                                  prefixIcon: const Icon(
                                      Icons.radio_button_unchecked),
                                  suffixText: 'cm',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText: _previewDiameter != null
                                      ? '⋅ ${_previewDiameter!.toStringAsFixed(2)} cm'
                                      : 'Keliling → Diameter otomatis',
                                  helperStyle: TextStyle(
                                    color: _previewDiameter != null
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey,
                                    fontWeight: _previewDiameter != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                onChanged: (v) {
                                  final k = double.tryParse(
                                      v.trim().replaceAll(',', '.'));
                                  setState(() {
                                    _previewDiameter =
                                        (k != null && k > 0)
                                            ? PlantingPoint
                                                .kelilingToDiameter(k)
                                            : null;
                                  });
                                },
                                validator: (v) {
                                  if (v != null && v.trim().isNotEmpty) {
                                    final n = double.tryParse(
                                        v.trim().replaceAll(',', '.'));
                                    if (n == null || n <= 0) {
                                      return 'Tidak valid';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Catatan
                    const Text(
                      'Catatan (opsional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _catatanCtrl,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Tambahkan catatan tentang kondisi tanaman...',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.notes),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignLabelWithHint: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 24),

                    // Tombol simpan
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _simpan,
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
                        label: Text(
                          _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
