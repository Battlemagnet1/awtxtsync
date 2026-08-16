import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredServer {
  final String ip;
  final int port;
  final String name;

  const DiscoveredServer(this.ip, this.port, this.name);
}

class DiscoveryService {
  static const int discoveryPort = 7778;
  static const String appTag = 'AWtxtSync';

  RawDatagramSocket? _announceSocket;
  Timer? _announceTimer;
  RawDatagramSocket? _listenSocket;
  bool _listening = false;

  /// 服务器端：周期性向局域网广播自己的 IP:端口
  Future<void> startAnnouncing(int serverPort, String deviceName) async {
    await stopAnnouncing();
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    s.broadcastEnabled = true;
    _announceSocket = s;
    final payload = utf8.encode(jsonEncode(<String, dynamic>{
      'app': appTag,
      'port': serverPort,
      'name': deviceName,
    }));
    _announceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      try {
        s.send(payload, InternetAddress('255.255.255.255'), discoveryPort);
      } catch (_) {}
    });
  }

  Future<void> stopAnnouncing() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    _announceSocket?.close();
    _announceSocket = null;
  }

  /// 客户端：监听广播，发现局域网内的服务器
  Future<void> startListening(void Function(DiscoveredServer) onFound) async {
    if (_listening) return;
    final s = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    s.broadcastEnabled = true;
    _listenSocket = s;
    _listening = true;
    s.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = s.receive();
      if (dg == null) return;
      try {
        final json = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
        if (json['app'] == appTag) {
          onFound(DiscoveredServer(
            dg.address.address,
            json['port'] as int,
            json['name'] as String,
          ));
        }
      } catch (_) {}
    });
  }

  Future<void> stopListening() async {
    _listening = false;
    _listenSocket?.close();
    _listenSocket = null;
  }
}
