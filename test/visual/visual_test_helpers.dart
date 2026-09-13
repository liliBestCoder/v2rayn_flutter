import 'package:flutter/material.dart';
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
}) {
  final appState = state ?? createMockAppState();
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
            child: child,
          ),
        ),
      ),
    ),
  );
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

void printAuditSummary(String title, List<VisualAuditRecord> records) {
  // ignore: avoid_print
  print('\n============================================================');
  // ignore: avoid_print
  print('       $title        ');
  // ignore: avoid_print
  print('============================================================');
  for (final r in records) {
    r.printReport();
  }
  // ignore: avoid_print
  print('\n============================================================\n');
}
