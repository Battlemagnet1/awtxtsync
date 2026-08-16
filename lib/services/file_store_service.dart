import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/saved_file.dart';

class FileStoreService {
  final String subDir;
  Directory? _dir;

  FileStoreService({this.subDir = 'awtxtsync_saved'});

  Future<Directory> get directory async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}$subDir');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  Future<void> saveFile(String filename, String content) async {
    final d = await directory;
    final f = File('${d.path}${Platform.pathSeparator}$filename');
    await f.writeAsString(content, encoding: utf8);
  }

  Future<String> readFile(String filename) async {
    final d = await directory;
    final f = File('${d.path}${Platform.pathSeparator}$filename');
    if (!await f.exists()) return '';
    return f.readAsString(encoding: utf8);
  }

  Future<List<SavedFile>> listFiles() async {
    final d = await directory;
    final list = <SavedFile>[];
    await for (final e in d.list()) {
      if (e is File && e.path.toLowerCase().endsWith('.txt')) {
        final stat = await e.stat();
        final name = e.path.split(RegExp(r'[\\/]')).last;
        list.add(SavedFile(name, stat.size, _formatDate(stat.modified)));
      }
    }
    list.sort((a, b) => b.name.compareTo(a.name));
    return list;
  }

  String _formatDate(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }
}
