import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/location_status_card.dart';
import 'screens/location_picker_screen.dart';
import 'services/location_mock_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '虚拟定位',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double? _selectedLat;
  double? _selectedLng;
  bool _isMocking = false;
  bool _isCheckingPermission = false;

  static const _keyLat = 'last_lat';
  static const _keyLng = 'last_lng';

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
    _checkMockStatus();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    if (lat != null && lng != null) {
      setState(() {
        _selectedLat = lat;
        _selectedLng = lng;
      });
    }
  }

  Future<void> _saveLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
  }

  Future<void> _checkMockStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final isMocking = await LocationMockService.isMocking();
      setState(() => _isMocking = isMocking);
    } catch (_) {}
  }

  Future<void> _openLocationPicker() async {
    final initialLocation = _selectedLat != null && _selectedLng != null
        ? LatLng(_selectedLat!, _selectedLng!)
        : null;

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: initialLocation),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
      });
      await _saveLocation(result.latitude, result.longitude);
    }
  }

  Future<void> _startMock() async {
    if (_selectedLat == null || _selectedLng == null) {
      _showSnackBar('请先选择目标位置', isError: true);
      return;
    }

    // Request notification permission for Android 13+
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    setState(() => _isCheckingPermission = true);
    try {
      await LocationMockService.startMock(_selectedLat!, _selectedLng!);
      setState(() => _isMocking = true);
      _showSnackBar('虚拟定位已启动');
    } on LocationMockException catch (e) {
      setState(() => _isCheckingPermission = false);
      if (e.message.contains('模拟位置信息应用')) {
        _showPermissionGuideDialog();
      } else {
        _showSnackBar(e.message, isError: true);
      }
    } catch (e) {
      setState(() => _isCheckingPermission = false);
      _showSnackBar('启动失败: $e', isError: true);
    }
    setState(() => _isCheckingPermission = false);
  }

  Future<void> _stopMock() async {
    try {
      await LocationMockService.stopMock();
      setState(() => _isMocking = false);
      _showSnackBar('虚拟定位已停止');
    } on LocationMockException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      _showSnackBar('停止失败: $e', isError: true);
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isCheckingPermission = true);
    try {
      final status = await LocationMockService.checkMockPermission();
      if (!mounted) return;

      if (status.isReady) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('权限已就绪'),
              ],
            ),
            content: const Text('模拟定位权限已配置正确，可以开始使用。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      } else {
        _showPermissionGuideDialog();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('检查失败: $e', isError: true);
      }
    }
    setState(() => _isCheckingPermission = false);
  }

  void _showPermissionGuideDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('需要开启模拟定位权限'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请按以下步骤操作：'),
              SizedBox(height: 12),
              Text('1. 打开手机 设置'),
              Text('2. 进入 关于手机'),
              Text('3. 连续点击「版本号」7次，开启开发者模式'),
              Text('4. 返回设置，进入 系统 → 开发者选项'),
              Text('5. 找到「选择模拟位置信息应用」'),
              Text('6. 选择「虚拟定位」'),
              SizedBox(height: 12),
              Text(
                '完成后返回本应用即可',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermission();
            },
            child: const Text('已完成设置'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后设置'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String get _locationLabel {
    if (_selectedLat == null || _selectedLng == null) {
      return '尚未选择';
    }
    return '${_selectedLat!.toStringAsFixed(6)}, ${_selectedLng!.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('虚拟定位'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            LocationStatusCard(
              isMocking: _isMocking,
              latitude: _selectedLat,
              longitude: _selectedLng,
            ),

            const SizedBox(height: 20),

            // Selected location info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, color: Colors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '目标位置',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _locationLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Select location button
            ElevatedButton.icon(
              onPressed: _isMocking ? null : _openLocationPicker,
              icon: const Icon(Icons.map),
              label: const Text('选择位置'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Start/Stop mock button
            ElevatedButton.icon(
              onPressed:
                  _isMocking ? _stopMock : (_isCheckingPermission ? null : _startMock),
              icon: Icon(_isMocking ? Icons.stop : Icons.play_arrow),
              label: Text(_isMocking ? '停止模拟' : '开始模拟'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMocking ? Colors.red : Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Check permission button
            OutlinedButton.icon(
              onPressed: _isCheckingPermission ? null : _checkPermission,
              icon: _isCheckingPermission
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.security),
              label: const Text('检查模拟权限'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Platform warning
            if (!isAndroid) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '模拟定位仅支持 Android 平台',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
