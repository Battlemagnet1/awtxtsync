import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../models/saved_file.dart';
import '../models/saved_server.dart';
import '../services/client_service.dart';
import '../services/discovery_service.dart';
import '../services/file_store_service.dart';
import '../services/foreground_service.dart';
import '../services/prefs_service.dart';
import '../services/server_service.dart';

enum AppMode { idle, server, client }

class AppState extends ChangeNotifier {
  final ServerService server = ServerService();
  final ClientService client = ClientService();
  final DiscoveryService discovery = DiscoveryService();
  final FileStoreService localStore = FileStoreService();

  AppMode _mode = AppMode.idle;
  String _deviceName = '';
  String _text = '';
  String _status = '未连接';
  Timer? _debounce;

  final List<DiscoveredServer> discovered = [];

  AppState() {
    server.addListener(_syncFromServices);
    client.addListener(_syncFromServices);
    _deviceName = _defaultDeviceName();
  }

  AppMode get mode => _mode;
  String get deviceName => _deviceName;
  String get text => _text;
  String get status => _status;
  bool get isServer => _mode == AppMode.server;
  bool get isClient => _mode == AppMode.client;
  bool get connected => server.running || client.connected;

  List<Device> get devices => isServer ? server.devices : const [];
  List<SavedFile> get files => isServer ? server.files : client.files;
  String? get lastDownloadedName => client.lastDownloadedName;
  String? get lastDownloadedPath => client.lastDownloadedPath;

  String _defaultDeviceName() {
    final suffix = (DateTime.now().millisecondsSinceEpoch % 100000).toString();
    return '设备-$suffix';
  }

  void _syncFromServices() {
    if (isServer) {
      _text = server.authoritativeText;
      _status = server.running
          ? '服务器运行中 · 端口 ${server.port} · ${server.devices.length} 台设备已连接'
          : '未连接';
    } else if (isClient) {
      _text = client.text;
      _status = client.connected
          ? '已连接到服务器'
          : (client.reconnecting ? '连接断开，正在重连…' : '未连接');
    }
    notifyListeners();
  }

  void setDeviceName(String name) {
    _deviceName = name;
    notifyListeners();
  }

  Future<void> startServer(int port) async {
    await server.start(port);
    _mode = AppMode.server;
    await discovery.startAnnouncing(port, _deviceName);
    _syncFromServices();
  }

  Future<void> stopServer() async {
    await discovery.stopAnnouncing();
    await server.stop();
    _mode = AppMode.idle;
    _text = '';
    _status = '未连接';
    notifyListeners();
  }

  Future<void> connectToServer(String ip, int port, {String? serverName}) async {
    await client.connect(ip, port, _deviceName);
    _mode = AppMode.client;
    await discovery.stopListening();
    await _persistAndKeepAlive(ip, port, serverName);
    _syncFromServices();
  }

  Future<void> _persistAndKeepAlive(String ip, int port, String? serverName) async {
    try {
      await PrefsService.addServer(SavedServer(ip, port, serverName ?? ''));
      await PrefsService.saveDeviceName(_deviceName);
    } catch (_) {}
    await ForegroundServiceController.start();
  }

  /// 已保存的服务器列表（连接页展示，点击可快速连接）。
  List<SavedServer> get savedServers => PrefsService.loadServers();

  Future<void> removeSavedServer(SavedServer server) async {
    await PrefsService.removeServer(server.ip, server.port);
    notifyListeners();
  }

  Future<void> disconnect() async {
    await client.disconnect();
    await ForegroundServiceController.stop();
    _mode = AppMode.idle;
    _text = '';
    _status = '未连接';
    notifyListeners();
  }

  void setText(String value) {
    _text = value;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _pushText);
  }

  void _pushText() {
    if (isServer) {
      server.setText(_text);
    } else if (isClient) {
      client.sendText(_text);
    }
  }

  Future<void> saveText(String filename, String content) async {
    _debounce?.cancel();
    _pushText();
    if (isServer) {
      await server.fileStore.saveFile(filename, content);
      await server.refreshFiles();
      _status = '已保存到服务器';
    } else if (isClient) {
      client.saveFile(filename, content);
      _status = '已发送保存请求';
    } else {
      await localStore.saveFile(filename, content);
      _status = '已保存到本地';
    }
    notifyListeners();
  }

  Future<void> listFiles() async {
    if (isServer) {
      await server.refreshFiles();
    } else if (isClient) {
      client.listFiles();
    }
  }

  Future<void> downloadFile(String filename) async {
    if (isClient) {
      client.downloadFile(filename);
    }
  }

  Future<void> openFileToText(String filename) async {
    String content = '';
    if (isServer) {
      content = await server.fileStore.readFile(filename);
    } else if (isClient) {
      content = await client.openFile(filename);
    }
    if (content.isNotEmpty) {
      setText(content);
      _status = '已打开 $filename';
    } else {
      _status = '文件为空或不存在';
    }
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    discovered.clear();
    await discovery.startListening((s) {
      final exists = discovered.any((d) => d.ip == s.ip && d.port == s.port);
      if (!exists) {
        discovered.add(s);
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    await discovery.stopListening();
    discovered.clear();
    notifyListeners();
  }

  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final i in interfaces) {
        for (final a in i.addresses) {
          if (!a.isLoopback && a.address.isNotEmpty) {
            return a.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static String defaultFilename() {
    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${p(now.month)}-${p(now.day)}_${p(now.hour)}-${p(now.minute)}-${p(now.second)}.txt';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    server.removeListener(_syncFromServices);
    client.removeListener(_syncFromServices);
    super.dispose();
  }
}
