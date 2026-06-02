// =========================================================
// screens/user_management_screen.dart - Admin: Kelola pengguna
// =========================================================
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _auth = AuthService();
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _auth.getAllUsers();
    if (mounted) setState(() { _users = users; _loading = false; });
  }

  void _showCreateUserDialog() {
    final namaCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'user';
    bool showPass = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Pengguna Baru'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.badge_outlined),
                      helperText: 'Tanpa spasi, huruf kecil',
                    ),
                    autocorrect: false,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      if (v.contains(' ')) return 'Tanpa spasi';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => showPass = !showPass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib diisi';
                      if (v.length < 6) return 'Minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'user',
                        child: Text('User — Petugas Lapangan'),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Admin — Pengelola'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => role = v ?? 'user'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final user = await _auth.createUser(
                  nama: namaCtrl.text.trim(),
                  username: usernameCtrl.text.trim(),
                  password: passwordCtrl.text,
                  role: role,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (user != null) {
                    _loadUsers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('✅ Pengguna "${user.nama}" ditambahkan'),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Username sudah dipakai.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(AppUser user) {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password — ${user.nama}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password Baru',
              prefixIcon: Icon(Icons.lock_reset),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Wajib diisi';
              if (v.length < 6) return 'Minimal 6 karakter';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final ok = await _auth.adminResetPassword(
                username: user.username,
                passwordBaru: passwordCtrl.text,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '✅ Password ${user.nama} berhasil direset'
                        : 'Gagal reset password'),
                    backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengguna?'),
        content: Text(
          'Hapus akun "${user.nama}" (@${user.username})?\n\n'
          'Data titik tanam yang direkam tidak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _auth.deleteUser(user.id);
      if (ok) {
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Akun "${user.nama}" dihapus'),
              backgroundColor: Colors.grey.shade700,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header info
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        '${_users.length} pengguna terdaftar',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final user = _users[i];
                      final isSelf = user.id == currentUserId;
                      final isAdmin = user.role == 'admin';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAdmin
                              ? const Color(0xFF1B5E20)
                              : Colors.blue.shade100,
                          child: Text(
                            user.nama.isNotEmpty
                                ? user.nama[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isAdmin
                                  ? Colors.white
                                  : Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              user.nama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Anda',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '@${user.username} • ${isAdmin ? "Admin" : "User"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAdmin
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                          ),
                        ),
                        trailing: isSelf
                            ? null // Tidak bisa hapus diri sendiri
                            : PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'reset') {
                                    _showResetPasswordDialog(user);
                                  } else if (val == 'hapus') {
                                    _hapusUser(user);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'reset',
                                    child: Row(children: [
                                      Icon(Icons.lock_reset,
                                          size: 18, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Reset Password'),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'hapus',
                                    child: Row(children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Hapus Pengguna',
                                          style:
                                              TextStyle(color: Colors.red)),
                                    ]),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Pengguna'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
    );
  }
}
