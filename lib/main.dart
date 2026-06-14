import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'app_toast.dart';
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'services/api_service.dart';
import 'services/token_store.dart';

void main() {
  runApp(const V2rayNFlutterApp());
}

class V2rayNFlutterApp extends StatefulWidget {
  const V2rayNFlutterApp({super.key});

  @override
  State<V2rayNFlutterApp> createState() => _V2rayNFlutterAppState();
}

class _V2rayNFlutterAppState extends State<V2rayNFlutterApp> {
  static const _windowChannel = MethodChannel('luxwap/window');

  late final ApiService api;
  late final AppState appState;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    api = ApiService();
    appState = AppState(api: api, tokenStore: TokenStore());
    appState.addListener(_syncWindowSize);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await appState.loadSession();
    await _syncWindowSize();
    setState(() => loading = false);
  }

  @override
  void dispose() {
    appState.removeListener(_syncWindowSize);
    super.dispose();
  }

  Future<void> _syncWindowSize() async {
    if (!Platform.isWindows) {
      return;
    }
    final loggedIn = appState.isLoggedIn;
    try {
      await _windowChannel.invokeMethod('setSize', {
        'width': loggedIn ? 1194 : 420,
        'height': loggedIn ? 850 : 760,
        'center': true,
      });
    } catch (_) {
      // The Windows channel is only available in packaged desktop builds.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: appState,
      child: MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'v2rayN',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xfff6f8fc),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff2a80ff),
            primary: const Color(0xff2a80ff),
          ),
          useMaterial3: true,
          fontFamily: 'Microsoft YaHei',
        ),
        home: AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            if (loading) {
              return const _BootLoading();
            }
            return appState.isLoggedIn ? const MainShell() : const LoginPage();
          },
        ),
      ),
    );
  }
}

class _BootLoading extends StatelessWidget {
  const _BootLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
