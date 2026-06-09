import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/history_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _accuracy = 5.0;
  int _updateInterval = 1000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accuracy = prefs.getDouble('mock_accuracy') ?? 5.0;
      _updateInterval = prefs.getInt('mock_interval') ?? 1000;
    });
  }

  Future<void> _saveAccuracy(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('mock_accuracy', v);
  }

  Future<void> _saveInterval(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mock_interval', v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Accuracy setting
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模拟精度: ${_accuracy.toStringAsFixed(0)} 米',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text('较低的精度看起来更真实，但可能影响定位效果',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Slider(
                    value: _accuracy,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: '${_accuracy.toStringAsFixed(0)}m',
                    onChanged: (v) {
                      setState(() => _accuracy = v);
                      _saveAccuracy(v);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Update interval
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('更新间隔: ${_updateInterval}ms',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text('更短的间隔更不容易被检测，但耗电更多',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 500, label: Text('500ms')),
                      ButtonSegment(value: 1000, label: Text('1s')),
                      ButtonSegment(value: 2000, label: Text('2s')),
                    ],
                    selected: {_updateInterval},
                    onSelectionChanged: (v) {
                      setState(() => _updateInterval = v.first);
                      _saveInterval(v.first);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Clear history
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('清空历史记录'),
              subtitle: const Text('删除所有保存的位置记录'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('确认清空'),
                    content: const Text('确定要删除所有历史记录吗？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('确定', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await HistoryService.clearAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('历史记录已清空')),
                    );
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 12),

          // About
          Card(
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('关于'),
              subtitle: Text('虚拟定位 v1.0.0\n基于 Android 调试 API + 百度地图'),
            ),
          ),
        ],
      ),
    );
  }
}
