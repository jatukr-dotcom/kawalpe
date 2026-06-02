// =========================================================
// screens/species_screen.dart - Halaman manajemen daftar spesies
// =========================================================
import 'package:flutter/material.dart';
import '../services/species_service.dart';

class SpeciesScreen extends StatefulWidget {
  const SpeciesScreen({super.key});

  @override
  State<SpeciesScreen> createState() => _SpeciesScreenState();
}

class _SpeciesScreenState extends State<SpeciesScreen> {
  final SpeciesService _service = SpeciesService();
  final _controller = TextEditingController();
  List<String> _daftar = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _service.getDaftarSpesies();
    if (mounted) setState(() { _daftar = list; _loading = false; });
  }

  Future<void> _tambah() async {
    final nama = _controller.text.trim();
    if (nama.isEmpty) return;

    final success = await _service.tambahSpesies(nama);
    if (!mounted) return;

    if (success) {
      _controller.clear();
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "$nama" ditambahkan'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$nama" sudah ada di daftar'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _hapus(String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Spesies'),
        content: Text('Hapus "$nama" dari daftar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.hapusSpesies(nama);
      if (success && mounted) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$nama" dihapus'), backgroundColor: Colors.grey),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Jenis Tanaman'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Form tambah spesies baru
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            labelText: 'Nama spesies baru',
                            hintText: 'Contoh: Ceriops tagal',
                            prefixIcon: const Icon(Icons.local_florist),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _tambah(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _tambah,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Keterangan
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${_daftar.length} spesies • Spesies default tidak bisa dihapus',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Daftar spesies
                Expanded(
                  child: ListView.separated(
                    itemCount: _daftar.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final spesies = _daftar[index];
                      final isDefault = _service.isDefault(spesies);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDefault
                              ? const Color(0xFF2E7D32).withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          child: Icon(
                            Icons.local_florist,
                            size: 20,
                            color: isDefault
                                ? const Color(0xFF2E7D32)
                                : Colors.blue,
                          ),
                        ),
                        title: Text(
                          spesies,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: isDefault
                            ? const Text('Spesies default',
                                style: TextStyle(fontSize: 11))
                            : const Text('Ditambahkan manual',
                                style: TextStyle(fontSize: 11, color: Colors.blue)),
                        trailing: isDefault
                            ? const Icon(Icons.lock_outline,
                                size: 16, color: Colors.grey)
                            : IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _hapus(spesies),
                                tooltip: 'Hapus',
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
