// =========================================================
// services/gps_service.dart - Layanan GPS dengan akurasi ketat
// =========================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Threshold akurasi GPS yang diizinkan (meter)
const double kGpsAkurasiMinimum = 5.0;

/// Jumlah sample untuk moving average anti-fluktuasi
const int kMovingAverageSample = 3;

/// Status akurasi GPS
enum GpsAccuracyStatus {
  excellent, // ≤2m
  good,      // 2-5m (LULUS threshold)
  poor,      // 5-15m (TIDAK LULUS)
  unacceptable, // >15m (TIDAK LULUS)
}

class GpsService {
  StreamSubscription<Position>? _positionSubscription;
  final _positionController = StreamController<Position?>.broadcast();
  
  // Buffer untuk moving average anti-fluktuasi
  final List<double> _accuracyBuffer = [];

  Stream<Position?> get positionStream => _positionController.stream;

  /// Mulai streaming posisi GPS secara real-time
  Future<void> startStream() async {
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0, // Update setiap perubahan sekecil apapun
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        _positionController.add(position);
      },
      onError: (error) {
        debugPrint('GPS stream error: $error');
        _positionController.add(null);
      },
    );
  }

  /// Hentikan streaming untuk hemat baterai
  void stopStream() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _accuracyBuffer.clear();
  }

  /// Dapatkan posisi sekali saja (tidak stream)
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      debugPrint('Gagal mendapatkan posisi: $e');
      return null;
    }
  }

  /// Cek dan minta permission GPS
  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Layanan GPS tidak aktif');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permission GPS ditolak');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Permission GPS ditolak permanen');
      return false;
    }

    return true;
  }

  /// Cek apakah layanan GPS aktif
  Future<bool> isGpsEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Cek status permission GPS
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Buka pengaturan lokasi HP
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Buka pengaturan aplikasi (untuk permission yang sudah ditolak)
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Cek apakah akurasi memenuhi syarat (≤5m)
  bool isAccuracyAcceptable(double accuracy) {
    return accuracy <= kGpsAkurasiMinimum;
  }

  /// Hitung moving average akurasi untuk mencegah fluktuasi
  /// Menggunakan 3 sample terakhir
  bool isAccuracyStable(double newAccuracy) {
    _accuracyBuffer.add(newAccuracy);
    if (_accuracyBuffer.length > kMovingAverageSample) {
      _accuracyBuffer.removeAt(0);
    }

    if (_accuracyBuffer.length < kMovingAverageSample) {
      return false; // Belum cukup sample
    }

    // Hitung rata-rata
    final avg = _accuracyBuffer.reduce((a, b) => a + b) / _accuracyBuffer.length;
    return avg <= kGpsAkurasiMinimum;
  }

  /// Reset buffer moving average
  void resetAccuracyBuffer() {
    _accuracyBuffer.clear();
  }

  /// Dapatkan status akurasi GPS
  GpsAccuracyStatus getAccuracyStatus(double accuracy) {
    if (accuracy <= 2.0) return GpsAccuracyStatus.excellent;
    if (accuracy <= 5.0) return GpsAccuracyStatus.good;
    if (accuracy <= 15.0) return GpsAccuracyStatus.poor;
    return GpsAccuracyStatus.unacceptable;
  }

  /// Label teks status akurasi dalam Bahasa Indonesia
  String getAccuracyLabel(double accuracy) {
    switch (getAccuracyStatus(accuracy)) {
      case GpsAccuracyStatus.excellent:
        return 'Sangat Baik';
      case GpsAccuracyStatus.good:
        return 'Baik';
      case GpsAccuracyStatus.poor:
        return 'Kurang';
      case GpsAccuracyStatus.unacceptable:
        return 'Tidak Memadai';
    }
  }

  /// Warna indikator berdasarkan status akurasi
  Color getAccuracyColor(double accuracy) {
    switch (getAccuracyStatus(accuracy)) {
      case GpsAccuracyStatus.excellent:
        return const Color(0xFF1B5E20); // Hijau tua
      case GpsAccuracyStatus.good:
        return const Color(0xFF2E7D32); // Hijau
      case GpsAccuracyStatus.poor:
        return const Color(0xFFE65100); // Oranye
      case GpsAccuracyStatus.unacceptable:
        return const Color(0xFFB71C1C); // Merah
    }
  }

  void dispose() {
    stopStream();
    _positionController.close();
  }
}
