import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 前台服务的任务处理器（空转，不跑业务）。
///
/// 前台服务的职责仅是：提升进程为前台优先级 + 常驻通知 + 保持 WakeLock，
/// 真正的 WebSocket 连接仍由主 isolate 的 ClientService 持有。
class SyncTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// 必须为顶层函数，供前台服务在独立 isolate 中定位任务处理器。
@pragma('vm:entry-point')
void syncTaskCallback() {
  FlutterForegroundTask.setTaskHandler(SyncTaskHandler());
}

/// 封装 flutter_foreground_task，仅 Android 生效（Windows 上为 no-op）。
class ForegroundServiceController {
  static bool _initialized = false;

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'awtxtsync_sync',
        channelName: 'AWtxtSync 同步',
        channelDescription: '保持与服务器连接时显示的常驻通知',
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
    _initialized = true;
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.requestNotificationPermission();
    } catch (_) {}
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: 'AWtxtSync 正在同步',
        notificationText: '保持与服务器的连接',
        callback: syncTaskCallback,
      );
    } catch (_) {
      // 前台服务启动失败（如权限不足）不阻断连接本身
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
