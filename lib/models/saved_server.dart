/// 已保存的服务器（用于连接页的历史记录，点击即可快速连接）。
class SavedServer {
  final String ip;
  final int port;
  final String name;

  SavedServer(this.ip, this.port, this.name);

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'ip': ip, 'port': port, 'name': name};

  factory SavedServer.fromJson(Map<String, dynamic> json) => SavedServer(
        json['ip'] as String? ?? '',
        json['port'] as int? ?? 7777,
        json['name'] as String? ?? '',
      );
}
