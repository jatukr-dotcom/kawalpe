// =========================================================
// widgets/connectivity_badge.dart - Badge status koneksi internet
// =========================================================
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityBadge extends StatefulWidget {
  const ConnectivityBadge({super.key});

  @override
  State<ConnectivityBadge> createState() => _ConnectivityBadgeState();
}

class _ConnectivityBadgeState extends State<ConnectivityBadge> {
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Dengarkan perubahan koneksi secara realtime
    Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = !results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isOnline
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOnline ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            size: 14,
            color: _isOnline ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _isOnline ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
