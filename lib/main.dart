import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/location_status_card.dart';
import 'screens/location_picker_screen.dart';
import 'screens/settings_screen.dart';
import 'services/location_mock_service.dart';
import 'services/history_service.dart';

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
  List<LocationRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
    _checkMockStatus();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await HistoryService.getHistory();
    if (mounted) setState(() => _history = list);
  }

  Future<void> _loadSavedLocation() async {
    final list = await HistoryService.getHistory();
    if (list.isNotEmpty && mounted) {
      setState(() {
        _selectedLat = list.first.lat;
        _selectedLng = list.first.lng;
      });
    }
  }

  Future<void> _saveLocation(double lat, double lng) async {
    await HistoryService.addRecord(lat, lng);
    _loadHistory();
  }

  Future<void> _checkMockStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final isMocking = await LocationMockService.isMocking();
      if (mounted) setState(() => _isMocking = isMocking);
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

    if (result != null && mounted) {
      setState(() {
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
      });
      await _saveLocation(result.latitude, result.longitude);
    }
  }

  Future<void> _selectHistory(LocationRecord record) async {
    Navigator.pop(context); // close drawer

    // Open map picker centered on the history location
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: record.latLng),
      ),
    );

    if (result != null && mounted) {
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

    if (Platform.isAndroid) {
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        final requested = await Permission.location.request();
        if (!requested.isGranted) {
          _showSnackBar('需要位置信息权限后才能启动调试定位', isError: true);
          return;
        }
      }

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
      if (e.message.contains('模拟位置信息应用')) {
        _showPermissionGuideDialog();
      } else {
        _showSnackBar(e.message, isError: true);
      }
    } catch (e) {
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
            title: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8),
              Text('权限已就绪'),
            ]),
            content: const Text('模拟定位权限已配置正确，可以开始使用。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
            ],
          ),
        );
      } else {
        _showPermissionGuideDialog();
      }
    } catch (e) {
      if (mounted) _showSnackBar('检查失败: $e', isError: true);
    }
    setState(() => _isCheckingPermission = false);
  }

  void _showPermissionGuideDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('需要开启模拟定位权限'),
        content: const SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('请按以下步骤操作：'), SizedBox(height: 12),
            Text('1. 打开手机 设置'),
            Text('2. 进入 关于手机'),
            Text('3. 连续点击「版本号」7次，开启开发者模式'),
            Text('4. 返回设置，进入 系统 → 开发者选项'),
            Text('5. 找到「选择模拟位置信息应用」'),
            Text('6. 选择「虚拟定位」'),
            SizedBox(height: 12),
            Text('完成后返回本应用即可', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _checkPermission(); }, child: const Text('已完成设置')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('稍后设置')),
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
    if (_selectedLat == null || _selectedLng == null) return '尚未选择';
    return '${_selectedLat!.toStringAsFixed(6)}, ${_selectedLng!.toStringAsFixed(6)}';
  }

  // ─── Drawer ───
  Drawer _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal.shade700),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.location_on, size: 40, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text('虚拟定位',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(_isMocking ? '模拟运行中' : '未启动',
                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
          ),

          // History section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('历史记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                const Spacer(),
                if (_history.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      await HistoryService.clearAll();
                      _loadHistory();
                    },
                    child: const Text('清空', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
              ],
            ),
          ),

          // History list
          Expanded(
            child: _history.isEmpty
                ? const Center(
                    child: Text('暂无历史记录', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _history.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = _history[index];
                      final isSelected = _selectedLat != null &&
                          _selectedLng != null &&
                          (_selectedLat! - record.lat).abs() < 0.000001 &&
                          (_selectedLng! - record.lng).abs() < 0.000001;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isSelected ? Icons.location_on : Icons.location_on_outlined,
                          color: isSelected ? Colors.teal : Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          '${record.lat.toStringAsFixed(6)}, ${record.lng.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: isSelected ? Colors.teal : null,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          _formatTime(record.time),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          onPressed: () async {
                            await HistoryService.removeRecord(index);
                            _loadHistory();
                          },
                        ),
                        onTap: () => _selectHistory(record),
                      );
                    },
                  ),
          ),

          // Bottom: Settings
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              Navigator.pop(context); // close drawer
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('虚拟定位'),
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocationStatusCard(
              isMocking: _isMocking,
              latitude: _selectedLat,
              longitude: _selectedLng,
            ),
            const SizedBox(height: 20),

            // Selected location
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
                          const Text('目标位置', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_locationLabel,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Select location
            ElevatedButton.icon(
              onPressed: _isMocking ? null : _openLocationPicker,
              icon: const Icon(Icons.map),
              label: const Text('选择位置'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // Start/Stop
            ElevatedButton.icon(
              onPressed: _isMocking ? _stopMock : (_isCheckingPermission ? null : _startMock),
              icon: Icon(_isMocking ? Icons.stop : Icons.play_arrow),
              label: Text(_isMocking ? '停止模拟' : '开始模拟'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMocking ? Colors.red : Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // Check permission
            OutlinedButton.icon(
              onPressed: _isCheckingPermission ? null : _checkPermission,
              icon: _isCheckingPermission
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.security),
              label: const Text('检查模拟权限'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

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
                    Expanded(child: Text('模拟定位仅支持 Android 平台', style: TextStyle(color: Colors.orange))),
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
