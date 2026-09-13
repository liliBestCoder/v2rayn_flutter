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
    TradeManagerPage(),
    SettingsPage(),
    HelpPage(),
    ActivityPage(),
    AboutPage(),
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
            Sidebar(
              selected: selected,
              onSelect: _select,
              onHelp: () => _select(4),
            ),
            Container(width: 1, color: const Color(0xFFEEEEEE)),
            Expanded(
              child: Column(
                children: [
                  if (selected != 4 && selected != 5 && selected != 6)
                    _UserHeader(
                      onTrade: () => setState(() => selected = 2),
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

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onHelp,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    const navItems = [
      (0, '线路'),
      (1, '个人中心'),
      (2, '交易记录'),
      (3, '设置'),
      (4, '帮助中心'),
      (5, '有礼活动'),
      (6, '关于'),
    ];

    return SizedBox(
      width: 230,
      child: Column(
        children: [
          Container(
            height: 200,
            alignment: Alignment.center,
            child: const LuxwapIcon(
              'icon-logo-blue',
              width: 120,
              height: 141,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in navItems) ...[
                    _NavButton(
                      index: item.$1,
                      selected: selected,
                      label: item.$2,
                      onTap: onSelect,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
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
    required this.onTap,
  });

  final int index;
  final int selected;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected == index;
    return SizedBox(
      width: 230,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (active)
            Positioned(
              left: 0,
              top: 5,
              bottom: 5,
              child: Container(
                width: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF286AFC),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(5),
                    bottomRight: Radius.circular(5),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 170,
            height: 50,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFE9F0FF)
                        : const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF286AFC)
                          : const Color(0xFF666666),
                      fontSize: 16,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
      height: 145,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nick,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2329),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '登录邮箱：$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      '账号等级：',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                    ),
                    Text(
                      level,
                      style: const TextStyle(fontSize: 14, height: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _HeaderActionButton(
                  label: '交易记录',
                  color: const Color(0xFF27C36A),
                  background: const Color(0xFFEBF8F0),
                  icon: Icons.receipt_long_rounded,
                  onPressed: onTrade,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Blue Traffic Card
          Container(
            width: 360,
            height: 125,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF286AFC), Color(0xFF3E98F3)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF286AFC).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '流量套餐信息',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    InkWell(
                      onTap: onRenew,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27C36A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '在线充值',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '已用流量 ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '$usedTraffic GB',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '总流量  80GB',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '有效期  $expiration',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                // Capsule progress bar with white rounded thumb knob
                LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    const trackHeight = 12.0;
                    const thumbWidth = 44.0;
                    final usedNum = double.tryParse(usedTraffic) ?? 0.0;
                    final factor = (usedNum / 80.0).clamp(0.0, 1.0);
                    final activeWidth =
                        (barWidth * factor).clamp(thumbWidth, barWidth);
                    return Container(
                      width: barWidth,
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            width: activeWidth,
                            height: trackHeight,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38B2FF), Colors.white],
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          Positioned(
                            left: (activeWidth - thumbWidth)
                                .clamp(0.0, barWidth - thumbWidth),
                            child: Container(
                              width: thumbWidth,
                              height: trackHeight,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}






