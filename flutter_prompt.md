# PROMPT: Flutter Geotagging App - Mangrove Monitoring (BKSDA)

## INSTRUKSI UNTUK AI
Buatkan aplikasi Flutter yang lengkap dan siap digunakan berdasarkan spesifikasi berikut. 
Berikan kode lengkap untuk setiap file, bukan hanya snippet. 
Sertakan instruksi setup dan cara build APK di bagian akhir.

---

## 1. OVERVIEW APLIKASI

Nama aplikasi: **SiTanam** (Sistem Tanam Mangrove)

Aplikasi mobile Android untuk petugas lapangan BKSDA (Balai Konservasi Sumber Daya Alam) 
dalam merekam titik tanam mangrove satu per satu secara geotagging. 

Karakteristik utama:
- **Offline-first**: seluruh pengambilan data bekerja tanpa internet
- **Multi-device**: 2+ HP mengerjakan proyek yang SAMA secara bersamaan di lapangan
- **Shared project**: proyek dibuat di satu HP → HP lain bisa join sebelum berangkat lapangan
- **Sync otomatis**: ketika ada internet, data terupload ke cloud dengan satu tap
- **Target pengguna**: petugas lapangan non-teknis
- **Distribusi**: install manual via APK (bukan Play Store)
- **Skala**: hingga 50.000 titik dalam beberapa tahun

### Alur Multi-Device (PENTING)
```
[DI KANTOR - ada internet]
HP 1: Buat proyek "Penanaman Desa Padang Pengrapat" → otomatis sync ke Supabase
HP 2: Buka app → tap "Ambil Proyek dari Server" → proyek HP 1 muncul → pilih & simpan lokal

[DI LAPANGAN - offline]
HP 1 & HP 2: Input titik tanam masing-masing → tersimpan lokal dengan project_id yang sama

[KEMBALI KE KANTOR - ada internet]
HP 1 & HP 2: Tap "Sync" → semua titik terupload ke Supabase dalam satu proyek yang sama

[WEBGIS]
Semua titik dari HP 1 dan HP 2 tampil dalam satu proyek yang terintegrasi
```

---

## 2. TECH STACK

```yaml
# pubspec.yaml dependencies
dependencies:
  flutter:
    sdk: flutter
  
  # Database lokal
  sqflite: ^2.3.0
  path: ^1.9.0
  
  # GPS
  geolocator: ^11.0.0
  permission_handler: ^11.3.0
  
  # Kamera & foto
  image_picker: ^1.0.7
  flutter_image_compress: ^2.1.0
  image: ^4.1.0               # Manipulasi gambar (overlay geotag)
  
  # Cloud sync
  supabase_flutter: ^2.3.0
  connectivity_plus: ^6.0.0
  http: ^1.2.0
  
  # Utilities
  uuid: ^4.3.3
  path_provider: ^2.1.2
  shared_preferences: ^2.2.2
  intl: ^0.19.0
```

---

## 3. STRUKTUR FOLDER

```
lib/
├── main.dart
├── models/
│   ├── planting_point.dart
│   └── project.dart
├── database/
│   └── database_helper.dart
├── services/
│   ├── gps_service.dart
│   ├── camera_service.dart
│   ├── geotag_service.dart
│   └── sync_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── project_screen.dart
│   ├── add_project_screen.dart
│   ├── add_point_screen.dart
│   ├── gps_calibration_screen.dart  ← BARU
│   ├── detail_screen.dart
│   └── settings_screen.dart
└── widgets/
    ├── connectivity_badge.dart
    ├── sync_status_chip.dart
    ├── gps_accuracy_meter.dart      ← BARU (widget reusable)
    ├── project_card.dart
    └── point_list_tile.dart
```

---

## 4. DATA MODEL

### Model Dart: Project (project.dart)
```dart
class Project {
  final String id;               // UUID v4 - sama di semua HP
  final String namaProyek;
  final String lokasi;
  final String? deskripsi;
  final String tanggalMulai;
  final String? tanggalSelesai;
  final String createdByDevice;  // device_id HP yang membuat proyek
  final String createdAt;
  bool syncedToServer;           // apakah proyek sudah ada di Supabase
  int jumlahTitik;               // dihitung dari DB lokal
  int jumlahBelumSync;           // dihitung dari DB lokal
}
```

