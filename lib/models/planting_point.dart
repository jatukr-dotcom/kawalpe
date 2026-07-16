// =========================================================
// models/planting_point.dart - Model data Titik Tanam
// =========================================================
import 'dart:math' as math;

class PlantingPoint {
  final String id;             // UUID v4 - primary key
  final String projectId;      // FK ke Project.id
  final double latitude;
  final double longitude;
  final double? accuracy;      // GPS accuracy dalam meter
  final String spesies;
  final String kondisi;        // 'Sehat', 'Merana', 'Mati'
  final String? catatan;
  final double? tinggi;        // Tinggi pohon dalam cm
  final double? diameter;      // Diameter batang dalam cm (dihitung dari keliling / π)
  final String? fotoLocalPath;
  String? fotoCloudUrl;
  final String deviceId;
  final String? recordedBy;    // Username petugas yang merekam
  final int? nomorTitik;       // Nomor urut global dari Supabase (null = belum sync)
  final String timestamp;      // ISO 8601
  bool synced;
  int syncAttempt;

  PlantingPoint({
    required this.id,
    required this.projectId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.spesies,
    required this.kondisi,
    this.catatan,
    this.tinggi,
    this.diameter,
    this.fotoLocalPath,
    this.fotoCloudUrl,
    required this.deviceId,
    this.recordedBy,
    this.nomorTitik,
    required this.timestamp,
    this.synced = false,
    this.syncAttempt = 0,
  });

  /// Hitung diameter dari keliling menggunakan rumus: diameter = keliling / π
  static double kelilingToDiameter(double keliling) {
    return keliling / math.pi;
  }

  /// Konversi dari Map SQLite ke objek PlantingPoint
  factory PlantingPoint.fromMap(Map<String, dynamic> map) {
    return PlantingPoint(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      accuracy: map['accuracy'] as double?,
      spesies: map['spesies'] as String,
      kondisi: map['kondisi'] as String,
      catatan: map['catatan'] as String?,
      tinggi: map['tinggi'] as double?,
      diameter: map['diameter'] as double?,
      fotoLocalPath: map['foto_local_path'] as String?,
      fotoCloudUrl: map['foto_cloud_url'] as String?,
      deviceId: map['device_id'] as String,
      recordedBy: map['recorded_by'] as String?,
      nomorTitik: map['nomor_titik'] as int?,
      timestamp: map['timestamp'] as String,
      synced: (map['synced'] as int? ?? 0) == 1,
      syncAttempt: map['sync_attempt'] as int? ?? 0,
    );
  }

  /// Konversi ke Map untuk penyimpanan SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'spesies': spesies,
      'kondisi': kondisi,
      'catatan': catatan,
      'tinggi': tinggi,
      'diameter': diameter,
      'foto_local_path': fotoLocalPath,
      'foto_cloud_url': fotoCloudUrl,
      'device_id': deviceId,
      'recorded_by': recordedBy,
      'nomor_titik': nomorTitik,
      'timestamp': timestamp,
      'synced': synced ? 1 : 0,
      'sync_attempt': syncAttempt,
    };
  }

  /// Konversi ke Map untuk dikirim ke Supabase
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'project_id': projectId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'spesies': spesies,
      'kondisi': kondisi,
      'catatan': catatan,
      'tinggi': tinggi,
      'diameter': diameter,
      'foto_url': fotoCloudUrl,
      'device_id': deviceId,
      'recorded_by': recordedBy,
      'timestamp': timestamp,
    };
  }

  /// Koordinat singkat untuk tampilan di list
  String get koordinatSingkat {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// Koordinat lengkap 6 desimal
  String get koordinatLengkap {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}


/// Hasil operasi sync
class SyncResult {
  final int success;
  final int failed;
  final List<String> errorMessages;

  SyncResult({
    required this.success,
    required this.failed,
    this.errorMessages = const [],
  });

  bool get hasErrors => failed > 0;
  int get total => success + failed;
}
