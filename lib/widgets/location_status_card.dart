import 'package:flutter/material.dart';

class LocationStatusCard extends StatelessWidget {
  final bool isMocking;
  final double? latitude;
  final double? longitude;

  const LocationStatusCard({
    super.key,
    required this.isMocking,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isMocking
                ? [Colors.teal.shade600, Colors.teal.shade400]
                : [Colors.grey.shade600, Colors.grey.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isMocking ? Icons.location_on : Icons.location_off,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              isMocking ? '正在模拟位置' : '未模拟',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (isMocking && latitude != null && longitude != null) ...[
              const SizedBox(height: 12),
              _buildCoordinateRow('纬度', latitude!),
              const SizedBox(height: 4),
              _buildCoordinateRow('经度', longitude!),
            ],
            if (isMocking) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '本应用调试将使用此位置',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value.toStringAsFixed(6),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