### Model Dart: PlantingPoint (planting_point.dart)
```dart
class PlantingPoint {
  final String id;           // UUID v4 - primary key
  final String projectId;    // FK ke Project.id ← BARU
  final double latitude;
  final double longitude;
  final double? accuracy;    // GPS accuracy dalam meter
  final String spesies;
  final String kondisi;      // 'Baik', 'Sedang', 'Buruk'
  final String? catatan;
  final String? fotoLocalPath;
  String? fotoCloudUrl;
  final String deviceId;
  final String timestamp;    // ISO 8601
  bool synced;
  int syncAttempt;
}
```

### SQLite Schema (database_helper.dart)
```sql
-- Tabel proyek (menyimpan proyek lokal DAN proyek yang diambil dari server)
CREATE TABLE projects (
  id                TEXT PRIMARY KEY,
  nama_proyek       TEXT NOT NULL,
  lokasi            TEXT NOT NULL,
  deskripsi         TEXT,
  tanggal_mulai     TEXT NOT NULL,
  tanggal_selesai   TEXT,
  created_by_device TEXT NOT NULL,  -- device_id pembuat
  created_at        TEXT NOT NULL,
  synced_to_server  INTEGER DEFAULT 0  -- 0=belum di server, 1=sudah
);

-- Tabel titik tanam
CREATE TABLE planting_points (
  id              TEXT PRIMARY KEY,
  project_id      TEXT NOT NULL,
  latitude        REAL NOT NULL,
  longitude       REAL NOT NULL,
  accuracy        REAL,
  spesies         TEXT NOT NULL,
  kondisi         TEXT NOT NULL,
  catatan         TEXT,
  foto_local_path TEXT,
  foto_cloud_url  TEXT,
  device_id       TEXT NOT NULL,
  timestamp       TEXT NOT NULL,
  synced          INTEGER DEFAULT 0,
  sync_attempt    INTEGER DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES projects(id)
)
```

### Supabase Table Schema
```sql
-- Tabel proyek
CREATE TABLE projects (
  id                UUID PRIMARY KEY,
  nama_proyek       TEXT NOT NULL,
  lokasi            TEXT NOT NULL,
  deskripsi         TEXT,
  tanggal_mulai     DATE NOT NULL,
  tanggal_selesai   DATE,
  created_by_device TEXT NOT NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Tabel titik tanam
CREATE TABLE planting_points (
  id          UUID PRIMARY KEY,
  project_id  UUID NOT NULL REFERENCES projects(id),
  latitude    DOUBLE PRECISION NOT NULL,
  longitude   DOUBLE PRECISION NOT NULL,
  accuracy    DOUBLE PRECISION,
  spesies     TEXT NOT NULL,
  kondisi     TEXT NOT NULL,
  catatan     TEXT,
  foto_url    TEXT,
  device_id   TEXT NOT NULL,
  timestamp   TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- RLS policies
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE planting_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon all" ON projects FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon all" ON planting_points FOR ALL TO anon USING (true) WITH CHECK (true);
```

---

## 5. SPESIFIKASI SCREENS

### Screen 1: HomeScreen (home_screen.dart) ← DIUPDATE

**Fungsi:** Halaman utama berisi daftar proyek lokal + proyek dari server.

**Layout:**
- AppBar:
  - Title: "SiTanam - Monitor Mangrove"
  - Trailing: ConnectivityBadge (hijau=online, abu=offline)
  - Actions:
    - Ikon `cloud_download` → "Ambil Proyek dari Server" (hanya aktif saat online)
    - Ikon `cloud_upload` → sync semua pending (hanya aktif saat online + ada pending)
    - Ikon `settings` → SettingsScreen
