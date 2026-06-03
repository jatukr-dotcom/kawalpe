// =========================================================
// screens/login_screen.dart - Halaman login offline
// =========================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../database/database_helper.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  bool _isFirstRun = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _namaCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFirstRun() async {
    final hasUser = await _auth.hasAnyUser();
    if (mounted) {
      setState(() {
        _isFirstRun = !hasUser;
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final user = await _auth.login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (user != null) {
      // Login berhasil → ke HomeScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username atau password salah.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setupAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final user = await _auth.createUser(
      nama: _namaCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: 'admin',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (user != null) {
      // Langsung login dengan akun admin baru
      await _auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat akun. Coba lagi.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kunci layar portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Logo aplikasi
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.forest,
                          size: 72,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kawal PE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      'Monitor Pemulihan Ekosistem',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Card form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isFirstRun
                                  ? '🌱 Setup Awal — Buat Akun Admin'
                                  : 'Masuk ke Akun Anda',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            if (_isFirstRun) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Belum ada akun. Buat akun admin pertama untuk mulai.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // Nama Lengkap (hanya untuk setup admin)
                            if (_isFirstRun) ...[
                              TextFormField(
                                controller: _namaCtrl,
                                decoration: _inputDecoration(
                                  'Nama Lengkap',
                                  Icons.person_outline,
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Nama tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Username
                            TextFormField(
                              controller: _usernameCtrl,
                              decoration: _inputDecoration(
                                'Username',
                                Icons.badge_outlined,
                                hint: 'Contoh: budi.santoso',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Username tidak boleh kosong';
                                }
                                if (v.trim().contains(' ')) {
                                  return 'Username tidak boleh mengandung spasi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: !_showPassword,
                              decoration: _inputDecoration(
                                'Password',
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password tidak boleh kosong';
                                }
                                if (_isFirstRun && v.length < 6) {
                                  return 'Password minimal 6 karakter';
                                }
                                return null;
                              },
                            ),

                            // Konfirmasi password (hanya untuk setup admin)
                            if (_isFirstRun) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordConfirmCtrl,
                                obscureText: true,
                                decoration: _inputDecoration(
                                  'Konfirmasi Password',
                                  Icons.lock_outline,
                                ),
                                validator: (v) {
                                  if (v != _passwordCtrl.text) {
                                    return 'Password tidak cocok';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Tombol submit
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : (_isFirstRun ? _setupAdmin : _login),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        _isFirstRun
                                            ? 'Buat Akun Admin & Mulai'
                                            : 'Masuk',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tombol lupa username/password
                    if (!_isFirstRun)
                      TextButton.icon(
                        onPressed: _showLupaAkunDialog,
                        icon: const Icon(Icons.help_outline, size: 16,
                            color: Colors.white60),
                        label: const Text(
                          'Lupa Username / Password?',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),

                    const SizedBox(height: 8),
                    const Text(
                      'BKSDA — Sistem Tanam Pemulihan Ekosistem',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Dialog lihat semua akun + reset password
  Future<void> _showLupaAkunDialog() async {
    final db = DatabaseHelper();
    final users = await db.getAllUsers();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.manage_accounts, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text('Akun Terdaftar', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: users.isEmpty
                ? const Text('Tidak ada akun terdaftar.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Daftar akun di perangkat ini.
'Reset password' hanya tersedia untuk akun petugas.
Untuk reset password admin, hubungi pengelola sistem.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...users.map((u) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: u.role == 'admin'
                                    ? const Color(0xFF2E7D32)
                                    : Colors.blue,
                                child: Text(
                                  u.nama.isNotEmpty
                                      ? u.nama[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(u.nama,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              subtitle: Text(
                                '@${u.username} • ${u.role == 'admin' ? '🔒 Admin' : 'Petugas'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              // Admin: tidak boleh direset dari sini
                              trailing: u.role == 'admin'
                                  ? const Tooltip(
                                      message:
                                          'Reset admin hanya via pengelola sistem',
                                      child: Icon(Icons.lock,
                                          color: Colors.grey, size: 20),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.lock_reset,
                                          color: Colors.orange),
                                      tooltip: 'Reset Password Petugas',
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showResetPasswordDialog(
                                            u.username, u.nama);
                                      },
                                    ),
                            ),
                          )),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog reset password untuk satu akun
  Future<void> _showResetPasswordDialog(
      String username, String nama) async {
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool show = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Reset Password: $nama'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('@$username',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: newPassCtrl,
                obscureText: !show,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => show = !show),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: !show,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () async {
                if (newPassCtrl.text.trim().length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password minimal 4 karakter'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                if (newPassCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password tidak cocok'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                final ok = await _auth.changePassword(
                  usernameTarget: username,
                  passwordBaru: newPassCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? '✅ Password @$username berhasil direset!'
                        : '❌ Gagal reset password'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ));
                }
              },
              child: const Text('Simpan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    newPassCtrl.dispose();
    confirmCtrl.dispose();
  }


  InputDecoration _inputDecoration(String label, IconData icon,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
