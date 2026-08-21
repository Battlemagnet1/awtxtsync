import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/foreground_service.dart';
import 'services/prefs_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.init();
  if (Platform.isAndroid) {
    await ForegroundServiceController.init();
  }
  final appState = AppState();
  // 启动即尝试自动连接上次的服务器（失败静默，保持 idle 首页）
  appState.autoConnect();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const AwTxtSyncApp(),
    ),
  );
}

class AwTxtSyncApp extends StatelessWidget {
  const AwTxtSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AWtxtSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF534AB7),
      ),
      home: const HomeScreen(),
    );
  }
}