- Body:
  - Card statistik global: "Total Proyek: X | Total Titik: Y | Belum Sync: Z"
  - ListView daftar proyek, setiap ProjectCard berisi:
    - Nama proyek (bold)
    - Lokasi
    - Tanggal mulai
    - Jumlah titik terekam (lokal)
    - Progress bar sync
    - Badge status: "Aktif" (hijau) / "Selesai" (abu) / "Dari Server" (biru)
  - Jika kosong: ilustrasi + panduan singkat cara mulai
- FAB: "➕ Buat Proyek Baru"

**Behavior "Ambil Proyek dari Server":**
```
Tap ikon cloud_download
    ↓
Tampilkan loading dialog "Mengambil daftar proyek..."
    ↓
Fetch semua proyek dari Supabase
    ↓
Bandingkan dengan proyek lokal (berdasarkan id)
    ↓
Tampilkan BottomSheet: daftar proyek yang BELUM ada di HP ini
    ↓
User centang proyek yang ingin diambil (misal: "Penanaman Desa Padang Pengrapat")
    ↓
Tap "Simpan ke HP" → proyek tersimpan di SQLite lokal
    ↓
Proyek muncul di HomeScreen, siap dipakai offline
```

**Catatan penting:**
- Proyek yang sudah ada di lokal tidak muncul di daftar "Ambil dari Server"
- Setelah disimpan lokal, proyek bisa dipakai sepenuhnya offline

---

### Screen 2: AddProjectScreen (add_project_screen.dart) ← BARU

**Layout:**
- AppBar: "Buat Proyek Baru"
- Form fields:
  - Nama Proyek * (TextField, contoh: "Restorasi Mangrove Teluk Adang 2025")
  - Lokasi/Kawasan * (TextField, contoh: "CA Teluk Adang, Kab. Paser")
  - Tanggal Mulai * (DatePicker)
  - Tanggal Selesai (DatePicker, opsional)
  - Deskripsi (TextArea, opsional, max 500 karakter)
- Tombol "Simpan Proyek" (full width, hijau)
- Validasi inline

---

### Screen 3: ProjectScreen (project_screen.dart) ← BARU

**Fungsi:** Daftar titik tanam dalam satu proyek.

**Layout:**
- AppBar: nama proyek + ConnectivityBadge
- Sub-header info proyek: lokasi + tanggal + jumlah titik
- Tombol sync di AppBar (hanya sync titik dalam proyek ini)
- Card statistik proyek: "Total: X | Synced: Y | Pending: Z"
- ListView titik (maks 100 terbaru):
  - Thumbnail foto kecil (50x50)
  - Koordinat singkat
  - Spesies + Kondisi chip
  - Waktu rekam
  - Status sync icon
- FAB: "📍 Rekam Titik Baru"

**Behavior:**
- Tap FAB → AddPointScreen (dengan project_id sudah terisi)
- Tap tile → DetailScreen

---

### Screen 4: AddPointScreen (add_point_screen.dart) ← DIUPDATE

**Layout (scroll dari atas ke bawah):**

0. **Info Proyek** (read-only, di paling atas)
   - Nama proyek aktif
   - Lokasi proyek

1. **GPS Card**
   - Icon GPS + teks koordinat (lat, lng) 6 desimal
   - **Accuracy Meter** — ditampilkan secara visual seperti target/radar:
     ```
     Akurasi GPS
     ┌─────────────────────────┐
     │   🎯  3.2 meter         │  ← hijau, LULUS
     │   ████████░░  BAIK      │
     └─────────────────────────┘

     ┌─────────────────────────┐
     │   ⚠️  12.5 meter        │  ← merah, TIDAK LULUS
     │   ███░░░░░░░  LEMAH     │
     └─────────────────────────┘
     ```
   - Threshold wajib: **≤5 meter untuk bisa lanjut**
   - Tombol **"🔒 Kunci Koordinat"**:
     - **DISABLED & merah** jika accuracy > 5m
     - **AKTIF & hijau** jika accuracy ≤ 5m
     - Teks helper di bawah tombol: "Akurasi harus ≤5m untuk mengunci koordinat"
   - Tombol **"🔧 Kalibrasi GPS"** — muncul jika accuracy > 5m setelah 15 detik
   - **TIDAK ADA pengecualian**: tombol Simpan tetap disabled selama GPS belum dikunci dengan akurasi ≤5m

