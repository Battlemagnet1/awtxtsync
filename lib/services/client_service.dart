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

  // 断线重连
  String? _lastIp;
  int? _lastPort;
  String? _deviceName;
  bool _reconnectEnabled = false;
  bool _reconnecting = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // 心跳
  Timer? _heartbeatTimer;
  bool _receivedPong = false;
  DateTime _lastPongAt = DateTime.now();

  bool get connected => _connected;
  bool get reconnecting => _reconnecting;
  String get text => _text;
  List<SavedFile> get files => List.unmodifiable(_files);
  String? get lastDownloadedName => _lastDownloadedName;
  String? get lastDownloadedPath => _lastDownloadedPath;

  Future<void> connect(String ip, int port, String deviceName) async {
    _lastIp = ip;
    _lastPort = port;
    _deviceName = deviceName;
    _reconnectEnabled = true;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    final ip = _lastIp;
    final port = _lastPort;
    if (ip == null || port == null) return;

    final channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port'));
    _channel = channel;
    try {
      await channel.ready;
    } catch (_) {
      _channel = null;
      rethrow;
    }
    _connected = true;
    _reconnecting = false;
    _reconnectAttempts = 0;
    final clientId = 'c${DateTime.now().microsecondsSinceEpoch}';
    _send(Message('hello', {'clientId': clientId, 'deviceName': _deviceName ?? ''}));
    _sub = channel.stream.listen(
      _onData,
      onDone: _onUnexpectedDisconnect,
      onError: (_) => _onUnexpectedDisconnect(),
    );
    _startHeartbeat();
    notifyListeners();
  }

  /// 用户主动断开：不再自动重连。
  Future<void> disconnect() async {
    _reconnectEnabled = false;
    _reconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
    _completePending();
    notifyListeners();
  }

  /// 意外断开（网络中断 / 服务器关闭）：若启用了重连则调度重连。
  void _onUnexpectedDisconnect() {
    _connected = false;
    _channel = null;
    _sub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _completePending();
    if (_reconnectEnabled) {
      _scheduleReconnect();
    }
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnecting = true;
    notifyListeners();
    final delay = _backoffDelay();
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () async {
      try {
        await _doConnect();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  Duration _backoffDelay() {
    const seconds = [2, 4, 8, 16, 30];
    final i = _reconnectAttempts.clamp(0, seconds.length - 1);
    return Duration(seconds: seconds[i]);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _receivedPong = false;
    _lastPongAt = DateTime.now();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_connected) return;
      // 仅当服务器确认支持 pong 后，才用「无 pong 超时」判定半开连接，
      // 避免对旧版（1.0.1）服务器误判断开。
      if (_receivedPong && DateTime.now().difference(_lastPongAt).inSeconds > 90) {
        _channel?.sink.close();
        return;
      }
      _send(Message('ping', {}));
    });
  }

  void _completePending() {
    for (final c in _pendingOpens.values) {
      if (!c.isCompleted) c.complete('');
    }
    _pendingOpens.clear();
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
      case 'pong':
        _receivedPong = true;
        _lastPongAt = DateTime.now();
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
