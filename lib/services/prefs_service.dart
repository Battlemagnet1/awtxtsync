import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化：记住上次连接的服务器与设备名称。
class PrefsService {
  static const _kIp = 'last_server_ip';
  static const _kPort = 'last_server_port';
  static const _kDeviceName = 'device_name';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveConnection(String ip, int port) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(_kIp, ip);
    await p.setInt(_kPort, port);
  }

  static Future<void> clearConnection() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.remove(_kIp);
    await p.remove(_kPort);
  }

  static ({String ip, int port})? loadConnection() {
    final p = _prefs;
    if (p == null) return null;
    final ip = p.getString(_kIp);
    final port = p.getInt(_kPort);
    if (ip == null || ip.isEmpty || port == null) return null;
    return (ip: ip, port: port);
  }

  static Future<void> saveDeviceName(String name) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString(_kDeviceName, name);
  }

  static String? loadDeviceName() {
    return _prefs?.getString(_kDeviceName);
  }
}
