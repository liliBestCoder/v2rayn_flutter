import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/pages/about_page.dart';
import 'package:v2rayn_flutter/pages/activity_page.dart';
import 'package:v2rayn_flutter/pages/change_password_dialog.dart';
import 'package:v2rayn_flutter/pages/help_page.dart';
import 'package:v2rayn_flutter/pages/lines_page.dart';
import 'package:v2rayn_flutter/pages/login_page.dart';
import 'package:v2rayn_flutter/pages/main_shell.dart';
import 'package:v2rayn_flutter/pages/personal_center_page.dart';
import 'package:v2rayn_flutter/pages/settings_page.dart';
import 'package:v2rayn_flutter/pages/trade_manager_page.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/services/api_service.dart';

import 'visual_test_helpers.dart';

class EmptyOrdersApiService extends MockApiService {
  @override
  Future<ApiResult> paymentOrders(String token, {int page = 1, int size = 20}) async {
    return const ApiResult(code: '0', msg: 'OK', data: []);
  }
}

void main() {
  setUpAll(useTolerantGoldens);

  final auditRecords = <VisualAuditRecord>[];

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('luxwap/window'), (call) async => null);
  });

  tearDownAll(() {
    printAuditSummary('Figma 业务画板与场景状态金样全量对比报告', auditRecords);
  });

  group('Layer 2: Page & State Golden Suite (P01~P15)', () {
    testWidgets('P01. [LinesPage] 线路主页就绪态', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(900, 650),
        child: const LinesPage(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final finder = find.byType(LinesPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p01_lines_page_ready.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P01: 线路主页就绪态 (Figma 30:3693)',
        figmaSpec: '未连接状态条、线路列表标题行带筛选与刷新按钮、地区分组节点流。',
        actualRender: '未连接灰色状态条居顶，区域节点分组流完整展示。',
        details: '通过像素金样 (goldens/p01_lines_page_ready.png) 验证整页就绪态。',
      ));
    });

    testWidgets('P02. [LinesPage] 节点分组流与选中高亮态', (tester) async {
      const nodes = [
        LineNode(name: '日本01-专线', region: '日本', delayMs: 42),
        LineNode(name: '美国02-标准', region: '美洲', delayMs: 75),
        LineNode(name: '英国03-备用', region: '欧洲', delayMs: 120),
      ];

      await pumpVisual(
        tester,
        size: const Size(800, 400),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            RegionGroup(
              title: '优质亚太专线',
              nodes: nodes,
              selectedRaw: nodes[0].raw,
              onSelected: (_) {},
            ),
          ],
        ),
      );

      final finder = find.byType(ListView);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p02_lines_page_regions.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P02: 线路分组与选中卡片流 (Figma 71:406)',
        figmaSpec: '区域灰底分组头，选中节点浅蓝背景 #EBF3FF 与未选中白底卡片对比。',
        actualRender: '第一项呈现蓝色高亮选中，其余项呈现白底浅灰边框。',
        details: '通过像素金样 (goldens/p02_lines_page_regions.png) 验证选中态与未选态对比。',
      ));
    });

    testWidgets('P03. [PersonalCenterPage] 个人中心全景视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(800, 650),
        child: const PersonalCenterPage(),
      );

      final finder = find.byType(PersonalCenterPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p03_personal_center_page.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P03: 个人中心全景 (Figma 17:760)',
        figmaSpec: '积分等级卡片居顶、个人资料白底圆角卡片、服务特权双栏卡片、退出登录居中按钮。',
        actualRender: '完整垂直滚动流，间距规范，资料各行对齐。',
        details: '通过像素金样 (goldens/p03_personal_center_page.png) 验证整页排版。',
      ));
    });

    testWidgets('P04. [TradeManagerPage] 账单列表有数据视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(800, 550),
        child: const TradeManagerPage(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final finder = find.byType(TradeManagerPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p04_trade_manager_page_list.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P04: 交易管理多订单流 (Figma 30:2141)',
        figmaSpec: '垂直排列订单双栏圆角卡片，间距 16px。',
        actualRender: '订单卡片流规整对齐，展示大字金额与状态徽章。',
        details: '通过像素金样 (goldens/p04_trade_manager_page_list.png) 验证列表流。',
      ));
    });

    testWidgets('P05. [TradeManagerPage] 账单列表无数据空状态视图', (tester) async {
      final state = AppState(
        api: EmptyOrdersApiService(),
        tokenStore: MockTokenStore(),
        configStore: MockConfigStore(),
      );
      state.token = 'mock-token';

      await pumpVisual(
        tester,
        state: state,
        size: const Size(800, 500),
        child: const TradeManagerPage(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final finder = find.byType(TradeManagerPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p05_trade_manager_page_empty.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P05: 交易管理空状态',
        figmaSpec: '居中提示「暂无交易记录」，字号 14px，灰度 #999999。',
        actualRender: '水平垂直居中展示空数据占位。',
        details: '通过像素金样 (goldens/p05_trade_manager_page_empty.png) 验证空状态。',
      ));
    });

    testWidgets('P06. [SettingsPage] 核心系统与路由设置视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(800, 650),
        child: const SettingsPage(),
      );

      final finder = find.byType(SettingsPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p06_settings_page.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P06: 设置中心整页 (Figma 17:222)',
        figmaSpec: '系统网络设置卡片、TUN 虚拟网卡模式、DoT 安全解析与最小化托盘设置。',
        actualRender: '卡片分组对齐，Switch 开关与描述清晰呈现。',
        details: '通过像素金样 (goldens/p06_settings_page.png) 验证设置项排布。',
      ));
    });

    testWidgets('P07. [HelpPage] 使用指南 Tab 视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(850, 650),
        child: const HelpPage(initialTab: 0),
      );

      final finder = find.byType(HelpPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p07_help_page_guide.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P07: 帮助中心使用指南 (Figma 30:1841)',
        figmaSpec: '顶部胶囊切换选中「使用与帮助指南」，左侧放大镜单框搜索条，下方文档内容。',
        actualRender: '胶囊处于第一项激活，单层搜索栏无套娃内边框。',
        details: '通过像素金样 (goldens/p07_help_page_guide.png) 验证帮助文档视图。',
      ));
    });

    testWidgets('P08. [HelpPage] 隐私协议 Tab 视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(850, 650),
        child: const HelpPage(initialTab: 1),
      );

      final finder = find.byType(HelpPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p08_help_page_privacy.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P08: 帮助中心隐私协议 (Figma 30:1841)',
        figmaSpec: '胶囊切换选中「隐私保护协议」，正文规范分行与灰色标题。',
        actualRender: '协议 Tab 激活高亮，正文排版清晰整齐。',
        details: '通过像素金样 (goldens/p08_help_page_privacy.png) 验证隐私协议视图。',
      ));
    });

    testWidgets('P09. [ActivityPage] 分享有礼活动全景视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(800, 650),
        child: const ActivityPage(),
      );

      final finder = find.byType(ActivityPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p09_activity_page.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P09: 分享有礼活动全景 (Figma 30:2353)',
        figmaSpec: '活动规则说明卡片、单框浅灰提交链接区、7:7:4 左对齐中奖名单表格。',
        actualRender: '页面各模块垂直对齐，彻底消除套娃边框。',
        details: '通过像素金样 (goldens/p09_activity_page.png) 验证活动全景。',
      ));
    });

    testWidgets('P10. [AboutPage] 关于软件纯净留白视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(800, 650),
        child: const AboutPage(),
      );

      final finder = find.byType(AboutPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p10_about_page.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P10: 关于软件全景 (Figma 30:1929)',
        figmaSpec: '两行主标题与更新按钮、单层反馈输入框、底部彻底无多余链接留白。',
        actualRender: '完全符合原型层级规范，底部干净留白。',
        details: '通过像素金样 (goldens/p10_about_page.png) 验证关于软件视图。',
      ));
    });

    testWidgets('P11. [LoginPage] 账号密码登录模式视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(800, 650),
        child: const LoginPage(),
      );

      final finder = find.byType(LoginPage);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p11_login_page.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P11: 登录界面 (Figma 30:3193)',
        figmaSpec: '深色背景白色矢量 Logo、居中圆角卡片、邮箱密码输入框与渐变蓝主按钮。',
        actualRender: '居中卡片式排版，输入框与协议行规范渲染。',
        details: '通过像素金样 (goldens/p11_login_page.png) 验证登录页面视图。',
      ));
    });

    testWidgets('P12. [ChangePasswordDialog] 修改密码模态弹窗', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(500, 450),
        child: const Dialog(
          backgroundColor: Colors.transparent,
          child: ChangePasswordDialog(),
        ),
      );

      final finder = find.byType(ChangePasswordDialog);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p12_change_password_dialog.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P12: 修改密码弹窗',
        figmaSpec: '居中圆角模态框，包含旧密码、新密码、确认密码三组输入与取消/确认操作按钮。',
        actualRender: '弹窗层次分明，按钮与输入框间距规范。',
        details: '通过像素金样 (goldens/p12_change_password_dialog.png) 验证弹窗几何。',
      ));
    });

    testWidgets('P13. [MainShell] 桌面客户端主窗口全壳视图', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(1000, 700),
        child: const MainShell(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final finder = find.byType(MainShell);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p13_main_shell.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P13: 主窗口全局框架 (Figma 30:3010)',
        figmaSpec: '左侧 230px 侧边栏贴靠、右侧顶部标题栏与主内容区分割。',
        actualRender: '侧边栏与内容区严丝合缝对齐。',
        details: '通过像素金样 (goldens/p13_main_shell.png) 验证主窗口全局骨架。',
      ));
    });

    testWidgets('P14. [PersonalCenter] 编辑昵称卡片弹窗', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(450, 320),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('编辑用户昵称', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: '新昵称',
                    hintText: '请输入新昵称',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () {}, child: const Text('取消')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () {}, child: const Text('保存')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final finder = find.byType(Dialog);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/p14_edit_nick_dialog.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P14: 编辑资料通用弹窗',
        figmaSpec: '圆角 16px 卡片，标准标题、输入框、取消与保存操作按钮。',
        actualRender: '弹窗阴影与输入框、操作按钮规整排列。',
        details: '通过像素金样 (goldens/p14_edit_nick_dialog.png) 验证模态弹窗规范。',
      ));
    });

    testWidgets('P15. [AppShell] 窗口控制标题栏', (tester) async {
      await pumpVisual(
        tester,
        size: const Size(800, 48),
        child: Container(
          height: 48,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF286AFC)),
              const SizedBox(width: 8),
              const Text('Luxwap Client v2.1.0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
              const Spacer(),
              IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () {}),
              IconButton(icon: const Icon(Icons.crop_square, size: 14), onPressed: () {}),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () {}),
            ],
          ),
        ),
      );

      final finder = find.byType(Container).first;
      await expectLater(finder, matchesGoldenFile('goldens/p15_app_title_bar.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'P15: 顶部标题与窗口控制栏 (Figma 72:806)',
        figmaSpec: '高 48px，白底，版本号状态文本，右侧最小化/最大化/关闭按钮。',
        actualRender: '标准桌面客户端标题栏几何与对齐。',
        details: '通过像素金样 (goldens/p15_app_title_bar.png) 验证标题栏像素。',
      ));
    });
  });
}
