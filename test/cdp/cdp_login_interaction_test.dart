import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/app_state.dart';
import 'package:v2rayn_flutter/pages/login_page.dart';
import 'package:v2rayn_flutter/services/api_service.dart';
import 'package:v2rayn_flutter/services/token_store.dart';

class MockTokenStore implements TokenStore {
  String? _token;
  @override
  Future<void> clear() async => _token = null;
  @override
  Future<String?> loadToken() async => _token;
  @override
  Future<void> saveToken(String token) async => _token = token;
}

void main() {
  group('CDP UI Integration Tests - Login Page Interactions', () {
    testWidgets('LoginPage dual tab and input layout test',
        (WidgetTester tester) async {
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

      // Verify dual tab items exist
      expect(find.text('账号登录'), findsWidgets);
      expect(find.text('账号注册'), findsOneWidget);

      // In login tab (mode 0), verify input hint texts
      expect(find.text('登录邮箱'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('登陆'), findsOneWidget);
      expect(find.text('免费试用'), findsOneWidget);

      // Tap "账号注册" tab
      await tester.tap(find.text('账号注册'));
      await tester.pumpAndSettle();

      // Now in register tab (mode 1)
      expect(find.text('输入邮箱'), findsOneWidget);
      expect(find.text('确认注册密码'), findsOneWidget);
      expect(find.text('验证邮箱'), findsOneWidget);

      // Switch back to "账号登录" tab
      await tester.tap(find.text('账号登录').first);
      await tester.pumpAndSettle();

      expect(find.text('登录邮箱'), findsOneWidget);
      expect(find.text('登陆'), findsOneWidget);
    });
  });
}
