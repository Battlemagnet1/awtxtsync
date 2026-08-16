import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/app_state.dart';
import '../widgets/device_list.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  String _ip = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final state = context.read<AppState>();
    await state.startServer(7777);
    final ip = await state.getLocalIp();
    if (mounted) setState(() => _ip = ip);
  }

  Future<void> _stop() async {
    await context.read<AppState>().stopServer();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final port = state.server.port;
    return Scaffold(
      appBar: AppBar(title: const Text('服务器模式')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '本机地址：$_ip:$port',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text('设备名：${state.deviceName}',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    if (_ip.isNotEmpty)
                      QrImageView(
                        data: 'awtxtsync://$_ip:$port',
                        version: QrVersions.auto,
                        size: 180,
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      '客户端可自动发现，或手动输入上方地址连接',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('已连接设备', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Card(child: DeviceList(devices: state.devices)),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _stop,
              child: const Text('停止服务器并返回'),
            ),
          ],
        ),
      ),
    );
  }
}
