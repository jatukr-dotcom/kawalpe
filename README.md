# Kawal PE - Flutter Project

## Cara membuat project Flutter baru dan menggabungkan kode ini

Karena kode ini dibuat secara manual, Anda perlu membuat Flutter project baru lalu 
menggabungkan file-file dari folder ini.

### Langkah Setup:

```bash
# 1. Buat Flutter project baru di lokasi yang berbeda
flutter create --org com.bksda --project-name kawal_pe kawal_pe_new

# 2. Copy file-file dari folder ini ke project baru:
# - Ganti pubspec.yaml
# - Ganti lib/ (semua file)
# - Ganti android/app/src/main/AndroidManifest.xml
# - Ganti android/app/src/main/kotlin/.../MainActivity.kt
# - Ganti android/app/build.gradle

# 3. Install dependencies
cd kawal_pe_new
flutter pub get

# 4. Jalankan
flutter run

# 5. Build APK
flutter build apk --release
```

### Catatan:
- Ganti `com.bksda.kawal_pe` dengan package name yang sesuai
- Pastikan Flutter SDK versi 3.x terinstall
- Lihat PANDUAN_SETUP.md untuk instruksi lengkap
