import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_server.dart';

/// 本地持久化：保存连接过的服务器列表 + 设备名称。
class PrefsService {
  static const _kServers = 'saved_servers';
  static const _kDeviceName = 'device_name';
  static const int _maxServers = 20;

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 读取已保存的服务器列表（最新连接的在前）。
  static List<SavedServer> loadServers() {
    final raw = _prefs?.getString(_kServers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SavedServer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 新增（或置顶）一个服务器，去重，最多保留 [_maxServers] 个。
  static Future<void> addServer(SavedServer server) async {
    final list = loadServers();
    list.removeWhere((e) => e.ip == server.ip && e.port == server.port);
    list.insert(0, server);
    if (list.length > _maxServers) {
      list.removeRange(_maxServers, list.length);
    }
    await _saveServers(list);
  }

  static Future<void> removeServer(String ip, int port) async {
    final list = loadServers();
    list.removeWhere((e) => e.ip == ip && e.port == port);
    await _saveServers(list);
  }

  static Future<void> _saveServers(List<SavedServer> list) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _kServers,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> saveDeviceName(String name) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(_kDeviceName, name);
  }

  static String? loadDeviceName() {
    return _prefs?.getString(_kDeviceName);
  }
}
