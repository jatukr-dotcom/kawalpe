// =========================================================
// screens/gps_calibration_screen.dart - Modal kalibrasi akurasi GPS
// =========================================================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/gps_service.dart';

/// Data yang dikembalikan saat kalibrasi berhasil
class GpsCalibrationResult {
  final double latitude;
  final double longitude;
  final double accuracy;

  const GpsCalibrationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

class GpsCalibrationScreen extends StatefulWidget {
  const GpsCalibrationScreen({super.key});

  @override
  State<GpsCalibrationScreen> createState() => _GpsCalibrationScreenState();
}

class _GpsCalibrationScreenState extends State<GpsCalibrationScreen>
    with TickerProviderStateMixin {
  final GpsService _gpsService = GpsService();

  // State GPS
  Position? _currentPosition;
  double? _currentAccuracy;
  bool _isAccuracyGood = false;

  // Auto-close countdown
  int _countdownSeconds = 0;
  Timer? _countdownTimer;
  Timer? _autoCloseTimer;

  // Buffer akurasi untuk stabilitas
  final List<double> _accuracyBuffer = [];

  // Animasi radar
  late AnimationController _radarController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Animasi rotasi radar
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Animasi pulse saat akurasi bagus
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _startGpsStream();
  }

  void _startGpsStream() {
    _gpsService.startStream();
    _gpsService.positionStream.listen((position) {
      if (!mounted || position == null) return;

      // Update buffer akurasi
      _accuracyBuffer.add(position.accuracy);
      if (_accuracyBuffer.length > 3) _accuracyBuffer.removeAt(0);
      final avgAccuracy = _accuracyBuffer.isNotEmpty
          ? _accuracyBuffer.reduce((a, b) => a + b) / _accuracyBuffer.length
          : position.accuracy;

      final wasGood = _isAccuracyGood;
      final isNowGood = avgAccuracy <= kGpsAkurasiMinimum;

      setState(() {
        _currentPosition = position;
        _currentAccuracy = avgAccuracy;
        _isAccuracyGood = isNowGood;
      });

      // Mulai countdown auto-close saat akurasi pertama kali bagus
      if (isNowGood && !wasGood) {
        _startAutoCloseCountdown();
        _pulseController.repeat(reverse: true);
      } else if (!isNowGood && wasGood) {
        // Akurasi memburuk lagi → batalkan countdown
        _cancelCountdown();
        _pulseController.stop();
      }
    });
  }

  void _startAutoCloseCountdown() {
    _countdownSeconds = 3;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        // Auto-close dengan koordinat saat ini
        _gunakanKoordinat();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 0;
  }

  void _gunakanKoordinat() {
    if (_currentPosition == null || !_isAccuracyGood) return;

    final result = GpsCalibrationResult(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      accuracy: _currentAccuracy!,
    );

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _autoCloseTimer?.cancel();
    _gpsService.stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalibrasi Akurasi GPS'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Animasi radar
            _buildRadarAnimation(),
            const SizedBox(height: 24),

            // Nilai akurasi besar
            _buildAccuracyDisplay(),
            const SizedBox(height: 16),

            // Progress bar akurasi
            _buildAccuracyProgressBar(),
            const SizedBox(height: 24),

            // Status text realtime
            _buildStatusText(),
            const SizedBox(height: 24),

            // Panduan tips
            _buildTipsCard(),
            const SizedBox(height: 24),

            // Countdown auto-close
            if (_isAccuracyGood && _countdownSeconds > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  '✅ Mengunci otomatis dalam $_countdownSeconds detik...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tombol aksi
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarAnimation() {
    final color = _isAccuracyGood ? Colors.green : Colors.red;

    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _radarController,
        builder: (ctx, child) {
          return CustomPaint(
            painter: _RadarPainter(
              rotation: _radarController.value * 2 * math.pi,
              accuracy: _currentAccuracy,
              isGood: _isAccuracyGood,
              color: color,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccuracyDisplay() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (ctx, child) {
        final scale = _isAccuracyGood
            ? 1.0 + (_pulseController.value * 0.05)
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Text(
            _currentAccuracy != null
                ? '${_currentAccuracy!.toStringAsFixed(1)} m'
                : '-- m',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _isAccuracyGood ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccuracyProgressBar() {
    final accuracy = _currentAccuracy ?? 20.0;
    // Progress: 0m=100%, 20m=0%
    final progress = (1 - (accuracy / 20.0)).clamp(0.0, 1.0);
    final color = _isAccuracyGood ? Colors.green : Colors.orange;

    return Column(
      children: [
        // Bar akurasi
        Stack(
          children: [
            // Background
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Progress
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 300),
              widthFactor: progress,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // Garis target 5m (75% dari total 20m range)
            Positioned(
              left: MediaQuery.of(context).size.width * 0.75 - 60,
              child: Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0m', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Target: ≤5m',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Text('20m+', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusText() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_currentAccuracy == null) {
      statusText = 'Sedang mencari sinyal satelit...';
      statusColor = Colors.grey;
      statusIcon = Icons.satellite_alt;
    } else if (_isAccuracyGood) {
      statusText = '✅ Akurasi tercapai! ${_currentAccuracy!.toStringAsFixed(1)}m';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_currentAccuracy! <= 10) {
      statusText = 'Mendekat... akurasi ${_currentAccuracy!.toStringAsFixed(1)}m';
      statusColor = Colors.orange;
      statusIcon = Icons.trending_down;
    } else {
      statusText = 'Sinyal lemah. Cari area lebih terbuka.';
      statusColor = Colors.red;
      statusIcon = Icons.signal_wifi_off;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  'Tips mendapatkan akurasi terbaik:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTip('Pastikan berada di area terbuka'),
            _buildTip('Hindari berdiri di bawah pohon lebat'),
            _buildTip('Tunggu beberapa detik hingga GPS terkunci'),
            _buildTip("Aktifkan mode lokasi 'Akurasi Tinggi' di HP"),
            _buildTip('Jauhi gedung atau atap logam'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF2E7D32))),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Tombol "Gunakan Koordinat Ini" — hanya aktif jika akurasi bagus
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isAccuracyGood ? _gunakanKoordinat : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('✅ Gunakan Koordinat Ini'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAccuracyGood ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Tombol Batal
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Batal'),
          ),
        ),
      ],
    );
  }
}

/// Custom painter untuk animasi radar GPS
class _RadarPainter extends CustomPainter {
  final double rotation;
  final double? accuracy;
  final bool isGood;
  final Color color;

  _RadarPainter({
    required this.rotation,
    this.accuracy,
    required this.isGood,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Gambar lingkaran-lingkaran akurasi
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 3; i >= 1; i--) {
      circlePaint.color = color.withOpacity(0.2 * i);
      canvas.drawCircle(center, maxRadius * i / 3, circlePaint);
    }

    // Garis silang (crosshair)
    final crossPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(center.dx, center.dy - maxRadius),
        Offset(center.dx, center.dy + maxRadius),
        crossPaint);
    canvas.drawLine(
        Offset(center.dx - maxRadius, center.dy),
        Offset(center.dx + maxRadius, center.dy),
        crossPaint);

    // Garis sweep radar yang berputar
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(0.8), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(maxRadius * math.cos(-0.5), maxRadius * math.sin(-0.5))
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: maxRadius),
        -0.5,
        0.5,
        false,
      )
      ..close();

    canvas.drawPath(path, sweepPaint);
    canvas.restore();

    // Titik tengah
    final centerPaint = Paint()..color = color;
    canvas.drawCircle(center, 6, centerPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.accuracy != accuracy ||
        oldDelegate.isGood != isGood;
  }
}
