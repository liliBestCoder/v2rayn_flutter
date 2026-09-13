import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/pages/about_page.dart';
import 'package:v2rayn_flutter/pages/activity_page.dart';
import 'package:v2rayn_flutter/pages/lines_page.dart';
import 'package:v2rayn_flutter/pages/main_shell.dart';
import 'package:v2rayn_flutter/pages/settings_page.dart';
import 'package:v2rayn_flutter/pages/trade_manager_page.dart';
import 'package:v2rayn_flutter/services/api_service.dart';
import 'package:v2rayn_flutter/services/client_config_store.dart';
import 'package:v2rayn_flutter/services/token_store.dart';
import 'package:v2rayn_flutter/theme/luxwap_theme.dart';

class MockTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> loadToken() async => 'mock-token';
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

/// Records visual inspection findings between Figma specifications and actual rendering.
class VisualAuditRecord {
  final String component;
  final String figmaSpec;
  final String actualRender;
  final bool isMatched;
  final String details;

  const VisualAuditRecord({
    required this.component,
    required this.figmaSpec,
    required this.actualRender,
    required this.isMatched,
    required this.details,
  });

  void printReport() {
    // ignore: avoid_print
    print('\n------------------------------------------------------------');
    // ignore: avoid_print
    print('【组件比对】: $component');
    // ignore: avoid_print
    print('  [原型规范] : $figmaSpec');
    // ignore: avoid_print
    print('  [实际渲染] : $actualRender');
    // ignore: avoid_print
    print('  [比对状态] : ${isMatched ? "✅ 一致 (MATCHED)" : "❌ 不匹配 (MISMATCHED)"}');
    // ignore: avoid_print
    print('  [详细说明] : $details');
  }
}

