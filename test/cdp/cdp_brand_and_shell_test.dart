import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/pages/activity_page.dart';
import 'package:v2rayn_flutter/pages/lines_page.dart';
import 'package:v2rayn_flutter/pages/login_page.dart';
import 'package:v2rayn_flutter/pages/main_shell.dart';
import 'package:v2rayn_flutter/pages/settings_page.dart';
import 'package:v2rayn_flutter/pages/trade_manager_page.dart';
import 'package:v2rayn_flutter/services/api_service.dart';
import 'package:v2rayn_flutter/services/client_config_store.dart';
import 'package:v2rayn_flutter/services/token_store.dart';
import 'package:v2rayn_flutter/widgets/luxwap_icon.dart';

class MockTokenStore implements TokenStore {
  String? _token;
  @override
  Future<void> clear() async => _token = null;
  @override
  Future<String?> loadToken() async => _token;
  @override
  Future<void> saveToken(String token) async => _token = token;
}

class MockConfigStore implements ClientConfigStore {
  ClientConfig config = const ClientConfig();
  @override
  Future<ClientConfig> load() async => config;
  @override
  Future<void> save(ClientConfig c) async => config = c;
}

class MockApiService extends ApiService {
  MockApiService() : super(baseUrl: 'http://127.0.0.1:8080');

  @override
  Future<ApiResult> getUserInfo(String token) async {
    return const ApiResult(code: '0', msg: 'OK', data: {'username': 'test_user'});
  }

  @override
  Future<ApiResult> paymentOrders(String token, {int page = 1, int size = 20}) async {
    return const ApiResult(
      code: '0',
      msg: 'OK',
      data: [
        {
          'orderNo': '453434345345',
          'packageName': '3年送8个月',
          'amount': '180.00',
          'currency': 'USD',
          'status': 'SUCCESS',
          'createdAt': '2026-02-08 10:00:00',
          'paidAt': '2029-10-08 10:00:00',
        }
      ],
    );
  }
}

void main() {
  group('CDP UI Integration Tests - Brand Logo & Main Shell Navigation', () {
    testWidgets('Sidebar displays single unified vector brand logo', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Sidebar(
              selected: 0,
              onSelect: (_) {},
              onHelp: () {},
            ),
          ),
        ),
      );

      // Verify the blue logo icon exists in the sidebar
      final logoFinder = find.byWidgetPredicate(
        (widget) => widget is LuxwapIcon && widget.name == 'icon-logo-blue',
      );
      expect(logoFinder, findsOneWidget, reason: 'Sidebar must have exactly one LuxwapIcon(icon-logo-blue)');

      final logoWidget = tester.widget<LuxwapIcon>(logoFinder);
      expect(logoWidget.width, equals(120));
      expect(logoWidget.height, equals(141));

      // Verify there is no separate redundant Text('Luxwap') widget
      final textFinder = find.text('Luxwap');
      expect(textFinder, findsNothing, reason: 'Wordmark is embedded as vector path in SVG, no redundant Text widget');
    });

    testWidgets('LoginPage header displays single unified vector white brand logo', (WidgetTester tester) async {
      final state = AppState(
        api: ApiService(baseUrl: 'http://127.0.0.1:8080'),
        tokenStore: MockTokenStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            state: state,
            child: const LoginPage(),
          ),
        ),
      );

      // Verify the white logo icon exists in the login header
      final logoFinder = find.byWidgetPredicate(
        (widget) => widget is LuxwapIcon && widget.name == 'icon-logo-white',
      );
      expect(logoFinder, findsOneWidget, reason: 'LoginPage header must have exactly one LuxwapIcon(icon-logo-white)');

      final logoWidget = tester.widget<LuxwapIcon>(logoFinder);
      expect(logoWidget.width, equals(145));
      expect(logoWidget.height, equals(136));
    });

    testWidgets('MainShell sidebar displays exact menu order matching Figma prototype', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Sidebar(
              selected: 0,
              onSelect: (_) {},
              onHelp: () {},
            ),
          ),
        ),
      );

      final menuTexts = ['线路', '个人中心', '交易记录', '设置', '帮助中心', '有礼活动', '关于'];
      for (final text in menuTexts) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('交易管理'), findsNothing);
      expect(find.text('分享有礼'), findsNothing);
    });

    testWidgets('SettingsPage displays clean Figma DNS & routing titles without hardcoded IPs', (WidgetTester tester) async {
      final state = AppState(
        api: MockApiService(),
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

      // Verify clean DNS titles
      expect(find.text('境外流量DNS'), findsOneWidget);
      expect(find.text('境内流量DNS'), findsOneWidget);
      expect(find.text('全局流量DNS'), findsOneWidget);

      // Verify no concatenated IP strings in titles
      expect(find.text('域外流量DNS8.8.8.8'), findsNothing);
      expect(find.text('域内流量DNS223.5.5.5'), findsNothing);
      expect(find.text('全局流量DNS8.8.8.8'), findsNothing);

      // Verify routing titles
      expect(find.text('直连国内IP'), findsOneWidget);
      expect(find.text('直连国内域名'), findsOneWidget);
      expect(find.text('启用VPN路由   端口: 10853'), findsOneWidget);
      expect(find.text('默认使用AsIs规则，本地资源消耗最小'), findsOneWidget);
    });

    testWidgets('TradeManagerPage renders boxed card (_TradeBillCard) with border and 2-column layout', (WidgetTester tester) async {
      final state = AppState(
        api: MockApiService(),
        tokenStore: MockTokenStore(),
        configStore: MockConfigStore(),
      );
      state.token = 'test-token';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppScope(
              state: state,
              child: const TradeManagerPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('订单：3年送8个月'), findsOneWidget);
      expect(find.textContaining('有效期：2029-10-08'), findsOneWidget);
      expect(find.text('订单号：453434345345'), findsOneWidget);
      expect(find.textContaining('开始时间：2026-02-08 10:00'), findsOneWidget);
      expect(find.text(r'US$ 180.00'), findsOneWidget);
      expect(find.text('已支付'), findsOneWidget);

      final statusWidget = tester.widget<Text>(find.text('已支付'));
      expect(statusWidget.style?.color, equals(const Color(0xFFFF9923)));
    });

    testWidgets('LinesPage signal congestion indicator renders 4-bar indicator and no groups icon', (WidgetTester tester) async {
      const nodeGreen = LineNode(
        name: '美洲HUUYWU',
        region: '美洲',
        delayMs: 34,
        testingDelay: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SignalBarsIndicator(node: nodeGreen),
              ],
            ),
          ),
        ),
      );

      final barFinder = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 3.5,
      );
      expect(barFinder, findsNWidgets(4));
      expect(find.byIcon(Icons.groups_rounded), findsNothing);
    });

    testWidgets('ActivityPage renders rank table inside rounded bordered card', (WidgetTester tester) async {
      final state = AppState(
        api: MockApiService(),
        tokenStore: MockTokenStore(),
        configStore: MockConfigStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppScope(
              state: state,
              child: const ActivityPage(),
            ),
          ),
        ),
      );

      expect(find.text('分享有礼'), findsOneWidget);
      expect(find.text('用户名'), findsOneWidget);
      expect(find.text('有效期'), findsOneWidget);
      expect(find.text('奖励'), findsOneWidget);
    });
  });
}
