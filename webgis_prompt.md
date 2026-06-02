# PROMPT WEBGIS KAWALPE

---

Buatkan saya aplikasi **WebGIS monitoring titik tanam mangrove** bernama **KawalPE** menggunakan **Next.js + Tailwind CSS**.

---

## Konteks Proyek

Aplikasi ini adalah dashboard web untuk memvisualisasikan data titik tanam mangrove yang dikumpulkan oleh petugas lapangan BKSDA menggunakan aplikasi Flutter di HP Android. Data tersimpan di **Supabase (PostgreSQL)** dan diakses langsung via Supabase JS Client.

---

## Stack Teknologi

- **Framework**: Next.js 14 (App Router)
- **Styling**: Tailwind CSS
- **Peta**: Leaflet.js + plugin `leaflet.markercluster` (untuk clustering dan spiderfy)
- **Chart**: Chart.js (pie chart + bar chart)
- **Tabel**: TanStack Table v8 (sort, filter, pagination)
- **Database**: Supabase (PostgreSQL) — akses via `@supabase/supabase-js`
- **Auth admin**: Supabase Auth

---

## Struktur Database Supabase

### Tabel `projects`
```sql
id              TEXT PRIMARY KEY
nama            TEXT NOT NULL
deskripsi       TEXT
penanggungjawab TEXT
tanggal_mulai   TEXT NOT NULL
tanggal_selesai TEXT
jenis_lahan     TEXT  -- 'Tambak', 'Pesisir', 'Terestrial'
created_at      TEXT NOT NULL
```

### Tabel `planting_points`
```sql
id              TEXT PRIMARY KEY
project_id      TEXT REFERENCES projects(id)
latitude        REAL NOT NULL
longitude       REAL NOT NULL
accuracy        REAL
spesies         TEXT NOT NULL   -- nama spesies mangrove
kondisi         TEXT NOT NULL   -- 'Sehat', 'Merana', 'Mati'
catatan         TEXT
foto_url        TEXT            -- URL foto dari Cloudinary
device_id       TEXT
recorded_by     TEXT            -- username petugas yang merekam
timestamp       TEXT NOT NULL   -- ISO 8601
synced          INTEGER DEFAULT 0
```

### Tabel `app_users`
```sql
id            TEXT PRIMARY KEY
nama          TEXT NOT NULL
username      TEXT UNIQUE NOT NULL
role          TEXT NOT NULL   -- 'admin' atau 'user'
created_at    TEXT NOT NULL
```

---

## 3 Halaman Aplikasi

---

### HALAMAN 1: Peta Sebaran (`/` atau `/map`)

**Layout**: Sidebar kiri + Peta kanan

**Sidebar Kiri berisi:**
1. **Logo + Judul** "KawalPE WebGIS"
2. **Pie Chart** — distribusi kondisi tanaman:
   - Sehat (hijau `#2E7D32`)
   - Merana (oranye `#F57F17`)
   - Mati (merah `#B71C1C`)
3. **Bar Chart** — jumlah titik per jenis lahan:
   - Tambak / Pesisir / Terestrial
   (data diambil dari JOIN `planting_points` dengan `projects`)
4. **Panel Statistik** ringkas:
   - Total titik
   - Total proyek
   - Total petugas
5. **Filter**:
   - Dropdown Proyek (semua proyek dari tabel `projects`)
   - Dropdown Kondisi (Sehat / Merana / Mati / Semua)
   - Dropdown Jenis Lahan (Tambak / Pesisir / Terestrial / Semua)
   - Dropdown Spesies

**Peta (Leaflet.js):**
- Basemap: OpenStreetMap
- Semua titik dari `planting_points` tampil sebagai marker
- Gunakan **`leaflet.markercluster`** untuk cluster marker yang berdekatan
- Fitur **Spiderfy**: klik cluster yang padat → marker menyebar spiral
- Warna marker sesuai kondisi:
  - Sehat → ikon hijau
  - Merana → ikon oranye
  - Mati → ikon merah
- **Popup saat klik marker**:
  ```
  [thumbnail foto 200px — dari foto_url]
  ─────────────────────────────────
  🌱 [spesies]
  ● [kondisi badge berwarna]  |  📍 [jenis_lahan dari proyek]
  ─────────────────────────────────
  👤 [nama petugas] (@[recorded_by])
  📅 [timestamp format: dd MMMM yyyy, HH:mm]
  📁 [nama proyek]
  ─────────────────────────────────
  [Lihat Detail →] (link ke halaman tabel dengan filter ID ini)
  ```

---

### HALAMAN 2: Tabel Data (`/data`)

**Header**: Search bar + Filter (Kondisi, Jenis Lahan, Proyek) + Tombol Export CSV

