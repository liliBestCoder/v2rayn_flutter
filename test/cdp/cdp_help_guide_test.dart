import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/pages/about_page.dart';
import 'package:v2rayn_flutter/pages/help_page.dart';

void main() {
  group('CDP UI Integration Tests - Help Page & Documentation Center', () {
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

      // Enter query 'DoT'
      await tester.enterText(find.byType(TextField), 'DoT');
      await tester.pumpAndSettle();

      expect(find.text('4. DoT (DNS over TLS) 与路由分流策略'), findsOneWidget);
      expect(find.text('1. 快速入门：账号登录与注册'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

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

    testWidgets('AboutPage strictly adheres to Figma prototype without extra help links', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('使用与帮助指南'), findsNothing);
      expect(find.text('隐私保护协议'), findsNothing);
      expect(find.text('关于 Luxwap'), findsOneWidget);
      expect(find.text('版本说明'), findsOneWidget);
      expect(find.text('反馈'), findsOneWidget);
      expect(find.text('发送'), findsOneWidget);
    });
  });
}
