import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/pages/about_page.dart';
import 'package:v2rayn_flutter/pages/help_page.dart';
import 'package:v2rayn_flutter/pages/main_shell.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/services/api_service.dart';
import 'package:v2rayn_flutter/services/token_store.dart';

class MockTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> loadToken() async => 'test-token';
  @override
  Future<void> saveToken(String token) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HelpPage Widget Tests', () {
    testWidgets('Renders help guide tab and category pills by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelpPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('帮助与文档中心'), findsOneWidget);
      expect(find.text('使用与帮助指南'), findsOneWidget);
      expect(find.text('隐私保护协议'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('入门与连接'), findsOneWidget);
      expect(find.text('线路拥堵色'), findsOneWidget);
      expect(find.text('核心功能(TUN/DoT)'), findsOneWidget);
      expect(find.text('常见问题FAQ'), findsOneWidget);
      expect(find.text('技术支持'), findsOneWidget);

      // Verify sections are visible
      expect(find.text('1. 快速入门：账号登录与注册'), findsOneWidget);
      expect(find.text('2. 线路选择与三色拥堵指标说明'), findsOneWidget);
    });

    testWidgets('Switching to privacy policy tab renders No-Logs banner and content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelpPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Privacy Policy Tab
      await tester.tap(find.text('隐私保护协议'));
      await tester.pumpAndSettle();

      // Verify privacy policy notice
      expect(find.textContaining('无访问日志记录原则（No-Logs Policy）'), findsOneWidget);
      expect(find.textContaining('Luxwap 隐私保护协议'), findsOneWidget);
    });

    testWidgets('Search query filters help sections and clear button works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelpPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search term "DoT"
      await tester.enterText(find.byType(TextField), 'DoT');
      await tester.pumpAndSettle();

      // DoT section should be present, but unrelated sections like "账号登录与注册" should be filtered out
      expect(find.textContaining('DoT (DNS over TLS)'), findsOneWidget);
      expect(find.text('1. 快速入门：账号登录与注册'), findsNothing);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Sections should reappear
      expect(find.text('1. 快速入门：账号登录与注册'), findsOneWidget);
    });

    testWidgets('Category pill filter narrows down sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelpPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "线路拥堵色" pill
      await tester.tap(find.text('线路拥堵色'));
      await tester.pumpAndSettle();

      expect(find.text('2. 线路选择与三色拥堵指标说明'), findsOneWidget);
      expect(find.text('1. 快速入门：账号登录与注册'), findsNothing);
    });

    testWidgets('showHelpDialog opens modal dialog with close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showHelpDialog(ctx),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('帮助与文档中心'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('帮助与文档中心'), findsNothing);
    });

    testWidgets('AboutPage has links to open help guide and privacy policy dialogs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('使用与帮助指南'), findsOneWidget);
      expect(find.text('隐私保护协议'), findsOneWidget);

      // Tap help guide link
      await tester.tap(find.text('使用与帮助指南'));
      await tester.pumpAndSettle();

      expect(find.text('帮助与文档中心'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Tap privacy policy link
      await tester.tap(find.text('隐私保护协议'));
      await tester.pumpAndSettle();

      expect(find.text('帮助与文档中心'), findsOneWidget);
      expect(find.textContaining('无访问日志记录原则'), findsOneWidget);
    });
  });
}
