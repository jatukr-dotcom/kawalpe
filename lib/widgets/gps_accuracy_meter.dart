// =========================================================
// widgets/gps_accuracy_meter.dart - Meter akurasi GPS visual
// =========================================================
import 'package:flutter/material.dart';
import '../services/gps_service.dart';

class GpsAccuracyMeter extends StatelessWidget {
  final double? accuracy;
  final bool isLocked;

  const GpsAccuracyMeter({
    super.key,
    required this.accuracy,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    if (accuracy == null) {
      return _buildLoadingState();
    }

    final gpsService = GpsService();
    final status = gpsService.getAccuracyStatus(accuracy!);
    final color = gpsService.getAccuracyColor(accuracy!);
    final label = gpsService.getAccuracyLabel(accuracy!);
    final isAcceptable = gpsService.isAccuracyAcceptable(accuracy!);

    // Hitung progress bar: 0-20m range, ≤5m = hijau
    final progress = (1 - (accuracy! / 20.0)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocked ? Colors.green : color.withOpacity(0.4),
          width: isLocked ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ikon + nilai akurasi
          Row(
            children: [
              Icon(
                isLocked
                    ? Icons.lock
                    : (isAcceptable ? Icons.gps_fixed : Icons.gps_not_fixed),
                color: isLocked ? Colors.green : color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isLocked
                    ? '🔒 Terkunci'
                    : '${accuracy!.toStringAsFixed(1)} meter',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isLocked ? Colors.green : color,
                ),
              ),
              const Spacer(),
              // Badge status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLocked ? Colors.green : color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLocked ? 'TERKUNCI' : label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar akurasi
          Stack(
            children: [
              // Background bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Progress bar
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: isLocked ? 1.0 : progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isLocked ? Colors.green : color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Marker threshold 5m (= 75% progress jika max=20m)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.75 - 60,
                child: Container(
                  width: 2,
                  height: 8,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Label skala
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0m', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(
                '← Target ≤5m',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('20m+', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),

          // Pesan status
          if (!isLocked) ...[
            const SizedBox(height: 8),
            Text(
              _getStatusMessage(status),
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Mencari sinyal GPS...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage(GpsAccuracyStatus status) {
    switch (status) {
      case GpsAccuracyStatus.excellent:
        return '✅ Akurasi sangat baik! Siap dikunci.';
      case GpsAccuracyStatus.good:
        return '✅ Akurasi baik. Siap dikunci.';
      case GpsAccuracyStatus.poor:
        return '⚠️ Akurasi kurang. Tunggu sinyal membaik.';
      case GpsAccuracyStatus.unacceptable:
        return '❌ Akurasi tidak memadai. Pindah ke area terbuka.';
    }
  }
}

/// Widget chip status sync untuk titik tanam
class SyncStatusChip extends StatelessWidget {
  final bool synced;
  final int syncAttempt;

  const SyncStatusChip({
    super.key,
    required this.synced,
    this.syncAttempt = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (synced) {
      return const Chip(
        label: Text('Tersync', style: TextStyle(fontSize: 11, color: Colors.white)),
        backgroundColor: Colors.green,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    }

    return Chip(
      label: Text(
        syncAttempt > 0 ? 'Pending ($syncAttempt)' : 'Belum sync',
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: syncAttempt > 3 ? Colors.red : Colors.orange,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
