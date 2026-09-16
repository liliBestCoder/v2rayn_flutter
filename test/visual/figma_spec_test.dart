import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/pages/lines_page.dart';
import 'package:v2rayn_flutter/pages/main_shell.dart';
import 'package:v2rayn_flutter/pages/trade_manager_page.dart';

import 'figma_cache.dart';
import 'visual_test_helpers.dart';

/// Bill fixture whose status colour is taken from the design file itself.
TradeRecord billFixture(Color statusColor) => TradeRecord(
      type: '在线支付',
      title: '3年送8个月',
      createdAt: '2026-02-08 10:00:00',
      orderNo: '453434345345',
      paidAt: '2029-10-08 10:00:00',
      amount: r'US$ 180.00',
      status: '已支付',
      statusColor: statusColor,
    );

/// Asserts rendered widgets against the Figma design file itself.
///
/// Every expected value is read from the trimmed node cache under
/// `test/visual/figma_cache/` rather than transcribed into the test, so when
/// the design changes the specs move with it: refresh the MCP cache, re-run
/// `python tool/trim_figma_cache.py`, and these tests report the drift.
///
/// This replaces the old `figma_pixel_diff_test.dart`, where the "Figma spec"
/// was a prose string in a print-only audit record and nothing compared the
/// widget to the design at all.
void main() {
  final cache = FigmaCache.instance;

  // The cache is committed under test/visual/figma_cache, so this is normally
  // false. It only trips on a checkout where that directory was stripped, in
  // which case the self-check below still fails loudly with the reason.
  final noCache = !FigmaCache.available;

  group('Figma 设计规范一致性 (来源: test/visual/figma_cache)', () {
    late FigmaNode linesPage;
    late FigmaNode tradePage;

    setUpAll(() {
      if (cache == null) return;
      linesPage = cache.page('主页-线路');
      tradePage = cache.page('交易管理');
    });

    testWidgets('侧边栏几何与选中态取自 Frame 1 / PC主导航按钮', (tester) async {
      final sidebarSpec = linesPage.byName('Frame 1');
      final navButton = linesPage.allByName('PC主导航按钮').first;
      final activeCapsule = navButton.byName('Frame 67');
      final activeBar = navButton.byName('矩形 226');

      await pumpVisual(
        tester,
        alignment: Alignment.topLeft,
        size: Size(sidebarSpec.width + 40, sidebarSpec.height),
        child: Sidebar(selected: 0, onSelect: (_) {}, onHelp: () {}),
      );

      expect(tester.getSize(find.byType(Sidebar)).width, sidebarSpec.width,
          reason: '侧边栏宽度应为设计稿的 ${sidebarSpec.width}');

      // Locate by painted colour rather than tree position: the rail also
      // contains undecorated layout Containers, so `.first` is not the capsule.
      Finder paintedWith(Color color) => find.descendant(
            of: find.byType(Sidebar),
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == color),
          );

      // Selected nav capsule: fill, radius and size all come from the design.
      final capsuleFinder = paintedWith(activeCapsule.fill!);
      expect(capsuleFinder, findsOneWidget,
          reason: '应有且仅有一个选中态胶囊,底色 ${activeCapsule.fill}');
      final decoration =
          tester.widget<Container>(capsuleFinder).decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(activeCapsule.radius!),
        reason: '选中态胶囊圆角应为 ${activeCapsule.radius}',
      );
      expect(tester.getSize(capsuleFinder), activeCapsule.size,
          reason: '选中态胶囊尺寸应为 ${activeCapsule.size}');

      // The blue indicator hugs the very left edge of the rail.
      final barFinder = paintedWith(activeBar.fill!);
      expect(barFinder, findsOneWidget);
      final barRect = tester.getRect(barFinder);
      expect(barRect.size, activeBar.size,
          reason: '选中指示条应为 ${activeBar.size}');
      expect(barRect.left, tester.getRect(find.byType(Sidebar)).left,
          reason: '指示条应贴靠侧边栏最左沿');
    }, skip: noCache);

    testWidgets('侧边栏菜单文案与顺序取自设计稿图层', (tester) async {
      final designLabels = linesPage
          .allByName('PC主导航按钮')
          .map((btn) => btn.children
              .expand((c) => [c, ...c.children])
              .firstWhere((n) => n.characters != null)
              .characters!)
          .toList();

      // The design rail has 8 entries; the app ships 7. 充值中心 is not a page
      // here — MainShell opens the hosted payment flow in the system browser
      // (_openRenewPage), so there is no nav destination to render. Asserting
      // the difference explicitly means an accidental drift still fails.
      expect(designLabels, hasLength(8), reason: '设计稿侧边栏共 8 项');
      const omittedByDesign = {'充值中心'};
      final expectedLabels =
          designLabels.where((l) => !omittedByDesign.contains(l)).toList();
      expect(expectedLabels, hasLength(7));

      await pumpVisual(
        tester,
        alignment: Alignment.topLeft,
        size: const Size(280, 960),
        child: Sidebar(selected: 0, onSelect: (_) {}, onHelp: () {}),
      );

      for (final label in expectedLabels) {
        expect(find.text(label), findsOneWidget,
            reason: '侧边栏应包含设计稿菜单项「$label」');
      }
      for (final label in omittedByDesign) {
        expect(find.text(label), findsNothing,
            reason: '「$label」走外部支付页，侧边栏不应出现');
      }
    }, skip: noCache);

    testWidgets('线路行尺寸/边框/选中底色取自 kuang-line-*', (tester) async {
      final unselected = linesPage.allByName('kuang-line-unselect').first;
      final selected = linesPage.allByName('kuang-line-selected').first;

      const node = LineNode(
        name: '美洲HUUYWU',
        region: '美洲',
        delayMs: 34,
      );

      await pumpVisual(
        tester,
        alignment: Alignment.topLeft,
        size: Size(unselected.width + 40, unselected.height * 3),
        child: Column(
          children: [
            LineRow(node: node, index: 0, selected: false, onTap: () {}),
            LineRow(node: node, index: 1, selected: true, onTap: () {}),
          ],
        ),
      );

      final rows = find.byType(LineRow);
      // Figma stacks rows on a fixed pitch; the widget carries the gap as
      // bottom padding, so its own height is pitch, and the card inside is
      // the design's row height.
      // Filter by type: a Figma TEXT layer is named after its content, so the
      // 「线路列表」 heading shares the name with the row instances.
      final rowInstances = linesPage
          .allByName('线路列表')
          .where((n) => n.type == 'INSTANCE')
          .toList();
      final pitch = rowInstances[1].top - rowInstances[0].top;
      expect(tester.getSize(rows.at(0)).height, pitch,
          reason: '线路行间距应使行距为设计稿的 $pitch');
      expect(
        tester
            .getSize(find
                .descendant(of: rows.at(0), matching: find.byType(Container))
                .first)
            .height,
        unselected.height,
        reason: '线路卡高度应为设计稿的 ${unselected.height}',
      );

      final unselectedBox = tester.widget<Container>(
        find
            .descendant(of: rows.at(0), matching: find.byType(Container))
            .first,
      );
      final unselectedDecoration = unselectedBox.decoration as BoxDecoration;
      expect(
        (unselectedDecoration.border as Border).top.color,
        unselected.strokeColor,
        reason: '未选中行边框应为 ${unselected.strokeColor}',
      );
      expect(
        unselectedDecoration.borderRadius,
        BorderRadius.circular(unselected.radius!),
      );

      final selectedBox = tester.widget<Container>(
        find
            .descendant(of: rows.at(1), matching: find.byType(Container))
            .first,
      );
      expect((selectedBox.decoration as BoxDecoration).color, selected.fill,
          reason: '选中行底色应为 ${selected.fill}');
    }, skip: noCache);

    testWidgets('洲分组标题栏尺寸与底色取自 Frame 21', (tester) async {
      final header = linesPage.allByName('Frame 21').first;
      final title = header.children.firstWhere((c) => c.characters != null);

      await pumpVisual(
        tester,
        alignment: Alignment.topLeft,
        size: Size(header.width + 40, 200),
        child: RegionGroup(
          title: '美洲',
          nodes: const [],
          selectedRaw: null,
          onSelected: (_) {},
        ),
      );

      final headerBox = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RegionGroup),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = headerBox.decoration as BoxDecoration;
      expect(decoration.color, header.fill,
          reason: '分组标题底色应为 ${header.fill}');
      expect(decoration.borderRadius, BorderRadius.circular(header.radius!));
      expect(tester.getSize(find.byType(Container).first).height, header.height);

      final titleStyle = tester.widget<Text>(find.text('美洲')).style!;
      expect(titleStyle.fontSize, title.fontSize,
          reason: '分组标题字号应为 ${title.fontSize}');
      expect(titleStyle.fontWeight, title.fontWeight);
      expect(titleStyle.color, title.fill);
    }, skip: noCache);

    testWidgets('连接状态条渐变色标取自 PC 连接状态', (tester) async {
      final statusSpec = linesPage.byName('PC 连接状态');
      final stops = statusSpec.gradientStops;

      expect(stops, hasLength(greaterThanOrEqualTo(2)),
          reason: '设计稿连接状态条应为渐变填充');

      await pumpVisual(
        tester,
        alignment: Alignment.topLeft,
        size: Size(statusSpec.width + 40, statusSpec.height + 40),
        child: StatusBar(
          connected: true,
          switching: false,
          speedText: '↑ 240kb/s  ↓ 1.2mb/s',
          onChanged: (_) {},
        ),
      );

      final bar = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(StatusBar),
              matching: find.byType(Container),
            )
            .first,
      );
      final gradient =
          (bar.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors.first, stops.first,
          reason: '渐变起始色应为 ${stops.first}');
      expect(gradient.colors.last, stops.last,
          reason: '渐变结束色应为 ${stops.last}');
      expect(tester.getSize(find.byType(StatusBar)).height, statusSpec.height);
    }, skip: noCache);

    testWidgets('账单卡尺寸与状态色取自「账单」组件', (tester) async {
      final billSpec = tradePage.allByName('账单').first;
      final paidBadge = billSpec.byText('已支付');

      await pumpVisual(
        tester,
        alignment: Alignment.topLeft,
        size: Size(billSpec.width + 40, billSpec.height + 40),
        child: TradeBillCard(record: billFixture(paidBadge.fill!)),
      );

      expect(tester.getSize(find.byType(TradeBillCard)).height, billSpec.height,
          reason: '账单卡高度应为设计稿的 ${billSpec.height}');

      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TradeBillCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        ((card.decoration as BoxDecoration).border as Border).top.color,
        billSpec.strokeColor,
        reason: '账单卡边框应为 ${billSpec.strokeColor}',
      );

      final badgeStyle = tester.widget<Text>(find.text('已支付')).style!;
      expect(badgeStyle.color, paidBadge.fill,
          reason: '已支付徽章颜色应为 ${paidBadge.fill}');
      expect(badgeStyle.fontSize, paidBadge.fontSize);
    }, skip: noCache);
  });

  group('Figma 缓存自检', () {
    test('缓存可用且包含本次断言依赖的页面', () {
      expect(cache, isNotNull, reason: FigmaCache.unavailableReason);
      expect(
        cache!.pageNames.where((n) => n.contains('主页-线路')),
        isNotEmpty,
        reason: '缓存中应有「PC 3分-主页-线路」页,实际: ${cache.pageNames}',
      );
    });
  });
}
