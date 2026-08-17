import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import '../models/saved_file.dart';
import 'file_store_service.dart';

class ClientService extends ChangeNotifier {
  final FileStoreService downloadStore = FileStoreService(subDir: 'awtxtsync_downloads');

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  String _text = '';
  List<SavedFile> _files = [];
  String? _lastDownloadedName;
  String? _lastDownloadedPath;
  final Map<String, Completer<String>> _pendingOpens = {};

  bool get connected => _connected;
  String get text => _text;
  List<SavedFile> get files => List.unmodifiable(_files);
  String? get lastDownloadedName => _lastDownloadedName;
  String? get lastDownloadedPath => _lastDownloadedPath;

  Future<void> connect(String ip, int port, String deviceName) async {
    final clientId = 'c${DateTime.now().microsecondsSinceEpoch}';
    final channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port'));
    _channel = channel;
    await channel.ready;
    _connected = true;
    _send(Message('hello', {'clientId': clientId, 'deviceName': deviceName}));
    _sub = channel.stream.listen(_onData, onDone: _disconnect, onError: (_) => _disconnect());
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _disconnect();
  }

  void _disconnect() {
    _connected = false;
    _channel = null;
    _sub = null;
    for (final c in _pendingOpens.values) {
      if (!c.isCompleted) c.complete('');
    }
    _pendingOpens.clear();
    notifyListeners();
  }

  void _onData(dynamic data) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final msg = Message.fromJson(json);
    switch (msg.type) {
      case 'welcome':
        _text = msg.data['text'] as String? ?? '';
        _files = _parseFiles(msg.data['files']);
        notifyListeners();
        break;
      case 'text':
        _text = msg.data['content'] as String? ?? '';
        notifyListeners();
        break;
      case 'file_list':
        _files = _parseFiles(msg.data['files']);
        notifyListeners();
        break;
      case 'file_data':
        _handleFileData(
          msg.data['filename'] as String? ?? '',
          msg.data['content'] as String? ?? '',
        );
        break;
      case 'open_result':
        _pendingOpens.remove(msg.data['filename'] as String? ?? '')
            ?.complete(msg.data['content'] as String? ?? '');
        break;
    }
  }

  List<SavedFile> _parseFiles(dynamic files) {
    return (files as List? ?? [])
        .map((e) => SavedFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _handleFileData(String filename, String content) async {
    await downloadStore.saveFile(filename, content);
    final dir = await downloadStore.directory;
    _lastDownloadedName = filename;
    _lastDownloadedPath = '${dir.path}${Platform.pathSeparator}$filename';
    notifyListeners();
  }

  void sendText(String content) {
    _text = content;
    _send(Message('text', {'content': content}));
    notifyListeners();
  }

  void saveFile(String filename, String content) {
    _send(Message('save', {'filename': filename, 'content': content}));
  }

  void listFiles() {
    _send(Message('list', {}));
  }

  void downloadFile(String filename) {
    _send(Message('download', {'filename': filename}));
  }

  Future<String> openFile(String filename) {
    final c = Completer<String>();
    _pendingOpens[filename] = c;
    _send(Message('open', {'filename': filename}));
    return c.future.timeout(const Duration(seconds: 5), onTimeout: () => '');
  }

  void _send(Message msg) {
    _channel?.sink.add(jsonEncode(msg.toJson()));
  }
}
