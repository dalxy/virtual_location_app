import 'package:flutter/services.dart';

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
