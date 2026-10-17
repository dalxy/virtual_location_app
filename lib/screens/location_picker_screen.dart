import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_mock_service.dart';
import '../services/search_service.dart';

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

  // Search state
  bool _showSearch = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<PlaceResult> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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

  // ── Search ──

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _results = [];
        _searchFocus.unfocus();
      } else {
        // Delay focus to let the text field build
        Future.delayed(const Duration(milliseconds: 100), () {
          _searchFocus.requestFocus();
        });
      }
    });
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await SearchService.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  void _selectResult(PlaceResult place) {
    setState(() {
      _picked = LatLng(place.lat, place.lng);
      _showSearch = false;
      _searchController.clear();
      _results = [];
    });
    _channel?.invokeMethod('setCenter', {
      'latitude': place.lat,
      'longitude': place.lng,
    });
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
          // Search button
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: '搜索位置',
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _picked),
            child: const Text('确定',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Native Baidu Map
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

          // Crosshair
          if (!_showSearch)
            const IgnorePointer(
              child: Center(
                child: Icon(Icons.location_on, size: 44, color: Colors.red),
              ),
            ),

          // Search panel
          if (_showSearch) _buildSearchPanel(),

          // Coordinate display (hidden when search is open)
          if (!_showSearch)
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
          if (!_showSearch)
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
          if (!_showSearch)
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

  Widget _buildSearchPanel() {
    return Positioned(
      top: 0, left: 0, right: 0, bottom: 0,
      child: Column(
        children: [
          // Search input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索地点，如"天安门"、"星巴克"...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _doSearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: _doSearch,
                onSubmitted: _doSearch,
              ),
            ),
          ),

          // Results or empty state
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(
                        child: Text('未找到结果', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final place = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.red, size: 22),
                            title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(place.address, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Text(
                              '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                            ),
                            onTap: () => _selectResult(place),
                          );
                        },
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
