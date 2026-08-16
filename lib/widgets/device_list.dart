import 'package:flutter/material.dart';

import '../models/device.dart';

class DeviceList extends StatelessWidget {
  final List<Device> devices;

  const DeviceList({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('暂无设备连接', style: TextStyle(color: Colors.grey))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final d = devices[index];
        return ListTile(
          leading: const Icon(Icons.devices),
          title: Text(d.name),
          subtitle: Text('ID: ${d.id}'),
          trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        );
      },
    );
  }
}
