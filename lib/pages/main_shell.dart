import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/user_info.dart';
import 'about_page.dart';
import 'activity_page.dart';
import 'help_page.dart';
import 'lines_page.dart';
import 'personal_center_page.dart';
import 'settings_page.dart';
import 'trade_manager_page.dart';
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
            Container(width: 1, color: const Color(0xFFDFDFDF)),
            Expanded(
              child: Column(
                children: [
                  if (selected != 4 && selected != 5 && selected != 6)
                    _UserHeader(
                      onTrade: () => setState(() => selected = 2),
                      onRenew: () {
                        _startPaymentPolling();
                        _openRenewPage();
                      },
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
    _paymentPollTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _checkPaymentStatus());
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
    if (token == null ||
        token.isEmpty ||
        submitToken == null ||
        submitToken.isEmpty) {
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
    final url = Uri.parse("http://101.201.215.20:8000/pay")
        .replace(queryParameters: params)
        .toString();
    try {
      if (Platform.isWindows) {
        await Process.start("rundll32", ["url.dll,FileProtocolHandler", url],
            runInShell: false);
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
            height: 250,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 149,
              height: 263,
              child: Center(
                child: LuxwapIcon(
                  'icon-logo-blue',
                  width: 120,
                  height: 141,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  for (var i = 0; i < navItems.length; i++) ...[
                    _NavButton(
                      index: navItems[i].$1,
                      selected: selected,
                      label: navItems[i].$2,
                      onTap: onSelect,
                    ),
                    if (i != navItems.length - 1) const SizedBox(height: 24),
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
                          : const Color(0xFF3D3D3D),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
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
    final total = user?.totalTraffic ?? UserInfo.kDefaultTotalTrafficGb;
    final totalTrafficLabel =
        '${total == total.roundToDouble() ? total.round() : total}GB';
    final level = _levelSymbols(user?.cumulativeMonths ?? 0);

    return Container(
      height: 263,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDFDFDF), width: 1)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(42, 42, 42, 41),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Figma lays the header out as 406 (info) + 42 (gap) + 399 (card)
          // inside a 916pt content column, so the card owns ~49.5% of the pair.
          // Holding that share means the info block and the card lose width at
          // the same rate instead of the card hitting a floor and the info
          // block absorbing every further pixel.
          const gap = 42.0;
          final pairWidth = (constraints.maxWidth - gap).clamp(0.0, 916.0);
          final cardWidth = (pairWidth * 0.495).clamp(300.0, 399.0);
          return Row(
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
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '登录邮箱：$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          '账号等级：',
                          style:
                              TextStyle(color: Color(0xFF666666), fontSize: 18),
                        ),
                        Text(
                          level,
                          style: const TextStyle(fontSize: 18, height: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _HeaderActionButton(
                      label: '交易记录',
                      color: const Color(0xFF27A53C),
                      background: const Color(0xFFE9F6EC),
                      icon: const LuxwapIcon(LuxwapIcons.copy, size: 20),
                      onPressed: onTrade,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: gap),
              // Blue Traffic Card
              Container(
                width: cardWidth,
                height: 180,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3E98F3), Color(0xFF2A72E1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
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
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        InkWell(
                          onTap: onRenew,
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3EF362), Color(0xFF00A721)],
                              ),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Text(
                              '充值中心',
                              style: TextStyle(
                                color: Color(0xFFF7F7F8),
                                fontSize: 16,
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
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$usedTraffic GB',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                  text: '总流量',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              const TextSpan(text: '  '),
                              TextSpan(
                                  text: totalTrafficLabel,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400)),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                  text: '有效期',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              const TextSpan(text: '  '),
                              TextSpan(
                                  text: expiration,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Capsule progress bar: white track, blue gradient fill
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth = constraints.maxWidth;
                        const trackHeight = 23.0;
                        final factor = user?.trafficFactor ?? 0.0;
                        final activeWidth = (barWidth * factor).clamp(0.0, barWidth);
                        return Container(
                          width: barWidth,
                          height: trackHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                                    colors: [
                                      Color(0xFF92C7FF),
                                      Color(0xFF29A4FF),
                                      Color(0xFF218AFF),
                                    ],
                                    stops: [0.0, 0.51, 1.0],
                                  ),
                                  borderRadius: BorderRadius.circular(100),
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
          );
        },
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
  final Widget icon;
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
            ColorFiltered(
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              child: icon,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
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