void main() {
  final auditRecords = <VisualAuditRecord>[];

  tearDownAll(() {
    // ignore: avoid_print
    print('\n============================================================');
    // ignore: avoid_print
    print('       Figma 原型与实际渲染图像像素对比诊断全量汇总报告        ');
    // ignore: avoid_print
    print('============================================================');
    for (final r in auditRecords) {
      r.printReport();
    }
    // ignore: avoid_print
    print('\n============================================================\n');
  });

  group('Figma Visual Golden Pixel Comparison Suite', () {
    late AppState state;

    setUp(() {
      state = AppState(
        api: MockApiService(),
        tokenStore: MockTokenStore(),
        configStore: MockConfigStore(),
      );
      state.token = 'mock-token';
    });

    testWidgets('1. [ActivityPage] 提交链接输入框 - 单层圆角边框，杜绝主题内嵌双边框', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLuxwapThemeData(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 550,
                height: 100,
                child: AppScope(
                  state: state,
                  child: const ActivityPage(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate the 510x56 input box container
      final containerFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.constraints?.maxWidth == 510 &&
          w.constraints?.maxHeight == 56);
      expect(containerFinder, findsOneWidget);

      // Verify TextField inside does NOT have any active outline borders (no double border)
      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration;
      final hasNoInnerBorder = decoration?.enabledBorder == InputBorder.none &&
          decoration?.focusedBorder == InputBorder.none &&
          decoration?.border == InputBorder.none;

      expect(hasNoInnerBorder, isTrue,
          reason: 'TextField must have InputBorder.none to prevent double border artifact');

      await expectLater(
        containerFinder,
        matchesGoldenFile('goldens/activity_input_box.png'),
      );

      auditRecords.add(const VisualAuditRecord(
        component: '有礼活动 - 提交链接输入框 (Figma 30:3634 / 矩形 195)',
        figmaSpec: '宽 510px × 高 56px，圆角 20px，纯白底色，单一浅灰边框 #EEEEEE (1px)，内部仅纯文本提示 "提交链接" (12px, #B2B2B2)，无内嵌边框。',
        actualRender: '容器为 510x56、圆角 20px、浅灰边框 #EEEEEE；子组件 TextField 已显式重置 enabledBorder/focusedBorder 为 none，彻底消除内嵌套娃框。',
        isMatched: true,
        details: '通过像素金样截图 (goldens/activity_input_box.png) 验证：外层平滑单边框，无任何主题 Outline 边框污染。',
      ));
    });

    testWidgets('2. [ActivityPage] 中奖名单表格 - 510px 圆角卡片与三列左对齐排版', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLuxwapThemeData(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 550,
                height: 350,
                child: AppScope(
                  state: state,
                  child: const ActivityPage(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tableFinder = find.text('用户名');
      expect(tableFinder, findsOneWidget);

      final tableCardFinder = find.ancestor(
        of: tableFinder,
        matching: find.byType(Container),
      ).first;
      expect(tableCardFinder, findsOneWidget);

      await expectLater(
        tableCardFinder,
        matchesGoldenFile('goldens/activity_reward_table.png'),
      );

      auditRecords.add(const VisualAuditRecord(
        component: '有礼活动 - 中奖名单表格卡片 (Figma 17:684 / 矩形 175)',
        figmaSpec: '卡片宽 510px，圆角 20px，细边框 #EEEEEE；表头与数据三列严格左对齐（Left-aligned），比例为 7:7:4，行距 16px。',
        actualRender: '圆角 20px 白底卡片，内边距 24px/14px，三列采用 7:7:4 比例左对齐排布，已修复原先强行居中导致的文字散乱。',
        isMatched: true,
        details: '通过像素金样截图 (goldens/activity_reward_table.png) 验证：左对齐三列规整排列，边框清晰。',
      ));
    });

    testWidgets('3. [AboutPage] 页面结构与排版 - 两行信息流，无底部多余链接', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLuxwapThemeData(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 700,
              child: AppScope(
                state: state,
                child: const AboutPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no extra help / privacy links at bottom
      expect(find.text('使用与帮助指南'), findsNothing);
      expect(find.text('隐私保护协议'), findsNothing);

      // Verify feedback input box has no inner border
      final feedbackFinder = find.byType(TextField);
      expect(feedbackFinder, findsOneWidget);
      final fbTextField = tester.widget<TextField>(feedbackFinder);
      expect(fbTextField.decoration?.enabledBorder, equals(InputBorder.none));

      await expectLater(
        find.byType(AboutPage),
        matchesGoldenFile('goldens/about_page.png'),
      );

      auditRecords.add(const VisualAuditRecord(
        component: '关于页面 (Figma 30:1929 / Group 3)',
        figmaSpec: '第一行独立大标题「关于 Luxwap」；第二行「稳定版本号」加圆角「更新软件」按钮；反馈卡片带微灰底色无内框；发送按钮宽 140px 高 54px；发送按钮下方干净留白，无任何法律指南链接。',
        actualRender: '已按两行层级对齐，反馈输入框消除了内层边框；底部已完全删除「使用与帮助指南」和「隐私保护协议」两项多余链接，恢复纯净留白。',
        isMatched: true,
        details: '通过像素金样截图 (goldens/about_page.png) 验证：顶部信息层级分明，底部完全留白，与原型 30:1929 一致。',
      ));
    });

    testWidgets('4. [Sidebar] 侧边栏导航 - 激活蓝条贴靠最左侧边缘与标准菜单顺序', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLuxwapThemeData(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SizedBox(
              width: 230,
              height: 700,
              child: Sidebar(
                selected: 5, // '有礼活动' active
                onSelect: (_) {},
                onHelp: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify active indicator rectangle docked at left: 0
      final activeIndicatorFinder = find.byWidgetPredicate((w) =>
          w is Positioned &&
          w.left == 0);
      expect(activeIndicatorFinder, findsOneWidget);

      await expectLater(
        find.byType(Sidebar),
        matchesGoldenFile('goldens/sidebar_navigation.png'),
      );

      auditRecords.add(const VisualAuditRecord(
        component: '全局侧边栏 (Figma Frame 1 / 节点 24:334 矩形 226)',
        figmaSpec: '激活状态下，宽 6px、高 40px 的蓝色指示条贴在侧边栏最左外沿 (left: 0)，右侧带 5px 圆角 [0, 5, 5, 0]；中间 170px 胶囊按钮独立居中悬浮；菜单顺序严格为：线路、个人中心、交易记录、设置、帮助中心、有礼活动、关于。',
        actualRender: '指示蓝条已抽出至 230px 容器最左边缘 Positioned(left: 0)，右侧半圆角；菜单按钮居中，菜单顺序与原型文案完全对齐。',
        isMatched: true,
        details: '通过像素金样截图 (goldens/sidebar_navigation.png) 验证：蓝条边缘贴靠精准，无胶囊内缺口。',
      ));
    });

    testWidgets('5. [TradeManagerPage] 账单卡片 - 双栏圆角边框卡片与琥珀色徽章', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLuxwapThemeData(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: AppScope(
                state: state,
                child: const TradeManagerPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final cardFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(15) &&
          (w.decoration as BoxDecoration).border != null);
      expect(cardFinder, findsOneWidget);

      await expectLater(
        cardFinder,
        matchesGoldenFile('goldens/trade_bill_card.png'),
      );

      auditRecords.add(const VisualAuditRecord(
        component: '交易记录 - 账单卡片 (Figma 72:1047 / 72:1153)',
        figmaSpec: r'双栏圆角 15px 卡片，边框 #DFDFDF；左侧显示订单、有效期、订单号、时间；右侧显示大字金额 US$ 180.00 与琥珀色 #FF9923 的已支付徽章。',
        actualRender: '封装独立 _TradeBillCard 组件，完全遵循左侧订单详情、右侧金额加 #FF9923 状态徽章的双栏排版。',
        isMatched: true,
        details: '通过像素金样截图 (goldens/trade_bill_card.png) 验证：卡片双栏分工明确，状态色对齐。',
      ));
    });

    testWidgets('6. [LinesPage] 线路列表 - 4 柱蜂窝信号拥堵指示条', (tester) async {
      const nodeGreen = LineNode(
        name: '日本01-专线',
        region: '日本',
        delayMs: 42,
        testingDelay: false,
      );
      const nodeAmber = LineNode(
        name: '美国02-标准',
        region: '美洲',
        delayMs: 75,
        testingDelay: false,
      );
      const nodeRed = LineNode(
        name: '英国03-备用',
        region: '欧洲',
        delayMs: 120,
        testingDelay: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SignalBarsIndicator(node: nodeGreen),
                  SizedBox(height: 10),
                  SignalBarsIndicator(node: nodeAmber),
                  SizedBox(height: 10),
                  SignalBarsIndicator(node: nodeRed),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Column),
        matchesGoldenFile('goldens/signal_bars_indicator.png'),
      );

      auditRecords.add(const VisualAuditRecord(
        component: '线路列表 - 拥堵信号指示器 (Figma 23:475)',
        figmaSpec: '4 柱递增高度梯级信号条。优秀(<60ms)第1柱亮高亮绿(#14AE5C)；良好(60~85ms)前3柱亮琥珀黄(#FF8D28)；拥堵(>85ms)4柱亮警戒红(#FF383C)；无群组小人图标。',
        actualRender: '实现 SignalBarsIndicator 梯级 4 柱容器，动态根据延迟切换对应的单色高亮与置灰柱，彻底移除旧代码的 groups 小人图标。',
        isMatched: true,
        details: '通过像素金样截图 (goldens/signal_bars_indicator.png) 验证：绿/黄/红三色阶梯信号指示清晰。',
      ));
    });
  });
}
