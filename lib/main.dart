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
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
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
