import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../models/message.dart';
import '../models/saved_file.dart';
import 'file_store_service.dart';

class ServerService extends ChangeNotifier {
  final FileStoreService fileStore = FileStoreService();

  HttpServer? _httpServer;
  final Map<String, WebSocket> _clients = {};
  final Map<WebSocket, String> _socketToId = {};
  final List<Device> _devices = [];
  String _authoritativeText = '';
  List<SavedFile> _files = [];
  bool _running = false;
  int _port = 7777;

  bool get running => _running;
  int get port => _port;
  List<Device> get devices => List.unmodifiable(_devices);
  String get authoritativeText => _authoritativeText;
  List<SavedFile> get files => List.unmodifiable(_files);

  Future<void> start(int port) async {
    if (_running) return;
    _port = port;
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _running = true;
    _httpServer!.listen(_onRequest);
    await _refreshFiles();
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    for (final s in _clients.values) {
      await s.close();
    }
    _clients.clear();
    _socketToId.clear();
    _devices.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
    _authoritativeText = '';
    notifyListeners();
  }

  /// 服务器自身文本框输入
  void setText(String content) {
    _authoritativeText = content;
    _broadcast(Message('text', {'content': content, 'from': 'server'}));
    notifyListeners();
  }

  Future<void> refreshFiles() async {
    await _refreshFiles();
    notifyListeners();
  }

  void _onRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(_handleConnection);
    } else {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.close();
    }
  }

  void _handleConnection(WebSocket socket) {
    socket.listen(
      (data) => _onMessage(socket, data),
      onDone: () {
        final id = _socketToId.remove(socket);
        if (id != null) {
          _clients.remove(id);
          _devices.removeWhere((d) => d.id == id);
          notifyListeners();
        }
      },
      onError: (_) {},
    );
  }

  void _onMessage(WebSocket socket, dynamic data) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final msg = Message.fromJson(json);
    switch (msg.type) {
      case 'hello':
        final id = msg.data['clientId'] as String? ?? '';
        if (id.isEmpty) return;
        _socketToId[socket] = id;
        _clients[id] = socket;
        _devices.removeWhere((d) => d.id == id);
        _devices.add(Device(id, msg.data['deviceName'] as String? ?? '未知设备'));
        _welcome(socket);
        notifyListeners();
        break;
      case 'text':
        _authoritativeText = msg.data['content'] as String? ?? '';
        _broadcast(
          Message('text', {'content': _authoritativeText, 'from': _socketToId[socket]}),
          except: _socketToId[socket],
        );
        notifyListeners();
        break;
      case 'save':
        _handleSave(
          socket,
          msg.data['filename'] as String? ?? '',
          msg.data['content'] as String? ?? '',
        );
        break;
      case 'list':
        _handleList(socket);
        break;
      case 'download':
        _handleDownload(socket, msg.data['filename'] as String? ?? '');
        break;
    }
  }

  Future<void> _welcome(WebSocket socket) async {
    final files = await fileStore.listFiles();
    _sendTo(socket, Message('welcome', {
      'text': _authoritativeText,
      'files': files.map((f) => f.toJson()).toList(),
    }));
  }

  Future<void> _handleSave(WebSocket socket, String filename, String content) async {
    await fileStore.saveFile(filename, content);
    await _refreshFiles();
    _sendTo(socket, Message('file_list', {'files': _files.map((f) => f.toJson()).toList()}));
    notifyListeners();
  }

  Future<void> _handleList(WebSocket socket) async {
    await _refreshFiles();
    _sendTo(socket, Message('file_list', {'files': _files.map((f) => f.toJson()).toList()}));
  }

  Future<void> _handleDownload(WebSocket socket, String filename) async {
    final content = await fileStore.readFile(filename);
    _sendTo(socket, Message('file_data', {'filename': filename, 'content': content}));
  }

  Future<void> _refreshFiles() async {
    _files = await fileStore.listFiles();
  }

  void _broadcast(Message msg, {String? except}) {
    final encoded = jsonEncode(msg.toJson());
    _clients.forEach((id, socket) {
      if (id != except) socket.add(encoded);
    });
  }

  void _sendTo(WebSocket socket, Message msg) {
    socket.add(jsonEncode(msg.toJson()));
  }
}
