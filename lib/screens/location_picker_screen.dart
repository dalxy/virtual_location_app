import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_mock_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng _picked = const LatLng(39.9042, 116.4074);
  MethodChannel? _channel;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.initialLocation != null) {
      _picked = widget.initialLocation!;
    } else {
      try {
        final ok = await Geolocator.isLocationServiceEnabled();
        if (ok) {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm != LocationPermission.deniedForever) {
            final pos = await LocationMockService.getEffectiveCurrentPosition();
            _picked = LatLng(pos.latitude, pos.longitude);
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _ready = true);
  }

  void _onPlatformCreated(int id) {
    _channel = MethodChannel('baidu_map_$id');
    _channel?.setMethodCallHandler(_onMethodCall);
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMapClick':
        final lat = call.arguments['latitude'] as double?;
        final lng = call.arguments['longitude'] as double?;
        if (lat != null && lng != null) {
          setState(() => _picked = LatLng(lat, lng));
        }
        break;
      case 'onMapMoveEnd':
        final lat2 = call.arguments['latitude'] as double?;
        final lng2 = call.arguments['longitude'] as double?;
        if (lat2 != null && lng2 != null) {
          setState(() => _picked = LatLng(lat2, lng2));
        }
        break;
      case 'onMapReady':
        // Map is loaded
        break;
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final pos = await LocationMockService.getEffectiveCurrentPosition();
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = loc);
      _channel?.invokeMethod('setCenter', {
        'latitude': loc.latitude,
        'longitude': loc.longitude,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取当前位置')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('选择位置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择位置'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _picked),
            child: const Text('确定',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Native Baidu Map via AndroidView
          Positioned.fill(
            child: AndroidView(
              viewType: 'baidu_map',
              creationParams: {
                'latitude': _picked.latitude,
                'longitude': _picked.longitude,
              },
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformCreated,
            ),
          ),

          // Crosshair overlay (stationary at center)
          const IgnorePointer(
            child: Center(
              child: Icon(Icons.location_on, size: 44, color: Colors.red),
            ),
          ),

          // Coordinate display at top
          Positioned(
            top: 12, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _coordLabel('纬度', _picked.latitude),
                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                  _coordLabel('经度', _picked.longitude),
                ],
              ),
            ),
          ),

          // Current location button
          Positioned(
            right: 16, bottom: 160,
            child: FloatingActionButton.small(
              heroTag: 'loc',
              onPressed: _goToCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.teal),
            ),
          ),

          // Bottom confirm
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _picked),
                  icon: const Icon(Icons.check),
                  label: const Text('确  定', style: TextStyle(fontSize: 17)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordLabel(String label, double value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(7),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
