import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/models/user_info.dart';
import 'package:v2rayn_flutter/pages/personal_center_page.dart';
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
  testWidgets('PersonalCenterPage renders PointsCard and 2x2 FeatureCards', (WidgetTester tester) async {
    final state = AppState(
      api: ApiService(baseUrl: 'http://127.0.0.1:8080'),
      tokenStore: MockTokenStore(),
    );
    state.userInfo = const UserInfo(
      uuid: 'user-uuid-12345',
      username: 'user@example.com',
      email: 'user@example.com',
      nick: 'TestUser',
      country: 'CN',
      expiration: '2026-12-31',
      usedTraffic: '1024',
      cumulativeMonths: 6,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppScope(
            state: state,
            child: const PersonalCenterPage(),
          ),
        ),
      ),
    );

    // Verify Points card is at the top of content
    expect(find.text('我的积分：'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('LV1 会员'), findsOneWidget);
    expect(find.text('1000 / 3000'), findsOneWidget);
    expect(find.text('积分兑换'), findsOneWidget);

    // Verify User Profile
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('user-uuid-12345'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('TestUser'), findsOneWidget);

    // Verify 4 Feature Cards in 2x2 grid
    expect(find.text('高匿匿名'), findsOneWidget);
    expect(find.text('隧道自由'), findsOneWidget);
    expect(find.text('弹性并发'), findsOneWidget);
    expect(find.text('安全稳定'), findsOneWidget);
  });
}
