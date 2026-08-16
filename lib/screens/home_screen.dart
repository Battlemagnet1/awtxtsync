import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/text_panel.dart';
import 'connect_screen.dart';
import 'files_screen.dart';
import 'server_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AWtxtSync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '浏览文件',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FilesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: '设备名称',
            onPressed: () => _editDeviceName(context, state),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusBanner(state: state),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextPanel(text: state.text, onChanged: state.setText),
              ),
            ),
            _ActionBar(state: state),
          ],
        ),
      ),
    );
  }

  void _editDeviceName(BuildContext context, AppState state) async {
    final controller = TextEditingController(text: state.deviceName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设备名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '设备名称', hintText: '用于在其它设备上显示'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      state.setDeviceName(name);
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final AppState state;
  const _StatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    if (state.isServer) {
      bg = Theme.of(context).colorScheme.primaryContainer;
      fg = Theme.of(context).colorScheme.onPrimaryContainer;
      icon = Icons.dns;
    } else if (state.isClient) {
      bg = Theme.of(context).colorScheme.tertiaryContainer;
      fg = Theme.of(context).colorScheme.onTertiaryContainer;
      icon = Icons.cast_connected;
    } else {
      bg = Theme.of(context).colorScheme.surfaceContainerHighest;
      fg = Theme.of(context).colorScheme.onSurfaceVariant;
      icon = Icons.cloud_off;
    }
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.status, style: TextStyle(color: fg, fontWeight: FontWeight.w500)),
                Text('本机设备名：${state.deviceName}',
                    style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final AppState state;
  const _ActionBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final connected = state.connected;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!connected) ...[
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServerScreen()),
              ),
              icon: const Icon(Icons.dns),
              label: const Text('启动服务器'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectScreen()),
              ),
              icon: const Icon(Icons.link),
              label: const Text('连接设备'),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: () => state.isServer ? state.stopServer() : state.disconnect(),
              icon: const Icon(Icons.link_off),
              label: const Text('断开'),
            ),
          FilledButton.tonalIcon(
            onPressed: () => _save(context),
            icon: const Icon(Icons.save),
            label: const Text('保存文字'),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: state.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
            },
            icon: const Icon(Icons.copy),
            tooltip: '复制全部',
          ),
          IconButton(
            onPressed: () => state.setText(''),
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空',
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final state = context.read<AppState>();
    final controller = TextEditingController(text: AppState.defaultFilename());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存文字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '文件名', hintText: '默认「日期+时间」.txt'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await state.saveText(name, state.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.status)));
    }
  }
}
