// =========================================================
// services/camera_service.dart - Layanan kamera dan kompres foto
// =========================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
        imageQuality: 100, // Ambil kualitas penuh dulu, kompres manual
      );

      if (photo == null) {
        debugPrint('CameraService: User membatalkan pengambilan foto');
        return null;
      }

      // Buat direktori penyimpanan di dalam app (bukan DCIM publik)
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // Nama file unik berdasarkan timestamp
      final fileName = 'kawalpe_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedPath = p.join(photosDir.path, fileName);

      // Kompres foto menggunakan FlutterImageCompress
      String finalPath;
      try {
        final result = await FlutterImageCompress.compressAndGetFile(
          photo.path,
          compressedPath,
          quality: 70,
          minWidth: 800,
          minHeight: 600,
          format: CompressFormat.jpeg,
        );

        if (result == null) {
          // Edge case 5: Kompres gagal → pakai foto original
          debugPrint('CameraService: Kompres gagal, pakai foto original');
          final originalFile = File(photo.path);
          await originalFile.copy(compressedPath);
          finalPath = compressedPath;
        } else {
          finalPath = result.path;
        }
      } catch (compressError) {
        // Edge case 5: Error saat kompres → pakai foto original
        debugPrint('CameraService: Error kompres: $compressError. Pakai original.');
        final originalFile = File(photo.path);
        await originalFile.copy(compressedPath);
        finalPath = compressedPath;
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
