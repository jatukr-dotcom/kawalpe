// =========================================================
// screens/species_screen.dart - Halaman manajemen daftar spesies
// =========================================================
import 'package:flutter/material.dart';
import '../services/species_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class SpeciesScreen extends StatefulWidget {
  const SpeciesScreen({super.key});

  @override
  State<SpeciesScreen> createState() => _SpeciesScreenState();
}

class _SpeciesScreenState extends State<SpeciesScreen> {
  final SpeciesService _service = SpeciesService();
  final SyncService _sync = SyncService();
  final _controller = TextEditingController();
  List<String> _daftar = [];
  bool _loading = true;
  bool _syncing = false;

  bool get _isAdmin => AuthService().isAdmin;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-pull dari server saat buka halaman
    _syncWithServer(silent: true);
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

  /// Sync spesies dengan Supabase (push lokal + pull server)
  Future<void> _syncWithServer({bool silent = false}) async {
    if (_syncing) return;
    if (mounted) setState(() => _syncing = true);

    final result = await _sync.syncSpesies();
    await _load(); // Refresh daftar setelah sync

    if (mounted) {
      setState(() => _syncing = false);
      if (!silent || result.hasChanges || result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(
                result.hasError ? Icons.error_outline : Icons.sync,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(result.ringkasan)),
            ]),
            backgroundColor: result.hasError
                ? Colors.orange
                : const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _tambah() async {
    final nama = _controller.text.trim();
    if (nama.isEmpty) return;

    final success = await _service.tambahSpesies(nama);
    if (!mounted) return;

    if (success) {
      _controller.clear();
      await _load();
      // Push spesies baru ke server di background
      _sync.pushSpesies();
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
        actions: [
          // Tombol sync manual
          _syncing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync dengan server',
                  onPressed: () => _syncWithServer(),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form tambah spesies baru (HANYA ADMIN)
                  if (_isAdmin)
                    Material(
                      color: Colors.white,
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  labelText: 'Nama spesies baru',
                                  hintText: 'Contoh: Ceriops tagal',
                                  prefixIcon: const Icon(Icons.local_florist),
                                  isDense: false,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                onSubmitted: (_) => _tambah(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _tambah,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(52, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.add, size: 24),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Banner info untuk user biasa
                    Container(
                      color: Colors.blue.shade50,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: const Row(children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hanya Admin yang dapat menambah atau menghapus spesies.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ]),
                    ),
                  const Divider(height: 1),

                  // Keterangan jumlah spesies
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_daftar.length} spesies • Spesies default tidak bisa dihapus',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
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
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
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
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.blue)),
                          // Trailing: kunci (default), hapus (admin+kustom), atau kosong
                          trailing: isDefault
                              ? const Icon(Icons.lock_outline,
                                  size: 16, color: Colors.grey)
                              : (_isAdmin
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () => _hapus(spesies),
                                      tooltip: 'Hapus',
                                    )
                                  : null),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
