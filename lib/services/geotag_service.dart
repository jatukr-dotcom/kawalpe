// =========================================================
// services/geotag_service.dart - Render overlay geotag ke gambar
// =========================================================
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GeotagService {
  /// Tambahkan overlay geotag langsung ke file gambar
  ///
  /// Render teks informasi (koordinat, waktu, proyek, device) ke bagian bawah gambar.
  /// Mengembalikan path file baru dengan overlay sudah tertanam.
  Future<String> addOverlay({
    required String imagePath,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required String namaProyek,
    required String namaDevice,
  }) async {
    try {
      // 1. Load gambar dari file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        debugPrint('GeotagService: Gagal decode gambar');
        return imagePath; // Kembalikan path asli jika gagal
      }

      // 2. Hitung dimensi overlay (20% tinggi gambar, minimal 80px)
      final overlayHeight = (image.height * 0.20).clamp(80, 300).toInt();
      final imgWidth = image.width;
      final imgHeight = image.height;

      // 3. Gambar rectangle semi-transparan hitam di bawah gambar
      // Warna hitam dengan alpha 180/255 ≈ 70% transparan
      final overlayColor = img.ColorRgba8(0, 0, 0, 180);

      for (int y = imgHeight - overlayHeight; y < imgHeight; y++) {
        for (int x = 0; x < imgWidth; x++) {
          final existingPixel = image.getPixel(x, y);
          // Blend pixel asli dengan warna overlay semi-transparan
          final blended = img.ColorRgba8(
            ((existingPixel.r * (255 - 180) + overlayColor.r * 180) / 255).toInt(),
            ((existingPixel.g * (255 - 180) + overlayColor.g * 180) / 255).toInt(),
            ((existingPixel.b * (255 - 180) + overlayColor.b * 180) / 255).toInt(),
            255,
          );
          image.setPixel(x, y, blended);
        }
      }

      // 4. Siapkan teks overlay
      final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
      final timeFormatter = DateFormat('HH:mm:ss');

      final latStr = '${latitude >= 0 ? '' : ''}${latitude.toStringAsFixed(6)}°';
      final lngStr = '${longitude.toStringAsFixed(6)}°';

      final lines = [
        'GPS: $latStr, $lngStr',
        '${dateFormatter.format(timestamp)} ${timeFormatter.format(timestamp)} WITA',
        'Proyek: $namaProyek',
        'Device: $namaDevice | Kawal PE v1.0',
      ];

      // 5. Hitung font size proporsional terhadap resolusi
      // Untuk gambar 800px lebar: font ~14px, untuk 1920px: font ~32px
      final fontSize = (imgWidth / 55).clamp(12, 36).toInt();
      final lineHeight = (fontSize * 1.5).toInt();
      final paddingLeft = (imgWidth * 0.02).toInt();
      final paddingTop = imgHeight - overlayHeight + (overlayHeight * 0.15).toInt();

      // 6. Render teks putih menggunakan font bawaan package image
      for (int i = 0; i < lines.length; i++) {
        final yPos = paddingTop + (i * lineHeight);
        if (yPos + lineHeight > imgHeight) break; // Jangan overflow

        img.drawString(
          image,
          lines[i],
          font: fontSize > 20 ? img.arial24 : img.arial14,
          x: paddingLeft,
          y: yPos,
          color: img.ColorRgba8(255, 255, 255, 255), // Putih solid
        );
      }

      // 7. Simpan ke file baru (jangan overwrite original)
      final appDir = await getApplicationDocumentsDirectory();
      final geotagDir = Directory(p.join(appDir.path, 'geotagged'));
      if (!await geotagDir.exists()) {
        await geotagDir.create(recursive: true);
      }

      final originalName = p.basenameWithoutExtension(imagePath);
      final newFileName = '${originalName}_geotagged.jpg';
      final newPath = p.join(geotagDir.path, newFileName);

      // Encode kembali ke JPEG dengan kualitas 85
      final jpegBytes = img.encodeJpg(image, quality: 85);
      final outputFile = File(newPath);
      await outputFile.writeAsBytes(Uint8List.fromList(jpegBytes));

      debugPrint('GeotagService: Overlay berhasil ditambahkan → $newPath');
      return newPath;
    } catch (e) {
      // Edge case 6: Overlay geotag gagal → simpan foto tanpa overlay
      debugPrint('GeotagService: ERROR menambahkan overlay: $e');
      return imagePath; // Kembalikan path asli
    }
  }
}
