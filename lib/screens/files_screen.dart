import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().listFiles();
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final files = state.files;
    return Scaffold(
      appBar: AppBar(
        title: const Text('已保存文件'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => state.listFiles(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.lastDownloadedPath != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                '已下载：${state.lastDownloadedPath}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: files.isEmpty
                ? const Center(
                    child: Text('暂无已保存的文件', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final f = files[index];
                      return ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(f.name),
                        subtitle: Text('${_formatSize(f.size)} · ${f.date}'),
                        trailing: state.isClient
                            ? IconButton(
                                icon: const Icon(Icons.download),
                                tooltip: '同步下载',
                                onPressed: () {
                                  state.downloadFile(f.name);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('开始下载 ${f.name}…')),
                                  );
                                },
                              )
                            : const Icon(Icons.check, color: Colors.grey),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
