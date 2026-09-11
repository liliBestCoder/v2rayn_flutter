import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import 'about_page.dart';
import 'activity_page.dart';
import 'dns_settings_page.dart';
import 'help_page.dart';
import 'lines_page.dart';
import 'personal_center_page.dart';
import 'settings_page.dart';
import 'trade_manager_page.dart';
import '../theme/luxwap_theme.dart';
import '../widgets/luxwap_icon.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int selected = 0;
  Timer? _paymentPollTimer;
  Timer? _trafficTimer;
  String? _submitToken;

  final pages = const [
    LinesPage(),
    PersonalCenterPage(),
    SettingsPage(),
    TradeManagerPage(),
    ActivityPage(),
    AboutPage(),
    HelpPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTrafficTimer();
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    _trafficTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startTrafficTimer() {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(hours: 1), (_) {
      AppScope.of(context).refreshUserInfo();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _paymentPollTimer?.cancel();
      _paymentPollTimer = null;
      _trafficTimer?.cancel();
      _trafficTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_submitToken != null && _paymentPollTimer == null) {
        _startPaymentPolling();
      }
      if (_trafficTimer == null) {
        _startTrafficTimer();
      }
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Row(
          children: [
            _Sidebar(
              selected: selected,
              onSelect: _select,
              onHelp: () => _select(6),
            ),
            Container(width: 1, color: LuxwapColors.divider),
            Expanded(
              child: Column(
                children: [
                  if (selected != 4 && selected != 5 && selected != 6)
                    _UserHeader(
                      onTrade: () => setState(() => selected = 3),
                      onRenew: () { _startPaymentPolling(); _openRenewPage(); },
                    ),
                  Expanded(
                    child: IndexedStack(index: selected, children: pages),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(int index) {
    if (index >= pages.length) {
      return;
    }
    setState(() => selected = index);
  }

static String _generateUuid() {
    final r = Random();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  void _startPaymentPolling() {
    _paymentPollTimer?.cancel();
    _submitToken = _generateUuid();
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkPaymentStatus());
  }

  void _stopPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    _submitToken = null;
  }

  Future<void> _checkPaymentStatus() async {
    final app = AppScope.of(context);
    final token = app.token;
    final submitToken = _submitToken;
    if (token == null || token.isEmpty || submitToken == null || submitToken.isEmpty) {
      _stopPaymentPolling();
      return;
    }
    try {
      final result = await app.api.orderStatusBySubmitToken(submitToken, token);
      if (!result.success) {
        // 订单尚未创建，继续轮�?        return;
      }
      final data = result.data;
      if (data is! Map) return;
      final status = data['status']?.toString() ?? '';
      if (status == 'SUCCESS') {
        await app.refreshUserInfo();
        _stopPaymentPolling();
      } else if (status == 'FAILED' || status == 'CLOSED') {
        _stopPaymentPolling();
      }
    } catch (_) {}
  }

  Future<void> _openRenewPage() async {
    final token = AppScope.of(context).token;
    if (token == null || token.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("请先登录")),
        );
      }
      return;
    }
    final sToken = _submitToken ?? "";
    final params = <String, String>{"token": token};
    if (sToken.isNotEmpty) params["submitToken"] = sToken;
    final url = Uri.parse("http://101.201.215.20:8000/pay").replace(queryParameters: params).toString();
    try {
      if (Platform.isWindows) {
        await Process.start("rundll32", ["url.dll,FileProtocolHandler", url], runInShell: false);
      } else if (Platform.isMacOS) {
        await Process.start("open", [url], runInShell: false);
      } else {
        await Process.start("xdg-open", [url], runInShell: false);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("无法打开续费页面")),
        );
      }
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.onHelp,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: LuxwapColors.brand50,
                    borderRadius: LuxwapRadius.rSm,
                  ),
                  child: const LuxwapIcon('icon-logo-blue', size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Luxwap',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: LuxwapColors.brand500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          _NavButton(
            index: 0,
            selected: selected,
            label: '线路',
            icon: 'icon-rocket',
            onTap: onSelect,
          ),
          _NavButton(
            index: 1,
            selected: selected,
            label: '个人中心',
            icon: 'icon-star',
            onTap: onSelect,
          ),
          _NavButton(
            index: 2,
            selected: selected,
            label: '设置',
            icon: 'icon-gear',
            onTap: onSelect,
          ),
          _NavButton(
            index: 6,
            selected: selected,
            label: '帮助',
            icon: 'icon-clipboard',
            onTap: onSelect,
          ),
          _NavButton(
            index: 5,
            selected: selected,
            label: '关于',
            icon: 'icon-cloud',
            onTap: onSelect,
          ),
          _NavButton(
            index: 4,
            selected: selected,
            label: '有礼活动',
            icon: 'icon-turkey',
            onTap: onSelect,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'v2.0 PC 专业版',
              style: TextStyle(
                fontSize: 11,
                color: LuxwapColors.neutral400,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.index,
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final int index;
  final int selected;
  final String label;
  final String icon;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: LuxwapRadius.rSm,
          hoverColor: LuxwapColors.neutral100,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? LuxwapColors.brand50 : Colors.transparent,
              borderRadius: LuxwapRadius.rSm,
              border: Border.all(
                color: active
                    ? LuxwapColors.brand500.withValues(alpha: 0.18)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                LuxwapIcon(
                  icon,
                  size: 16,
                  color: active
                      ? LuxwapColors.brand500
                      : LuxwapColors.neutral600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? LuxwapColors.brand500
                          : LuxwapColors.neutral800,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 4,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: LuxwapColors.brand500,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.onTrade, required this.onRenew});

  static const _renewUrl = 'http://101.201.215.20:8000/pay';

  final VoidCallback onTrade;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).userInfo;
    final username = user?.username.isNotEmpty == true ? user!.username : '-';
    final nick = user?.nick.isNotEmpty == true ? user!.nick : username;
    final expiration =
        user?.expiration.isNotEmpty == true ? user!.expiration : '-';
    final usedTraffic =
        user?.usedTraffic.isNotEmpty == true ? user!.usedTraffic : '0';
    final level = _levelSymbols(user?.cumulativeMonths ?? 0);

    return Container(
      height: 138,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LuxwapColors.divider)),
        color: LuxwapColors.neutral0,
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 30, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 310),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nick,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff1b1b1b),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登录邮箱：$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xff777777), fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        '账号等级：',
                        style: TextStyle(color: Color(0xff777777), fontSize: 11),
                      ),
                      Text(
                        level,
                        style: const TextStyle(fontSize: 12, height: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _HeaderActionButton(
                        label: '交易记录',
                        color: const Color(0xff24a848),
                        background: const Color(0xffe9f7ee),
                        icon: Icons.receipt_long_outlined,
                        onPressed: onTrade,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 285,
            height: 64,
            decoration: BoxDecoration(
              color: LuxwapColors.brand500,
              borderRadius: LuxwapRadius.rMd,
              boxShadow: [
                BoxShadow(
                  color: LuxwapColors.brand500.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$expiration / 有效期',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '使用流量：$usedTraffic (MB)',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 62,
                  height: 30,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      foregroundColor: LuxwapColors.brand500,
                      shape: RoundedRectangleBorder(
                          borderRadius: LuxwapRadius.rLg),
                    ),
                    onPressed: onRenew,
                    child: const Text(
                      '续费',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _levelSymbols(int months) {
    var stars = months;
    final moons = stars ~/ 6;
    stars %= 6;
    final suns = moons ~/ 6;
    final restMoons = moons % 6;
    final crowns = suns ~/ 6;
    final restSuns = suns % 6;

    final result = StringBuffer()
      ..write('👑' * crowns)
      ..write('☀️' * restSuns)
      ..write('🌙' * restMoons)
      ..write('⭐' * stars);
    return result.isEmpty ? '无' : result.toString();
  }


}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: label.length > 4 ? 126 : 92,
      height: 32,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






