import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'app_toast.dart';
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'services/api_service.dart';
import 'services/token_store.dart';
import 'theme/luxwap_theme.dart';

void main() {
  runApp(const LuxwapApp());
}

class LuxwapApp extends StatefulWidget {
  const LuxwapApp({super.key});

  @override
  State<LuxwapApp> createState() => _LuxwapAppState();
}

class _LuxwapAppState extends State<LuxwapApp> {
  static const _windowChannel = MethodChannel('luxwap/window');

  late final ApiService api;
  late final AppState appState;
  bool loading = true;
  bool? _lastLoggedIn;

  @override
  void initState() {
    super.initState();
    api = ApiService();
    appState = AppState(api: api, tokenStore: TokenStore());
    appState.addListener(_onAppStateChanged);
    _setupWindowChannelHandler();
    _bootstrap();
  }

  void _setupWindowChannelHandler() {
    _windowChannel.setMethodCallHandler((call) async {
      if (call.method == 'onTrayAction') {
        final action = call.arguments?.toString();
        if (action == 'closeToTray_true') {
          await appState.updateClientConfig(
            appState.clientConfig.copyWith(closeToTray: true),
          );
        } else if (action == 'closeToTray_false') {
          await appState.updateClientConfig(
            appState.clientConfig.copyWith(closeToTray: false),
          );
        }
      }
    });
  }

  void _onAppStateChanged() {
    final currentLoggedIn = appState.isLoggedIn;
    if (_lastLoggedIn != currentLoggedIn) {
      _lastLoggedIn = currentLoggedIn;
      _syncWindowSize(currentLoggedIn);
    }
  }

  Future<void> _bootstrap() async {
    await appState.loadSession();
    _lastLoggedIn = appState.isLoggedIn;
    await _syncWindowSize(appState.isLoggedIn);
    await _syncCloseToTray();
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _syncCloseToTray() async {
    try {
      await _windowChannel.invokeMethod('setCloseToTray', {
        'enabled': appState.clientConfig.closeToTray,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<void> _syncWindowSize(bool loggedIn) async {
    try {
      await _windowChannel.invokeMethod('setSize', {
        'width': loggedIn ? 1194 : 440,
        'height': loggedIn ? 850 : 720,
        'center': true,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: appState,
      child: MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Luxwap',
        theme: buildLuxwapThemeData(),
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
