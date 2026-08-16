import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '7777');
  final _nameController = TextEditingController();
  bool _connecting = false;
  AppState? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state = context.read<AppState>();
      _nameController.text = _state!.deviceName;
      _state!.startDiscovery();
    });
  }

  @override
  void dispose() {
    _state?.stopDiscovery();
    _ipController.dispose();
    _portController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _connect(String ip, int port) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final state = context.read<AppState>();
    if (_nameController.text.trim().isNotEmpty) {
      state.setDeviceName(_nameController.text.trim());
    }
    try {
      await state.connectToServer(ip, port);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('连接设备')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '本机设备名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('自动发现的设备', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (state.discovered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('正在搜索局域网内的服务器…\n（也可在下方手动输入地址）',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...state.discovered.map((s) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.dns),
                    title: Text(s.name),
                    subtitle: Text('${s.ip}:${s.port}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _connect(s.ip, s.port),
                  ),
                )),
          const SizedBox(height: 24),
          const Text('手动输入地址', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '服务器 IP',
                    hintText: '例如 192.168.1.100',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '端口',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _connecting
                ? null
                : () {
                    final ip = _ipController.text.trim();
                    final port = int.tryParse(_portController.text.trim()) ?? 7777;
                    if (ip.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入服务器 IP')),
                      );
                      return;
                    }
                    _connect(ip, port);
                  },
            icon: const Icon(Icons.link),
            label: Text(_connecting ? '连接中…' : '连接'),
          ),
        ],
      ),
    );
  }
}
