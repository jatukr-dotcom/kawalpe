// =========================================================
// screens/edit_point_screen.dart - Edit data titik tanam
// =========================================================
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/planting_point.dart';
import '../services/species_service.dart';

class EditPointScreen extends StatefulWidget {
  final PlantingPoint point;

  const EditPointScreen({super.key, required this.point});

  @override
  State<EditPointScreen> createState() => _EditPointScreenState();
}

class _EditPointScreenState extends State<EditPointScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catatanCtrl = TextEditingController();
  final _db = DatabaseHelper();
  final _speciesService = SpeciesService();

  late String _spesies;
  late String _kondisi;
  List<String> _daftarSpesies = [];
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _spesies = widget.point.spesies;
    _kondisi = widget.point.kondisi;
    _catatanCtrl.text = widget.point.catatan ?? '';
    _loadSpesies();
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
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
        fotoLocalPath: widget.point.fotoLocalPath,
        fotoCloudUrl: widget.point.fotoCloudUrl,
        deviceId: widget.point.deviceId,
        timestamp: widget.point.timestamp,
        synced: false, // reset agar sync ulang
        syncAttempt: widget.point.syncAttempt,
      );

      await _db.updatePoint(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data titik berhasil diperbarui'),
            backgroundColor: Color(0xFF2E7D32),
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