2. **Foto Section**
   - Jika belum ada foto: tombol besar "📷 Ambil Foto" (full width, tinggi 150dp)
   - Jika sudah ada foto: tampilkan preview foto dengan OVERLAY GEOTAG:
     ```
     ┌─────────────────────────────┐
     │                             │
     │        [FOTO TANAMAN]       │
     │                             │
     ├─────────────────────────────┤
     │ 📍 -2.123456, 117.890123    │
     │ 🕐 15 Jan 2025, 09:32:15   │
     │ 📁 Restorasi Mangrove 2025  │
     │ 📱 HP Tim A                 │
     └─────────────────────────────┘
     ```
   - Overlay geotag di-render LANGSUNG ke file gambar (bukan hanya tampilan)
   - Tombol "Ambil Ulang"

3. **Form Section**
   - Dropdown Spesies: Rhizophora mucronata, Avicennia marina,
     Sonneratia alba, Bruguiera gymnorrhiza, Nypa fruticans, Lainnya
   - RadioButton Kondisi: Baik / Sedang / Buruk
   - TextArea Catatan (opsional, max 200 karakter)

4. **Tombol Simpan**
   - "💾 Simpan Titik"
   - Disabled jika GPS belum kunci / foto belum ada / form belum lengkap

---

### Screen 5: SettingsScreen (settings_screen.dart)

**Form fields:**
- Supabase URL
- Supabase Anon Key
- Cloudinary Cloud Name
- Cloudinary Upload Preset (unsigned)
- Nama Perangkat (contoh: "HP Tim A")

**Info read-only:**
- Device ID (UUID auto-generate)
- Versi App: 1.0.0

---

### Screen 6: DetailScreen (detail_screen.dart)

- Foto full width (sudah include overlay geotag)
- Info lengkap: proyek, koordinat, spesies, kondisi, catatan, waktu, device, status sync
- Tombol "Buka di Google Maps"

---

## 6. SERVICES

### GPS Service (gps_service.dart)
```dart
// Konstanta akurasi
const double GPS_ACCURACY_REQUIRED = 5.0;  // meter, WAJIB ≤ ini untuk kunci

// Stream posisi yang terus update
// Gunakan LocationAccuracy.best (bukan hanya high)
// Stop stream saat screen di-dispose untuk hemat baterai
// Handle permission denied dengan pesan Indonesia
// Handle GPS disabled dengan dialog buka Settings

// isAccuracyAcceptable(double accuracy) → bool
// return accuracy <= GPS_ACCURACY_REQUIRED

// getAccuracyStatus(double accuracy) → GpsAccuracyStatus
// enum GpsAccuracyStatus { excellent, good, poor, unacceptable }
// excellent: ≤2m, good: 2-5m, poor: 5-15m, unacceptable: >15m

// Accuracy label & warna:
// ≤2m   → "Sangat Baik" (hijau tua #1B5E20)
// 2-5m  → "Baik" (hijau #2E7D32) ← LULUS threshold
// 5-15m → "Kurang" (oranye #E65100) ← TIDAK LULUS
// >15m  → "Tidak Memadai" (merah #B71C1C) ← TIDAK LULUS
```

