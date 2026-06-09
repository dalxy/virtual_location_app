import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationRecord {
  final double lat;
  final double lng;
  final DateTime time;

  const LocationRecord({
    required this.lat,
    required this.lng,
    required this.time,
  });

  LatLng get latLng => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'time': time.toIso8601String(),
      };

  factory LocationRecord.fromJson(Map<String, dynamic> json) => LocationRecord(
        lat: json['lat'] as double,
        lng: json['lng'] as double,
        time: DateTime.parse(json['time'] as String),
      );
}

class HistoryService {
  static const _key = 'location_history';

  static Future<List<LocationRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => LocationRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addRecord(double lat, double lng) async {
    final list = await getHistory();
    // Remove duplicate if exists, then insert at front
    list.removeWhere((r) =>
        (r.lat - lat).abs() < 0.000001 && (r.lng - lng).abs() < 0.000001);
    list.insert(
        0, LocationRecord(lat: lat, lng: lng, time: DateTime.now()));
    // Keep max 20 records
    if (list.length > 20) list.removeRange(20, list.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((r) => r.toJson()).toList()));
  }

  static Future<void> removeRecord(int index) async {
    final list = await getHistory();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(list.map((r) => r.toJson()).toList()));
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
