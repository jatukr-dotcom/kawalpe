// =========================================================
// models/project.dart - Model data Proyek
// =========================================================

class Project {
  final String id;               // UUID v4 - sama di semua HP
  final String namaProyek;
  final String lokasi;
  final String? deskripsi;
  final String? penanggungjawab; // Nama kelompok tani / penanggung jawab
  final String tanggalMulai;
  final String? tanggalSelesai;
  final String createdByDevice;  // device_id HP yang membuat proyek
  final String createdAt;
  bool syncedToServer;           // apakah proyek sudah ada di Supabase
  int jumlahTitik;               // dihitung dari DB lokal
  int jumlahBelumSync;           // dihitung dari DB lokal

  Project({
    required this.id,
    required this.namaProyek,
    required this.lokasi,
    this.deskripsi,
    this.penanggungjawab,
    required this.tanggalMulai,
    this.tanggalSelesai,
    required this.createdByDevice,
    required this.createdAt,
    this.syncedToServer = false,
    this.jumlahTitik = 0,
    this.jumlahBelumSync = 0,
  });

  /// Konversi dari Map SQLite ke objek Project
  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      namaProyek: map['nama_proyek'] as String,
      lokasi: map['lokasi'] as String,
      deskripsi: map['deskripsi'] as String?,
      penanggungjawab: map['penanggungjawab'] as String?,
      tanggalMulai: map['tanggal_mulai'] as String,
      tanggalSelesai: map['tanggal_selesai'] as String?,
      createdByDevice: map['created_by_device'] as String,
      createdAt: map['created_at'] as String,
      syncedToServer: (map['synced_to_server'] as int? ?? 0) == 1,
      jumlahTitik: map['jumlah_titik'] as int? ?? 0,
      jumlahBelumSync: map['jumlah_belum_sync'] as int? ?? 0,
    );
  }

  /// Konversi dari Map Supabase ke objek Project
  factory Project.fromSupabase(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      namaProyek: map['nama_proyek'] as String,
      lokasi: map['lokasi'] as String,
      deskripsi: map['deskripsi'] as String?,
      penanggungjawab: map['penanggungjawab'] as String?,
      tanggalMulai: map['tanggal_mulai'] as String,
      tanggalSelesai: map['tanggal_selesai'] as String?,
      createdByDevice: map['created_by_device'] as String,
      createdAt: map['created_at'] as String,
      syncedToServer: true,
    );
  }

  /// Konversi ke Map untuk penyimpanan SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_proyek': namaProyek,
      'lokasi': lokasi,
      'deskripsi': deskripsi,
      'penanggungjawab': penanggungjawab,
      'tanggal_mulai': tanggalMulai,
      'tanggal_selesai': tanggalSelesai,
      'created_by_device': createdByDevice,
      'created_at': createdAt,
      'synced_to_server': syncedToServer ? 1 : 0,
    };
  }

  /// Konversi ke Map untuk dikirim ke Supabase
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nama_proyek': namaProyek,
      'lokasi': lokasi,
      'deskripsi': deskripsi,
      'penanggungjawab': penanggungjawab,
      'tanggal_mulai': tanggalMulai,
      'tanggal_selesai': tanggalSelesai,
      'created_by_device': createdByDevice,
      'created_at': createdAt,
    };
  }

  /// Salin proyek dengan nilai baru (immutable pattern)
  Project copyWith({
    String? id,
    String? namaProyek,
    String? lokasi,
    String? deskripsi,
    String? penanggungjawab,
    String? tanggalMulai,
    String? tanggalSelesai,
    String? createdByDevice,
    String? createdAt,
    bool? syncedToServer,
    int? jumlahTitik,
    int? jumlahBelumSync,
  }) {
    return Project(
      id: id ?? this.id,
      namaProyek: namaProyek ?? this.namaProyek,
      lokasi: lokasi ?? this.lokasi,
      deskripsi: deskripsi ?? this.deskripsi,
      penanggungjawab: penanggungjawab ?? this.penanggungjawab,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      tanggalSelesai: tanggalSelesai ?? this.tanggalSelesai,
      createdByDevice: createdByDevice ?? this.createdByDevice,
      createdAt: createdAt ?? this.createdAt,
      syncedToServer: syncedToServer ?? this.syncedToServer,
      jumlahTitik: jumlahTitik ?? this.jumlahTitik,
      jumlahBelumSync: jumlahBelumSync ?? this.jumlahBelumSync,
    );
  }
}