### GPS Calibration Screen/Modal (gps_calibration_screen.dart) ← BARU
```dart
// Layar/modal yang muncul saat user tap "🔧 Kalibrasi GPS"
// atau otomatis muncul jika setelah 30 detik accuracy masih > 5m

// Layout:
// - Judul: "Kalibrasi Akurasi GPS"
// - Animasi target/radar yang berputar (menggunakan AnimationController)
//   - Lingkaran luar merah berubah ke hijau saat accuracy membaik
// - Teks akurasi besar di tengah: "12.5 m" → realtime update
// - Progress bar akurasi: 0m ←───●────── 20m+
//   - Marker di posisi 5m sebagai garis target
// - Status text realtime:
//   - "Sedang mencari sinyal satelit..."
//   - "Mendekat... akurasi 8.2m"
//   - "✅ Akurasi tercapai! 3.1m"
// - Panduan teks di bawah:
//   "Tips mendapatkan akurasi terbaik:
//    • Pastikan berada di area terbuka
//    • Hindari berdiri di bawah pohon lebat
//    • Tunggu beberapa detik hingga GPS terkunci
//    • Aktifkan mode lokasi 'Akurasi Tinggi' di HP"
// - Tombol "✅ Gunakan Koordinat Ini" — HANYA aktif jika accuracy ≤ 5m
// - Tombol "Batal"

// Behavior:
// - Stream GPS terus update accuracy di layar ini
// - Jika accuracy mencapai ≤5m: tombol aktif + animasi radar berubah hijau
// - Saat user tap "Gunakan Koordinat Ini": tutup modal, koordinat terkunci di AddPointScreen
// - Auto-close jika accuracy ≤ 5m selama 3 detik berturut-turut
//   (dengan countdown: "Mengunci otomatis dalam 3...")
```

### Camera Service (camera_service.dart)
```dart
// Ambil foto dari kamera (bukan gallery)
// Kompres dengan FlutterImageCompress:
//   - quality: 70
//   - minWidth: 800, minHeight: 600
//   - format: JPEG
// Simpan ke direktori app (bukan DCIM publik)
// Setelah kompres, panggil GeotagService.addOverlay()
// Return local path string dari foto yang sudah ada overlay
```

### Geotag Service (geotag_service.dart) ← BARU
```dart
// addOverlay() method - render teks geotag langsung ke file gambar
//
// Parameter yang diterima:
//   - imagePath: String (path foto hasil kamera)
//   - latitude: double
//   - longitude: double
//   - timestamp: DateTime
//   - namaProyek: String
//   - namaDevice: String
//
// Implementasi menggunakan package 'image':
// 1. Load gambar dari file
// 2. Hitung tinggi overlay = 20% dari tinggi gambar (min 80px)
// 3. Gambar rectangle semi-transparan hitam di bagian BAWAH gambar
//    - warna: rgba(0, 0, 0, 180)
//    - tinggi: overlay height
// 4. Render teks putih di atas rectangle dengan layout:
//    Baris 1: "📍 [latitude], [longitude]"      → format: -2.123456°, 117.890123°
//    Baris 2: "🕐 [tanggal] [waktu]"             → format: 15 Jan 2025, 09:32:15 WITA
//    Baris 3: "📁 [nama proyek]"
//    Baris 4: "📱 [nama device] | SiTanam v1.0"
// 5. Font size proporsional terhadap resolusi gambar
// 6. Simpan ke file baru (jangan overwrite original)
// 7. Return path file baru
//
// Contoh hasil visual overlay:
// ┌──────────────────────────────────────────┐
// │                                          │
// │           [FOTO TANAMAN]                 │
// │                                          │
// ├──────────────────────────────────────────┤
// │  📍 -2.123456°, 117.890123°              │
// │  🕐 15 Jan 2025, 09:32:15 WITA          │
// │  📁 Restorasi Mangrove Teluk Adang 2025  │
// │  📱 HP Tim A  |  SiTanam v1.0            │
// └──────────────────────────────────────────┘
```

