class Device {
  final String id;
  final String name;

  const Device(this.id, this.name);

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        json['clientId'] as String? ?? '',
        json['deviceName'] as String? ?? '未知设备',
      );
}
