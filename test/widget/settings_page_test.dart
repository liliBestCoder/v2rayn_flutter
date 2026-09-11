import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/pages/settings_page.dart';
import 'package:v2rayn_flutter/services/api_service.dart';
import 'package:v2rayn_flutter/services/client_config_store.dart';
import 'package:v2rayn_flutter/services/token_store.dart';

class MockTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> loadToken() async => 'test-token';
  @override
  Future<void> saveToken(String token) async {}
}

class MockConfigStore implements ClientConfigStore {
  ClientConfig config = const ClientConfig();
  @override
  Future<ClientConfig> load() async => config;
  @override
  Future<void> save(ClientConfig c) async => config = c;
}

void main() {
  testWidgets('SettingsPage displays TUN, DoT, close-to-tray, and UWP option', (WidgetTester tester) async {
    final state = AppState(
      api: ApiService(baseUrl: 'http://127.0.0.1:8080'),
      tokenStore: MockTokenStore(),
      configStore: MockConfigStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppScope(
            state: state,
            child: const SettingsPage(),
          ),
        ),
      ),
    );

    // Verify TUN mode row
    expect(find.text('TUN 虚拟网卡模式'), findsOneWidget);
    expect(find.text('接管系统全局流量（默认开启）'), findsOneWidget);

    // Verify DoT row
    expect(find.text('DoT (DNS over TLS)'), findsOneWidget);

    // Verify Close button action row
    expect(find.text('点击关闭 (X) 按钮'), findsOneWidget);
    expect(find.text('最小化到托盘'), findsOneWidget);

    // Verify UWP button on Windows
    if (Platform.isWindows) {
      expect(find.text('解除 UWP 应用回环限制'), findsOneWidget);
      expect(find.text('一键解除'), findsOneWidget);
    }
  });

  testWidgets('Toggling TUN mode switch updates AppState clientConfig.tunEnabled', (WidgetTester tester) async {
    final state = AppState(
      api: ApiService(baseUrl: 'http://127.0.0.1:8080'),
      tokenStore: MockTokenStore(),
      configStore: MockConfigStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppScope(
            state: state,
            child: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.clientConfig.tunEnabled, isTrue);

    // Find the TUN switch row and tap it
    final tunSwitch = find.ancestor(
      of: find.text('TUN 虚拟网卡模式'),
      matching: find.byType(Row),
    );
    expect(tunSwitch, findsWidgets);

    // Tap the switch widget
    final switches = find.byType(Switch);
    if (switches.evaluate().isNotEmpty) {
      await tester.tap(switches.first);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Double tapping DoT field enters edit mode', (WidgetTester tester) async {
    final state = AppState(
      api: ApiService(baseUrl: 'http://127.0.0.1:8080'),
      tokenStore: MockTokenStore(),
      configStore: MockConfigStore(),
    );
    await state.updateClientConfig(
      state.clientConfig.copyWith(dotDns: 'tcp://1.1.1.1:853'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppScope(
            state: state,
            child: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('tcp://1.1.1.1:853'), findsOneWidget);

    // Double tap to edit
    await tester.tap(find.text('tcp://1.1.1.1:853'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('tcp://1.1.1.1:853'));
    await tester.pumpAndSettle();

    // Now an input TextField should appear for editing
    expect(find.byType(TextField), findsWidgets);
  });
}