### Sync Service (sync_service.dart)
```dart
// === PUSH (upload ke server) ===

// pushProject(projectId) method:
// - Cek apakah project sudah ada di Supabase (by id)
// - Jika belum: insert ke Supabase, update synced_to_server=1 di SQLite
// - Jika sudah: skip

// pushPoints(projectId: String?) method:
//   - jika projectId null: push semua proyek
//   - Flow per titik:
//     1. Cek konektivitas
//     2. pushProject(projectId) dulu jika belum sync
//     3. Upload foto ke Cloudinary → dapat secure_url
//     4. Upsert titik ke Supabase (upsert untuk handle duplikat)
//     5. Update SQLite: synced=1, foto_cloud_url=url
//     6. Jika gagal: increment sync_attempt, lanjut ke titik berikutnya
//   - Return SyncResult(success: int, failed: int)

// uploadToCloudinary() method:
// POST multipart ke https://api.cloudinary.com/v1_1/{cloudName}/image/upload
// Field: upload_preset, folder="mangrove_monitoring/{project_id}", file
// Return secure_url dari response JSON

// === PULL (ambil dari server) ===

// fetchProjectsFromServer() method:
// - Fetch semua rows dari Supabase projects table
// - Return List<Project>
// - Dipakai HomeScreen untuk tampilkan daftar proyek di BottomSheet

// downloadProject(projectId) method:
// - Fetch satu proyek dari Supabase by id
// - Insert ke SQLite lokal dengan synced_to_server=1
// - HP sekarang bisa pakai proyek ini secara offline
```

---

## 7. ANDROID CONFIGURATION

### AndroidManifest.xml permissions
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="29" />
```

### android/app/build.gradle
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 23    // Android 6.0+
        targetSdkVersion 34
    }
}
```

---

## 8. UI/UX REQUIREMENTS

- **Bahasa**: seluruh UI dalam Bahasa Indonesia
- **Tema warna**:
  - Primary: Hijau tua #2E7D32
  - Secondary: Hijau muda #81C784
  - Background: #F5F5F5
  - Error: #D32F2F
- **Material Design 3**
- **Tombol minimum 56dp tinggi** (ramah jari dengan sarung tangan)
- **Font size minimum 14sp** untuk readability di luar ruangan
- **Loading state**: tampilkan CircularProgressIndicator untuk semua operasi async
- **Error messages**: tampilkan dalam SnackBar dengan bahasa Indonesia yang jelas
- Contoh pesan error:
  - "GPS tidak tersedia. Aktifkan lokasi di Pengaturan."
  - "Gagal upload foto. Periksa koneksi internet."
  - "Konfigurasi server belum lengkap. Buka Pengaturan."
  - "Penyimpanan hampir penuh. Segera sync data."

---

## 9. ALUR KERJA MULTI-DEVICE (WAJIB DIIMPLEMENTASI)

Ini adalah fitur inti aplikasi. Implementasikan dengan UX yang sangat jelas.

### Skenario: Tim 3 HP mengerjakan proyek yang sama

```
TAHAP 1 - PERSIAPAN DI KANTOR (ada internet)
─────────────────────────────────────────────
HP 1 (Koordinator):
  1. Buka app → tap "➕ Buat Proyek Baru"
  2. Isi form: nama, lokasi, tanggal
  3. Tap simpan → proyek otomatis PUSH ke Supabase
  4. Tampilkan notifikasi: "✅ Proyek berhasil dibuat & tersimpan di server.
     Minta anggota tim untuk ambil proyek dari server."

HP 2 & HP 3 (Anggota Tim):
  1. Buka app → tap ikon ☁️↓ (Ambil Proyek dari Server)
  2. Muncul BottomSheet: daftar proyek di server
     ┌──────────────────────────────────────┐
     │  Proyek Tersedia di Server           │
     │  ○ Penanaman Desa Padang Pengrapat   │
     │    Lokasi: CA Teluk Adang, Paser     │
     │    Dibuat: 15 Jan 2025               │
     │                                      │
     │  [Simpan ke HP]                      │
     └──────────────────────────────────────┘
  3. Centang proyek → tap "Simpan ke HP"
  4. Proyek tersimpan lokal → siap pakai offline

TAHAP 2 - DI LAPANGAN (offline)
─────────────────────────────────────────────
HP 1, HP 2, HP 3:
  - Semua buka proyek "Penanaman Desa Padang Pengrapat"
  - Input titik tanam masing-masing secara independen
  - Semua data tersimpan lokal dengan project_id yang SAMA
  - Tidak perlu koneksi internet

TAHAP 3 - KEMBALI KE KANTOR (ada internet)
─────────────────────────────────────────────
HP 1: tap sync → upload 250 titik
HP 2: tap sync → upload 180 titik
HP 3: tap sync → upload 195 titik

HASIL DI SUPABASE:
  Proyek "Penanaman Desa Padang Pengrapat"
  Total titik: 625 (dari 3 HP)
  Semua tampil di WebGIS dalam satu proyek ✅
```

