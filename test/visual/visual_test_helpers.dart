import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/user_info.dart';
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
    return const ApiResult(
      code: '0',
      msg: 'OK',
      data: {
        'username': '1289371123@168.com',
        'nick': '用户JHSJD98',
        'uuid': 'test-uuid-1234-5678',
        'points': 1000,
        'country': 'CN',
      },
    );
  }

  @override
  Future<ApiResult> lineList(String token) async {
    return const ApiResult(
      code: '0',
      msg: 'OK',
      data: [
        'vless://11111111-2222-3333-4444-555555555555@jp1.luxwap.net:443?encryption=none&security=tls&type=ws&host=jp1.luxwap.net&path=%2F#%E6%97%A5%E6%9C%AC01-%E4%B8%93%E7%BA%BF',
        'vless://11111111-2222-3333-4444-555555555555@us1.luxwap.net:443?encryption=none&security=tls&type=ws&host=us1.luxwap.net&path=%2F#%E7%BE%8E%E5%9B%BD02-%E6%A0%87%E5%87%86',
        'vless://11111111-2222-3333-4444-555555555555@uk1.luxwap.net:443?encryption=none&security=tls&type=ws&host=uk1.luxwap.net&path=%2F#%E8%8B%B1%E5%9B%BD03-%E5%A4%87%E7%94%A8',
      ],
    );
  }

  @override
  Future<ApiResult> paymentOrders(String token,
      {int page = 1, int size = 20}) async {
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
        },
        {
          'orderNo': '453434345346',
          'packageName': '1年标准包',
          'amount': '68.00',
          'currency': 'USD',
          'status': 'SUCCESS',
          'createdAt': '2026-01-01 12:30:00',
          'paidAt': '2027-01-01 12:30:00',
        },
      ],
    );
  }
}

AppState createMockAppState() {
  final state = AppState(
    api: MockApiService(),
    tokenStore: MockTokenStore(),
    configStore: MockConfigStore(),
  );
  state.token = 'mock-token';
  state.userInfo = UserInfo.fromJson(const {
    'username': '1289371123@168.com',
    'nick': '用户JHSJD98',
    'uuid': 'test-uuid-1234-5678',
    'points': 1000,
    'country': 'CN',
  });
  return state;
}

Widget wrapVisualTest({
  required Widget child,
  AppState? state,
  Size size = const Size(1000, 700),
  ThemeData? theme,
  Alignment? alignment,
}) {
  final appState = state ?? createMockAppState();
  // A SizedBox hands its child *tight* constraints, so a widget that sizes
  // itself (Sidebar's width: 230, StatusBar's height: 80) is stretched to the
  // canvas instead. Aligning inside it restores loose constraints, which is
  // what any test asserting a widget's own size needs.
  final content = alignment == null
      ? child
      : Align(alignment: alignment, child: child);
  return MaterialApp(
    theme: theme ?? buildLuxwapThemeData(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: AppScope(
            state: appState,
            child: content,
          ),
        ),
      ),
    ),
  );
}

/// Pumps [child] onto a surface sized exactly to [size] at 1x pixel ratio.
///
/// Without this the widget is laid out against the 800x600 default test view,
/// so anything wider silently overflows and the captured golden no longer
/// matches what the app renders. The view is restored after each test.
Future<void> pumpVisual(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(1000, 700),
  AppState? state,
  ThemeData? theme,
  Alignment? alignment,
  Duration? settleAfter,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    wrapVisualTest(
      child: child,
      state: state,
      size: size,
      theme: theme,
      alignment: alignment,
    ),
  );
  if (settleAfter == null) {
    await tester.pumpAndSettle();
  } else {
    // pumpAndSettle never returns for a widget that animates forever — a
    // progress spinner, a blinking text cursor. Advance a fixed amount instead
    // so the frame captured is deterministic.
    await tester.pump(settleAfter);
  }
}

/// A [LocalFileComparator] that accepts differences below [tolerance].
///
/// Goldens are platform-dependent: font rasterisation and anti-aliasing differ
/// between the macOS CI runner and a Windows dev machine, which shows up as a
/// sub-percent diff on every text-bearing widget. An exact-match comparator
/// therefore fails the whole suite for reasons unrelated to the UI. Real
/// regressions move far more pixels than [tolerance] and still fail.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  /// Maximum fraction of differing pixels still treated as a pass (0.5%).
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// Installs [TolerantGoldenComparator] for the current test file.
///
/// Call from `setUpAll` in any suite that uses `matchesGoldenFile`.
void useTolerantGoldens({double tolerance = 0.005}) {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      Uri.parse('${current.basedir}test.dart'),
      tolerance: tolerance,
    );
  }
}

/// Notes which Figma node a widget was checked against.
///
/// This is documentation attached to the run, not a verdict: whether the widget
/// actually matches is decided by the `expect`/`matchesGoldenFile` calls in the
/// test body, and a failure there fails the test. An earlier version of this
/// class carried a hardcoded `isMatched: true`, so the summary printed
/// "✅ 一致" for every entry even when the assertions had failed.
class VisualAuditRecord {
  const VisualAuditRecord({
    required this.component,
    required this.figmaSpec,
    required this.actualRender,
    this.details = '',
  });

  /// Widget under test, ideally with its Figma node id.
  final String component;

  /// What the design file specifies.
  final String figmaSpec;

  /// What the widget renders.
  final String actualRender;

  /// Which assertion covers the comparison.
  final String details;

  void printReport() {
    final lines = [
      '------------------------------------------------------------',
      '【组件比对】: $component',
      '  [原型规范] : $figmaSpec',
      '  [实际渲染] : $actualRender',
      if (details.isNotEmpty) '  [覆盖断言] : $details',
    ];
    for (final line in lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}

void printAuditSummary(String title, List<VisualAuditRecord> records) {
  final header = [
    '',
    '============================================================',
    '       $title        ',
    '  ${records.length} 项已覆盖 · 通过与否以上方测试结果为准',
    '============================================================',
  ];
  for (final line in header) {
    // ignore: avoid_print
    print(line);
  }
  for (final r in records) {
    r.printReport();
  }
  // ignore: avoid_print
  print('\n============================================================\n');
}