**Tabel kolom:**
| Kolom | Data | Keterangan |
|---|---|---|
| No | auto | Nomor urut |
| ID | `id` (8 karakter) | Truncated UUID |
| Jenis Pohon | `spesies` | |
| Jenis Lahan | `jenis_lahan` dari proyek | Via JOIN |
| Kondisi | `kondisi` | Badge berwarna |
| Waktu | `timestamp` | Format dd/mm/yyyy HH:mm |
| Foto | `foto_url` | Thumbnail kecil, klik → lightbox |
| Detail | — | Tombol → buka modal |

**Modal Detail** (klik tombol Detail):
- Tampilkan semua info titik lengkap
- Foto ukuran penuh
- Koordinat GPS dengan tombol "Buka di Google Maps"
- Info petugas, proyek, waktu

**Fitur tabel:**
- Sort per kolom (klik header)
- Search global
- Filter per kondisi, jenis lahan, proyek
- Pagination (25 per halaman)
- Export CSV seluruh data yang sedang difilter

---

### HALAMAN 3: Admin Panel (`/admin`)

**Halaman Login** (jika belum login):
```
┌─────────────────────────────────────┐
│    🔐 Login Admin KawalPE           │
│                                     │
│  Email:    [__________________]     │
│  Password: [__________________]     │
│                                     │
│           [  Masuk  ]               │
└─────────────────────────────────────┘
```
Auth menggunakan **Supabase Auth** (`supabase.auth.signInWithPassword`).

**Setelah login, tampilkan:**
1. **Tabel titik tanam** (sama seperti Halaman 2, tapi dengan kolom aksi):
   - Tombol **Edit** → modal edit kondisi + catatan
   - Tombol **Hapus** → konfirmasi dialog → delete dari Supabase
2. **Manajemen Proyek**:
   - List semua proyek
   - Form buat proyek baru (nama, deskripsi, penanggung jawab, tanggal, jenis lahan)
   - Edit / hapus proyek
3. **Daftar Pengguna** (read-only dari tabel `app_users`):
   - Nama, username, role, tanggal dibuat

---

## Desain & UI

- **Tema**: Dark mode dengan aksen hijau (`#2E7D32` dan `#1B5E20`)
- **Font**: Inter (Google Fonts)
- **Nuansa**: Modern, bersih, profesional — cocok untuk instansi pemerintah
- **Responsive**: Mobile-friendly (sidebar collapse di layar kecil)
- **Loading state**: Skeleton loader saat data sedang diambil
- **Error state**: Pesan ramah jika gagal ambil data

---

## Konfigurasi Supabase

Gunakan environment variable di `.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Akses data `planting_points` dengan JOIN ke `projects` untuk mendapatkan `jenis_lahan` dan `nama` proyek:
```sql
SELECT
  p.*,
  pr.nama as nama_proyek,
  pr.jenis_lahan
FROM planting_points p
LEFT JOIN projects pr ON p.project_id = pr.id
ORDER BY p.timestamp DESC
```

---

## Catatan Penting

1. **Marker cluster + Spiderfy**: WAJIB pakai `leaflet.markercluster`. Saat marker berdekatan (titik tanam mangrove sangat padat di satu kawasan), marker harus di-cluster dan ketika diklik menyebar dalam pola spiral (spiderfy). Ini fitur krusial.

2. **Foto**: `foto_url` berisi URL Cloudinary. Tampilkan sebagai `<img src={foto_url}>`. Jika null, tampilkan placeholder icon daun.

3. **Jenis lahan per proyek**: `jenis_lahan` ada di tabel `projects`, BUKAN di `planting_points`. Untuk mendapatkan jenis lahan setiap titik, harus JOIN.

4. **Data lama**: Beberapa titik lama mungkin tidak punya `recorded_by` atau `foto_url` — handle dengan graceful fallback ("Tidak diketahui" / placeholder).

5. **Row Level Security**: Pastikan di Supabase sudah ada policy:
```sql
-- Akses baca publik untuk peta dan tabel
CREATE POLICY "public_read" ON planting_points FOR SELECT USING (true);
CREATE POLICY "public_read_projects" ON projects FOR SELECT USING (true);
-- Edit/hapus hanya admin (via Supabase Auth service_role atau RLS policy)
```

---

## Output yang Diharapkan

Buatkan project Next.js lengkap dengan:
- `app/page.tsx` → Halaman peta (Halaman 1)
- `app/data/page.tsx` → Halaman tabel (Halaman 2)
- `app/admin/page.tsx` → Halaman admin (Halaman 3)
- `app/layout.tsx` → Layout dengan navbar
- `components/Map.tsx` → Komponen Leaflet (gunakan dynamic import, `ssr: false`)
- `components/StatsChart.tsx` → Pie chart + bar chart Chart.js
- `components/DataTable.tsx` → TanStack Table
- `lib/supabase.ts` → Supabase client
- `types/index.ts` → TypeScript types untuk PlantingPoint, Project, AppUser
- `.env.local.example` → Template environment variable
- `README.md` → Cara setup dan deploy ke Vercel