### UI feedback yang harus ada:
- Saat "Ambil Proyek dari Server": loading indicator + pesan jika tidak ada proyek baru
- Saat proyek berhasil disimpan: SnackBar "✅ Proyek disimpan. Siap dipakai offline."
- Di ProjectCard: badge "📥 Dari Server" untuk proyek yang diambil dari HP lain
- Di ProjectCard: tampilkan total titik dari SEMUA device (setelah sync)

---

## 10. EDGE CASES YANG HARUS DITANGANI

1. **Permission GPS/Kamera ditolak**: tampilkan dialog dengan tombol "Buka Pengaturan"
2. **GPS accuracy > 5m**: tombol "Kunci Koordinat" disabled, tampilkan tombol "Kalibrasi GPS"
3. **GPS tidak membaik setelah 60 detik**: tampilkan saran "Coba aktifkan mode lokasi Akurasi Tinggi di pengaturan HP"
4. **GPS sinyal hilang saat input form**: tampilkan banner "⚠️ Sinyal GPS hilang. Koordinat terakhir dipertahankan." jika sudah dikunci
5. **Foto gagal kompres**: simpan foto original, beri peringatan ukuran besar
6. **Overlay geotag gagal**: simpan foto tanpa overlay, log error, lanjutkan proses
7. **Supabase/Cloudinary belum dikonfigurasi**: block sync, arahkan ke Settings
8. **Sync sebagian gagal**: tampilkan summary "8 berhasil, 2 gagal" dengan opsi retry
9. **Storage HP penuh** (< 50MB): tampilkan warning banner di HomeScreen
10. **Duplicate sync** (ID sudah ada di Supabase): gunakan `upsert` bukan `insert`
11. **Hapus proyek yang masih ada titiknya**: konfirmasi "Proyek ini memiliki X titik. Yakin hapus?"
12. **GPS accuracy fluktuatif** (naik-turun di sekitar 5m): gunakan moving average 3 sample sebelum izinkan kunci

---

## 11. CARA BUILD & DISTRIBUSI APK

Setelah kode selesai, berikan instruksi langkah demi langkah:

1. Install Flutter SDK
2. Setup Android Studio / Android SDK
3. `flutter pub get`
4. Test di emulator: `flutter run`
5. Build release APK: `flutter build apk --release`
6. Lokasi APK: `build/app/outputs/flutter-apk/app-release.apk`
7. Cara kirim ke HP tim: via WhatsApp / kabel USB
8. Cara install di HP: aktifkan "Sumber tidak dikenal" di Pengaturan Android

---

## 12. SETUP CLOUD (INSTRUKSI TAMBAHAN)

Sertakan panduan singkat:

### Supabase Setup
1. Buat akun di supabase.com (gratis)
2. Buat project baru
3. Jalankan SQL schema dari bagian 4
4. Copy URL dan anon key dari Settings > API

### Cloudinary Setup
1. Buat akun di cloudinary.com (gratis, 25GB)
2. Settings > Upload > Add upload preset
3. Pilih "Unsigned" preset
4. Copy cloud name dan preset name

---

## CATATAN PENTING UNTUK AI

- Berikan **kode lengkap** setiap file, siap copy-paste
- Jangan gunakan package yang sudah deprecated
- Pastikan null safety (Dart 3.x)
- Tambahkan komentar dalam **Bahasa Indonesia** pada bagian penting
- Sertakan `pubspec.yaml` lengkap
- Sertakan `AndroidManifest.xml` lengkap
- Jika ada pilihan implementasi, pilih yang **paling simpel dan mudah di-maintain**
- Target perangkat: Android mid-range Indonesia (RAM 3-4GB, Android 8-12)
