// =========================================================
// services/camera_service.dart - Layanan kamera dan kompres foto
// =========================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'geotag_service.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();
  final GeotagService _geotagService = GeotagService();

  /// Ambil foto dari kamera, kompres, tambahkan overlay geotag
  ///
  /// Mengembalikan path file foto yang sudah dikompres + overlay,
  /// atau null jika user membatalkan / terjadi error.
  Future<String?> takePhoto({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required String namaProyek,
    required String namaDevice,
  }) async {
    try {
      // Ambil foto dari kamera (bukan gallery)
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85, // Kompres via image_picker langsung
        maxWidth: 1600,
        maxHeight: 1200,
      );

      if (photo == null) {
        debugPrint('CameraService: User membatalkan pengambilan foto');
        return null;
      }

      // Buat direktori penyimpanan di dalam app
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // Nama file unik berdasarkan timestamp
      final fileName = 'kawalpe_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputPath = p.join(photosDir.path, fileName);

      // Kompres menggunakan package 'image' (tanpa native plugin)
      String finalPath;
      try {
        final bytes = await File(photo.path).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final compressed = img.encodeJpg(decoded, quality: 70);
          await File(outputPath).writeAsBytes(compressed);
          finalPath = outputPath;
        } else {
          // Fallback: salin file original
          await File(photo.path).copy(outputPath);
          finalPath = outputPath;
        }
      } catch (compressError) {
        debugPrint('CameraService: Error kompres: $compressError. Pakai original.');
        await File(photo.path).copy(outputPath);
        finalPath = outputPath;
      }

      // Tambahkan overlay geotag ke gambar
      final geotaggedPath = await _geotagService.addOverlay(
        imagePath: finalPath,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        namaProyek: namaProyek,
        namaDevice: namaDevice,
      );

      return geotaggedPath;
    } catch (e) {
      debugPrint('CameraService: Error mengambil foto: $e');
      return null;
    }
  }
}
