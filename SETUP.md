## CARA SETUP KAWAL PE - Instruksi Lengkap

### Step 1: Install Flutter SDK (jika belum ada)

1. Download Flutter di: https://docs.flutter.dev/get-started/install/windows
2. Ekstrak ke C:\flutter
3. Tambahkan C:\flutter\bin ke PATH

### Step 2: Buat Flutter Project Baru

Buka Command Prompt/PowerShell di folder ini dan jalankan:

```
flutter create --org com.bksda --project-name kawal_pe .
```

(Perintah ini akan membuat project Flutter dan MENIMPA beberapa file default)

### Step 3: Kembalikan File Kode Kita

Setelah flutter create, beberapa file kita akan ditimpa.
Pastikan file-file berikut TIDAK ditimpa (atau restore dari git):

File yang SUDAH ADA dan harus DIPERTAHANKAN:
- pubspec.yaml (versi kita lebih lengkap)
- lib/main.dart
- lib/models/*.dart
- lib/database/*.dart
- lib/services/*.dart
- lib/screens/*.dart
- lib/widgets/*.dart
- android/app/src/main/AndroidManifest.xml
- android/app/build.gradle

### Step 4: Install Dependencies

```
flutter pub get
```

### Step 5: Jalankan Aplikasi

```
flutter run
```

### Step 6: Build APK

```
flutter build apk --release
```

APK ada di: build\app\outputs\flutter-apk\app-release.apk
