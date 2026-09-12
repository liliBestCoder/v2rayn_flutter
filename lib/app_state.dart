import 'dart:io' show Platform, Process;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart';

import 'models/client_config.dart';
import 'models/user_info.dart';
import 'services/api_service.dart';
import 'services/client_config_store.dart';
import 'services/token_store.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    required this.tokenStore,
    ClientConfigStore? configStore,
  }) : configStore = configStore ?? ClientConfigStore();

  final ApiService api;
  final TokenStore tokenStore;
  final ClientConfigStore configStore;

  String? token;
  UserInfo? userInfo;
  ClientConfig clientConfig = const ClientConfig();

  bool get isLoggedIn => token != null && token!.isNotEmpty && userInfo != null;

  Future<void> loadSession() async {
    clientConfig = await configStore.load();
    token = await tokenStore.loadToken();
    if (token == null || token!.isEmpty) {
      return;
    }
    try {
      final result = await api.getUserInfo(token!);
      if (result.success && result.data is Map<String, dynamic>) {
        userInfo = UserInfo.fromJson(result.data as Map<String, dynamic>);
      } else {
        await logout();
      }
    } catch (_) {
      await logout();
    }
    notifyListeners();
  }

  Future<void> updateClientConfig(ClientConfig config) async {
    clientConfig = config;
    await configStore.save(config);
    notifyListeners();
  }

  Future<ApiResult> login(String username, String password) async {
    final deviceId = _deviceId();
    final os = _osName();
    final deviceName = '$os ${_archName()}';
    final result = await api.login(
      username: username,
      password: password,
      deviceId: deviceId,
      os: os,
      deviceType: 'desktop',
      deviceName: deviceName,
    );
    if (!result.success) {
      return result;
    }
    final data = result.data;
    if (data is String) {
      token = data;
    } else if (data is Map<String, dynamic>) {
      token = data['token']?.toString();
    }
    if (token != null && token!.isNotEmpty) {
      await tokenStore.saveToken(token!);
      final info = await api.getUserInfo(token!);
      if (info.success && info.data is Map<String, dynamic>) {
        userInfo = UserInfo.fromJson(info.data as Map<String, dynamic>);
      }
    }
    notifyListeners();
    return result;
  }

  Future<void> refreshUserInfo() async {
    if (token == null || token!.isEmpty) {
      return;
    }
    final result = await api.getUserInfo(token!);
    if (result.success && result.data is Map<String, dynamic>) {
      userInfo = UserInfo.fromJson(result.data as Map<String, dynamic>);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    userInfo = null;
    await tokenStore.clear();
    await cleanupNetwork();
    notifyListeners();
  }

  Future<void> cleanupNetwork() async {
    try {
      const MethodChannel('luxwap/window').invokeMethod('cleanProxy');
    } catch (_) {}
    try {
      const MethodChannel('luxwap/window').invokeMethod('killCore');
    } catch (_) {}
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/f', '/im', 'luxwap_core.exe'])
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await Process.run('taskkill', ['/f', '/im', 'xray.exe'])
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    } else {
      try {
        await Process.run('pkill', ['-f', 'luxwap_core'])
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await Process.run('pkill', ['-f', 'xray'])
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  static String _deviceId() {
    final host = Platform.localHostname;
    return host.isNotEmpty ? host : 'flutter-desktop';
  }

  static String _osName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return Platform.operatingSystem;
  }

  static String _archName() {
    return Platform.isMacOS ? 'Mac' : 'PC';
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppScope is missing');
    }
    return scope.notifier!;
  }
}
