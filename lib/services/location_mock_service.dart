import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationMockService {
  static const _channel =
      MethodChannel('com.example.virtual_location_app/location_mock');

  /// Start mocking at the given coordinates. Returns true if successful.
  static Future<bool> startMock(double latitude, double longitude) async {
    try {
      final result = await _channel.invokeMethod('startMock', {
        'latitude': latitude,
        'longitude': longitude,
      });
      return result == true;
    } on PlatformException catch (e) {
      throw LocationMockException(e.message ?? 'Failed to start mock');
    } on MissingPluginException {
      throw LocationMockException('Mock location not supported on this platform');
    }
  }

  /// Stop mocking. Returns true if successful.
  static Future<bool> stopMock() async {
    try {
      final result = await _channel.invokeMethod('stopMock');
      return result == true;
    } on PlatformException catch (e) {
      throw LocationMockException(e.message ?? 'Failed to stop mock');
    } on MissingPluginException {
      throw LocationMockException('Mock location not supported on this platform');
    }
  }

  /// Check if currently mocking.
  static Future<bool> isMocking() async {
    try {
      final result = await _channel.invokeMethod('isMocking');
      return result == true;
    } on MissingPluginException {
      return false;
    }
  }

  /// Returns the active mock location if the app is currently mocking.
  static Future<MockLocationData?> getActiveMockLocation() async {
    try {
      final result = await _channel.invokeMethod('getActiveMockLocation');
      if (result == null) return null;
      final map = Map<String, dynamic>.from(result as Map);
      final latitude = (map['latitude'] as num?)?.toDouble();
      final longitude = (map['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) return null;
      return MockLocationData(latitude: latitude, longitude: longitude);
    } on MissingPluginException {
      return null;
    }
  }

  /// Returns the app's effective location, preferring the active mock location.
  static Future<Position> getEffectiveCurrentPosition() async {
    final activeMock = await getActiveMockLocation();
    if (activeMock != null) {
      return Position(
        longitude: activeMock.longitude,
        latitude: activeMock.latitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Check the mock location permission status.
  static Future<MockPermissionStatus> checkMockPermission() async {
    try {
      final result = await _channel.invokeMethod('checkMockPermission');
      final map = Map<String, dynamic>.from(result as Map);
      return MockPermissionStatus(
        isMockEnabled: map['isMockLocationGloballyEnabled'] == true,
        isAppSelected: map['isAppDesignatedAsMockApp'] == true,
        message: map['message'] as String? ?? '',
      );
    } on MissingPluginException {
      return const MockPermissionStatus(
        isMockEnabled: false,
        isAppSelected: false,
        message: '模拟定位仅支持 Android 平台',
      );
    }
  }
}

class MockLocationData {
  final double latitude;
  final double longitude;

  const MockLocationData({
    required this.latitude,
    required this.longitude,
  });
}

class MockPermissionStatus {
  final bool isMockEnabled;
  final bool isAppSelected;
  final String message;

  const MockPermissionStatus({
    required this.isMockEnabled,
    required this.isAppSelected,
    required this.message,
  });

  bool get isReady => isMockEnabled && isAppSelected;
}

class LocationMockException implements Exception {
  final String message;
  const LocationMockException(this.message);

  @override
  String toString() => message;
}
