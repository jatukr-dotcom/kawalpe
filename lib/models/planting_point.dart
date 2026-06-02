// =========================================================
// models/planting_point.dart - Model data Titik Tanam
// =========================================================

class PlantingPoint {
  final String id;             // UUID v4 - primary key
  final String projectId;      // FK ke Project.id
  final double latitude;
  final double longitude;
  final double? accuracy;      // GPS accuracy dalam meter
  final String spesies;
  final String kondisi;        // 'Baik', 'Sedang', 'Buruk'
  final String? catatan;
  final String? fotoLocalPath;
  String? fotoCloudUrl;
  final String deviceId;
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
    this.fotoLocalPath,
    this.fotoCloudUrl,
    required this.deviceId,
    required this.timestamp,
    this.synced = false,
    this.syncAttempt = 0,
  });

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
      fotoLocalPath: map['foto_local_path'] as String?,
      fotoCloudUrl: map['foto_cloud_url'] as String?,
      deviceId: map['device_id'] as String,
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
      'foto_local_path': fotoLocalPath,
      'foto_cloud_url': fotoCloudUrl,
      'device_id': deviceId,
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
      'foto_url': fotoCloudUrl,
      'device_id': deviceId,
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

/// Daftar spesies mangrove yang tersedia
const List<String> kDaftarSpesies = [
  'Rhizophora mucronata',
  'Avicennia marina',
  'Sonneratia alba',
  'Bruguiera gymnorrhiza',
  'Nypa fruticans',
  'Lainnya',
];

/// Daftar kondisi tanaman
const List<String> kDaftarKondisi = ['Sehat', 'Merana', 'Mati'];

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
