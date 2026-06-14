import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import 'about_page.dart';
import 'activity_page.dart';
import 'dns_settings_page.dart';
import 'lines_page.dart';
import 'personal_center_page.dart';
import 'settings_page.dart';
import 'trade_manager_page.dart';

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
              onHelp: () => showDialog(
                context: context,
                builder: (_) => const DnsSettingsPage(),
              ),
            ),
            Container(width: 1, color: const Color(0xffe5e8ef)),
            Expanded(
              child: Column(
                children: [
                  if (selected != 4 && selected != 5)
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
      width: 160,
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 42),
              Image.asset('assets/images/logo.png', width: 64, height: 64),
              const SizedBox(height: 36),
              _NavButton(
                  index: 0, selected: selected, label: '线路', onTap: onSelect),
              _NavButton(
                  index: 1, selected: selected, label: '个人中心', onTap: onSelect),
              _NavButton(
                  index: 2, selected: selected, label: '设置', onTap: onSelect),
              _NavButton(
                  index: 6,
                  selected: selected,
                  label: '帮助',
                  onTap: (_) => onHelp()),
              _NavButton(
                  index: 5, selected: selected, label: '关于', onTap: onSelect),
              _NavButton(
                  index: 4, selected: selected, label: '有礼活动', onTap: onSelect),
            ],
          ),
          Positioned(
            left: 0,
            top: _activeIndicatorTop(selected),
            child: Container(
              width: 4,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xff2b77ff),
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _activeIndicatorTop(int index) {
    final effectiveIndex = switch (index) {
      0 => 0,
      1 => 1,
      2 => 2,
      6 => 3,
      5 => 4,
      4 => 5,
      _ => 0,
    };
    return 42 + 64 + 36 + effectiveIndex * 46 + 2;
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 94,
            height: 30,
            decoration: BoxDecoration(
              color: active ? const Color(0xffe8f0ff) : const Color(0xfff6f6f7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: active
                      ? const Color(0xff2b77ff)
                      : const Color(0xff1b1b1b),
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
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
        border: Border(bottom: BorderSide(color: Color(0xffedf0f5))),
        color: Colors.white,
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 30, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 310,
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
                    const SizedBox(width: 12),
                    _HeaderActionButton(
                      label: '积分兑换会员',
                      color: const Color(0xffff8a18),
                      background: const Color(0xfffff2e3),
                      icon: Icons.stars_outlined,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('积分兑换会员')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 250,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xff3b77fd),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.only(left: 16, right: 12),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '使用流量：$usedTraffic (MB)',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 58,
                  height: 26,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff2b61ff),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onRenew,
                    child: const Text(
                      '续费',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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






