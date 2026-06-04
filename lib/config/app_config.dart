// =========================================================
// config/app_config.dart - Konfigurasi server KawalPE
// =========================================================
// CATATAN KEAMANAN:
// - supabaseAnonKey adalah kunci publik (anon/publishable key)
//   yang memang boleh ada di client. Ini BUKAN service_role key.
// - Cloudinary upload preset sudah dibatasi di Cloudinary dashboard.
// - File ini boleh ada di repository karena tidak mengandung secret.
// =========================================================

class AppConfig {
  // Supabase
  static const String supabaseUrl = 'https://eshtjuggnobwbnxitvfw.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_7PNo3F07dIEFDzrgfwjOZg_ZlAgFvph';

  // Cloudinary
  static const String cloudinaryCloudName = 'dro6tadsx';
  static const String cloudinaryUploadPreset = 'kawal_pe_preset';

  // Nama aplikasi
  static const String appName = 'KawalPE';
  static const String appSubtitle = 'Monitor Pemulihan Ekosistem';
  static const String appOrganization = 'BKSDA';
}
