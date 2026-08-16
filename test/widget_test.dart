import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:awtxtsync/main.dart';
import 'package:awtxtsync/state/app_state.dart';

void main() {
  testWidgets('App renders main screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const AwTxtSyncApp(),
      ),
    );
    await tester.pump();

    expect(find.text('AWtxtSync'), findsOneWidget);
    expect(find.text('启动服务器'), findsOneWidget);
    expect(find.text('连接设备'), findsOneWidget);
  });
}
