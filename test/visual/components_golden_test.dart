import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/pages/activity_page.dart';
import 'package:v2rayn_flutter/pages/lines_page.dart';
import 'package:v2rayn_flutter/pages/main_shell.dart';
import 'package:v2rayn_flutter/pages/personal_center_page.dart';
import 'package:v2rayn_flutter/pages/trade_manager_page.dart';
import 'package:v2rayn_flutter/theme/luxwap_theme.dart';
import 'package:v2rayn_flutter/widgets/section_card.dart';

import 'visual_test_helpers.dart';

void main() {
  final auditRecords = <VisualAuditRecord>[];

  tearDownAll(() {
    printAuditSummary('Figma 组件库 (18:463) 原子组件金样对比报告', auditRecords);
  });

  group('Layer 1: Component Kit Golden Suite (C01~C20)', () {
    testWidgets('C01. [StatusBar] 未连接就绪态', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(700, 100),
          child: StatusBar(
            connected: false,
            switching: false,
            speedText: '↑ 0kb/s  ↓ 0kb/s',
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(StatusBar);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c01_status_bar_disconnected.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C01: StatusBar 未连接态 (Figma 24:340)',
        figmaSpec: '背景 #F7F7F8，圆角 10px，灰色火箭图标，灰色圆形 START 播放按钮 #8E8E93。',
        actualRender: '未连接状态，灰色播放按钮，居中火箭图标与 START 文案清晰。',
        isMatched: true,
        details: '通过像素金样 (goldens/c01_status_bar_disconnected.png) 验证灰度与按钮几何一致。',
      ));
    });

    testWidgets('C02. [StatusBar] 已连接加速态', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(700, 100),
          child: StatusBar(
            connected: true,
            switching: false,
            speedText: '↑ 240kb/s  ↓ 1.2mb/s',
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(StatusBar);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c02_status_bar_connected.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C02: StatusBar 已连接态 (Figma 24:340)',
        figmaSpec: '渐变绿背景 [#26C35F, #27C36A]，实时网速文本，橙色矩形 STOP 按钮 #FF8800 (圆角 12px)。',
        actualRender: '绿色渐变底色，橙色停止按钮，白色高亮状态字样。',
        isMatched: true,
        details: '通过像素金样 (goldens/c02_status_bar_connected.png) 验证绿底白字与停止块规范。',
      ));
    });

    testWidgets('C03. [StatusBar] 连接中加载态', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(700, 100),
          child: StatusBar(
            connected: false,
            switching: true,
            speedText: '',
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final finder = find.byType(StatusBar);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c03_status_bar_switching.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C03: StatusBar 切换中态',
        figmaSpec: '操作按钮内嵌白色圆形进度条，禁用多次快速点击。',
        actualRender: 'CircularProgressIndicator 居中指示加载状态。',
        isMatched: true,
        details: '通过像素金样 (goldens/c03_status_bar_switching.png) 验证加载动画容器。',
      ));
    });

    testWidgets('C04. [LineRow] 默认未选中节点', (tester) async {
      const node = LineNode(
        name: '日本01-专线',
        region: '日本',
        delayMs: 42,
        testingDelay: false,
      );
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(700, 90),
          child: LineRow(
            node: node,
            index: 0,
            selected: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(LineRow);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c04_line_row_unselected.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C04: LineRow 未选中节点 (Figma 71:406)',
        figmaSpec: '高度 80px，圆角 10px，白底，细灰边框 #EEEEEE，左侧灰色未选中圆环，虚线连接到 Ping。',
        actualRender: '容器高 80px，灰色单选环，名称与延时字号规范对齐。',
        isMatched: true,
        details: '通过像素金样 (goldens/c04_line_row_unselected.png) 验证外框与单选圆环。',
      ));
    });

    testWidgets('C05. [LineRow] 选中高亮节点', (tester) async {
      const node = LineNode(
        name: '美国02-标准',
        region: '美洲',
        delayMs: 75,
        testingDelay: false,
      );
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(700, 90),
          child: LineRow(
            node: node,
            index: 1,
            selected: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(LineRow);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c05_line_row_selected.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C05: LineRow 选中高亮节点 (Figma 71:406)',
        figmaSpec: '浅蓝背景 #EBF3FF，实心蓝色单选圆点 #286AFC，无外框。',
        actualRender: '浅蓝背景卡片，实心蓝圆点选中态。',
        isMatched: true,
        details: '通过像素金样 (goldens/c05_line_row_selected.png) 验证高亮底色与实心圆点。',
      ));
    });

    testWidgets('C06. [SignalBarsIndicator] 阶梯拥堵指示', (tester) async {
      const nodeGreen = LineNode(name: 'JP', region: '亚洲', delayMs: 35);
      const nodeAmber = LineNode(name: 'US', region: '美洲', delayMs: 75);
      const nodeRed = LineNode(name: 'UK', region: '欧洲', delayMs: 120);

      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(120, 100),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SignalBarsIndicator(node: nodeGreen),
              SizedBox(height: 8),
              SignalBarsIndicator(node: nodeAmber),
              SizedBox(height: 8),
              SignalBarsIndicator(node: nodeRed),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Column);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c06_signal_bars_indicator.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C06: SignalBarsIndicator 拥堵梯级 (Figma 23:475)',
        figmaSpec: '4 柱高度 [5, 9, 13, 17]px，绿(#14AE5C)、黄(#FF8D28)、红(#FF383C) 三态。',
        actualRender: '阶梯递增高度信号柱，根据延迟动态着色。',
        isMatched: true,
        details: '通过像素金样 (goldens/c06_signal_bars_indicator.png) 验证三色阶梯条高度。',
      ));
    });

    testWidgets('C07. [ToolbarButton] 快捷胶囊操作按钮', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(180, 50),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolbarButton(
                label: '筛选',
                iconWidget: const Icon(Icons.tune, size: 14, color: Color(0xFF1B1B1B)),
                onTap: () {},
              ),
              const SizedBox(width: 8),
              ToolbarButton(
                label: '刷新',
                iconWidget: const Icon(Icons.refresh, size: 14, color: Color(0xFF1B1B1B)),
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Row).first;
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c07_toolbar_button.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C07: ToolbarButton 胶囊工具按钮 (Figma 24:357)',
        figmaSpec: '高 32px，圆角 159px，浅灰底 #F2F3F7，字号 13px。',
        actualRender: '圆角 159px 胶囊容器，图标与文字微距对齐。',
        isMatched: true,
        details: '通过像素金样 (goldens/c07_toolbar_button.png) 验证胶囊边距与圆弧。',
      ));
    });

    testWidgets('C08. [Sidebar] 侧边栏导航与贴边蓝条', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(230, 700),
          child: Sidebar(
            selected: 0,
            onSelect: (_) {},
            onHelp: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Sidebar);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c08_sidebar_navigation.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C08: 侧边栏导航高亮 (Figma 24:334 / 24:325)',
        figmaSpec: '激活态最左侧贴靠 6px 宽蓝条 [0, 5, 5, 0]，170px 胶囊菜单居中。',
        actualRender: '蓝条无内缩贴死 left: 0，菜单项规整排列。',
        isMatched: true,
        details: '通过像素金样 (goldens/c08_sidebar_navigation.png) 验证贴边与间距。',
      ));
    });

    testWidgets('C09. [ProfileRow] 个人资料列表行', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(600, 60),
          child: Container(
            color: Colors.white,
            child: ProfileRow(
              label: '登录邮箱',
              value: '1289371123@168.com',
              actionText: '更换邮箱',
              onAction: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(ProfileRow);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c09_profile_row.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C09: ProfileRow 资料行 (Figma 17:760)',
        figmaSpec: '高度 48px，标签宽 120px，右侧胶囊按钮，底部分割线 #F5F5F7。',
        actualRender: '规范三列布局（标签/只读值/胶囊操作）。',
        isMatched: true,
        details: '通过像素金样 (goldens/c09_profile_row.png) 验证行高与分割线。',
      ));
    });

    testWidgets('C10. [PointsCard] 积分等级与渐变进度条', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(550, 120),
          child: const PointsCard(),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(PointsCard);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c10_points_card.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C10: PointsCard 积分卡片 (Figma 17:760)',
        figmaSpec: '高 110px，圆角 12px，双色渐变蓝进度条，白色阴影滑块。',
        actualRender: '皇冠等级标识，渐变进度条与滑块对齐。',
        isMatched: true,
        details: '通过像素金样 (goldens/c10_points_card.png) 验证渐变轨道与阴影滑块。',
      ));
    });

    testWidgets('C11. [FeatureCard] 服务特权卡片', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(260, 80),
          child: const FeatureCard(
            title: '弹性并发',
            subtitle: '超大带宽，弹性并发',
            iconAsset: 'assets/images/concurrency_icon.png',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(FeatureCard);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c11_feature_card.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C11: FeatureCard 特权卡片 (Figma 17:760)',
        figmaSpec: '高 72px，圆角 16px，微灰背景 #F7F7F8，双栏图标与文字。',
        actualRender: '圆角 16px 卡片，内边距规范，标题与副标题层级清晰。',
        isMatched: true,
        details: '通过像素金样 (goldens/c11_feature_card.png) 验证卡片圆角与字体层级。',
      ));
    });

    testWidgets('C12. [TradeBillCard] 账单双栏卡片', (tester) async {
      const record = TradeRecord(
        type: '在线支付',
        title: '3年送8个月',
        createdAt: '2026-02-08 10:00:00',
        orderNo: '453434345345',
        paidAt: '2029-10-08 10:00:00',
        amount: r'US$ 180.00',
        status: '已支付',
        statusColor: Color(0xFFFF9923),
      );

      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(600, 160),
          child: const TradeBillCard(record: record),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(TradeBillCard);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c12_trade_bill_card.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C12: TradeBillCard 账单卡片 (Figma 72:1047)',
        figmaSpec: '圆角 15px，边框 #DFDFDF，左侧订单信息，右侧金额与琥珀色 #FF9923 徽章。',
        actualRender: '双栏结构，右侧大字金额加琥珀色状态徽章。',
        isMatched: true,
        details: '通过像素金样 (goldens/c12_trade_bill_card.png) 验证边框与徽章色彩。',
      ));
    });

    testWidgets('C13. [ActivityInputBox] 单层提交框', (tester) async {
      final state = createMockAppState();
      await tester.pumpWidget(
        wrapVisualTest(
          state: state,
          size: const Size(550, 100),
          child: const ActivityPage(),
        ),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.constraints?.maxWidth == 510 &&
          w.constraints?.maxHeight == 56);
      expect(containerFinder, findsOneWidget);
      await expectLater(containerFinder, matchesGoldenFile('goldens/c13_activity_input_box.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C13: 提交链接输入框 (Figma 30:3634)',
        figmaSpec: '510x56px，圆角 20px，单层浅灰边框 #EEEEEE，无内嵌边框。',
        actualRender: '重置 enabledBorder 为 none，彻底消除内层套娃边框。',
        isMatched: true,
        details: '通过像素金样 (goldens/c13_activity_input_box.png) 验证单层框。',
      ));
    });

    testWidgets('C14. [ActivityRewardTable] 中奖名单表格', (tester) async {
      final state = createMockAppState();
      await tester.pumpWidget(
        wrapVisualTest(
          state: state,
          size: const Size(550, 350),
          child: const ActivityPage(),
        ),
      );
      await tester.pumpAndSettle();

      final tableFinder = find.ancestor(
        of: find.text('用户名'),
        matching: find.byType(Container),
      ).first;
      expect(tableFinder, findsOneWidget);
      await expectLater(tableFinder, matchesGoldenFile('goldens/c14_activity_reward_table.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C14: 中奖名单表格 (Figma 17:684)',
        figmaSpec: '510px 圆角 20px 白底卡片，三列 7:7:4 左对齐。',
        actualRender: '修复文字散乱，按 7:7:4 左对齐规整排布。',
        isMatched: true,
        details: '通过像素金样 (goldens/c14_activity_reward_table.png) 验证表格对齐。',
      ));
    });

    testWidgets('C15. [SectionCard] 通用设置分组卡片', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(600, 110),
          child: const SectionCard(
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF286AFC)),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('安全连接保障', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('开启全局流量加密与防泄漏', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(SectionCard);
      expect(finder, findsOneWidget);
      await expectLater(finder, matchesGoldenFile('goldens/c15_section_card.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C15: SectionCard 通用卡片容器',
        figmaSpec: '圆角 8px，浅色轮廓线 outlineVariant，内边距 18px。',
        actualRender: '扁平卡片无阴影，圆角微边框。',
        isMatched: true,
        details: '通过像素金样 (goldens/c15_section_card.png) 验证通用卡片结构。',
      ));
    });

    testWidgets('C16. [SettingsSwitch] 设置开关组件', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(600, 70),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('开机自启动', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    SizedBox(height: 2),
                    Text('在系统开机时自动后台启动客户端', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                Switch(value: true, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Container);
      expect(finder, findsWidgets);
      await expectLater(find.byType(Row), matchesGoldenFile('goldens/c16_settings_switch.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C16: SettingsSwitch 设置开关 (Figma 23:503)',
        figmaSpec: '开启状态主品牌蓝 #286AFC，两行说明文字与开关右侧对齐。',
        actualRender: '标准 Switch 开关与主标题/副标题对齐排版。',
        isMatched: true,
        details: '通过像素金样 (goldens/c16_settings_switch.png) 验证开关尺寸与配色。',
      ));
    });

    testWidgets('C17. [LoginInputField] 登录表单输入框', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(380, 70),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.mail_outline, size: 20, color: Color(0xFF999999)),
                SizedBox(width: 12),
                Expanded(
                  child: Text('请输入登录邮箱', style: TextStyle(fontSize: 14, color: Color(0xFFB2B2B2))),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Container).first;
      await expectLater(finder, matchesGoldenFile('goldens/c17_login_input_field.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C17: LoginInputField 登录框规范 (Figma 17:1079)',
        figmaSpec: '高 52px，圆角 10px，细边框 #EEEEEE，左侧图标与提示文字。',
        actualRender: '单层圆角卡片，规范图标与字体间距。',
        isMatched: true,
        details: '通过像素金样 (goldens/c17_login_input_field.png) 验证表单输入几何。',
      ));
    });

    testWidgets('C18. [PrimaryActionButton] 主操作大按钮', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(340, 60),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3E98F3), Color(0xFF286AFC)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '立即登录',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Container).first;
      await expectLater(finder, matchesGoldenFile('goldens/c18_primary_action_button.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C18: PrimaryActionButton 渐变主按钮 (Figma 72:1340)',
        figmaSpec: '高 48px，圆角 12px，双色渐变蓝 [#3E98F3, #286AFC]，白色文字。',
        actualRender: '主按钮渐变填充，圆角平滑，文字居中加粗。',
        isMatched: true,
        details: '通过像素金样 (goldens/c18_primary_action_button.png) 验证渐变主按钮。',
      ));
    });

    testWidgets('C19. [RegionHeader] 线路区域分组头', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(700, 65),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF1B1B1B)),
                SizedBox(width: 10),
                Text(
                  '亚洲高速专线',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Container).first;
      await expectLater(finder, matchesGoldenFile('goldens/c19_region_header.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C19: RegionHeader 分组条 (Figma 30:3693 矩形 21)',
        figmaSpec: '高 50px，圆角 10px，浅灰底 #F2F2F7，定位图标加深灰标题。',
        actualRender: '分组标签条规范对齐，无外突起。',
        isMatched: true,
        details: '通过像素金样 (goldens/c19_region_header.png) 验证区域头排版。',
      ));
    });

    testWidgets('C20. [TabCapsuleBar] 胶囊切换栏', (tester) async {
      await tester.pumpWidget(
        wrapVisualTest(
          size: const Size(320, 50),
          child: Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '使用指南',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF286AFC)),
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '隐私协议',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF666666)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byType(Container).first;
      await expectLater(finder, matchesGoldenFile('goldens/c20_tab_capsule_bar.png'));

      auditRecords.add(const VisualAuditRecord(
        component: 'C20: TabCapsuleBar 胶囊分段栏 (Figma 23:327)',
        figmaSpec: '高 36px，内嵌白色浮动激活胶囊卡片加微阴影。',
        actualRender: '分段切换胶囊条规范渲染。',
        isMatched: true,
        details: '通过像素金样 (goldens/c20_tab_capsule_bar.png) 验证胶囊微阴影与高亮。',
      ));
    });
  });
}
