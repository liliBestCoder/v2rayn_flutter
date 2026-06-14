import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_toast.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final auditLink = TextEditingController();
  bool loading = false;
  int remaining = 520;
  List<_RankRow> rankRows = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRankList();
  }

  @override
  void dispose() {
    auditLink.dispose();
    super.dispose();
  }

  Future<void> _loadRankList() async {
    final state = AppScope.of(context);
    final token = state.token;
    if (token == null || token.isEmpty) return;
    try {
      final result = await state.api.activityRankList(token);
      if (!result.success || result.data is! Map) return;
      final data = result.data as Map;
      remaining = data['rest'] ?? remaining;
      final list = data['rankList'];
      if (list is List) {
        rankRows = list.map((item) {
          final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
          final rank = map['rank']?.toString() ?? '';
          final reward = _rewardLabel(int.tryParse(rank) ?? 0);
          return _RankRow(
            name: _maskName(map['userName']?.toString() ?? '-'),
            date: map['expiration']?.toString() ?? '-',
            reward: reward,
          );
        }).toList();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  String _maskName(String name) {
    if (name.length <= 3) return name;
    final atIndex = name.indexOf('@');
    if (atIndex > 0) {
      // 邮箱：保留前3位 + *** + @域名
      final prefix = name.substring(0, atIndex);
      final domain = name.substring(atIndex);
      if (prefix.length <= 3) return '$prefix***$domain';
      return '${prefix.substring(0, 3)}***$domain';
    }
    // 用户名：保留前3 + *** + 后2
    if (name.length <= 5) return '${name.substring(0, 2)}***${name.substring(name.length - 1)}';
    return '${name.substring(0, 3)}***${name.substring(name.length - 2)}';
  }

  String _rewardLabel(int rank) {
    if (rank >= 1 && rank <= 10) return '一等奖';
    if (rank >= 11 && rank <= 30) return '二等奖';
    if (rank >= 31 && rank <= 130) return '三等奖';
    return '参与奖';
  }

  Future<void> _submit() async {
    final state = AppScope.of(context);
    final token = state.token;
    if (token == null) {
      showAppToast('请先登录');
      return;
    }
    final link = auditLink.text.trim();
    if (link.isEmpty) {
      showAppToast('请填写提交链接');
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      showAppToast('提交链接必须是 http 或 https 地址');
      return;
    }
    if (link.length > 500) {
      showAppToast('提交链接不能超过 500 个字符');
      return;
    }
    setState(() => loading = true);
    final result = await state.api.joinActivity(token, link);
    if (!mounted) {
      return;
    }
    setState(() => loading = false);
    showAppToast(result.success ? '提交成功' : result.msg, success: result.success);
    if (result.success) {
      auditLink.clear();
      _loadRankList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth - 68;
          return SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 58, 34, 44),
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: contentWidth,
                        child: const Center(
                          child: Text(
                            '分享有礼',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff111111)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        '分享有礼：1000 人名额',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff111111)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '晒软件心得 / 教程等至论坛、视频平台、社交媒体、博客等，提交页面链接（非私链，客服可直接打开。私链无奖励！）参与评审。',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff666666),
                            height: 1.45),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        '奖项设置',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff111111)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '一等奖(10 名): 1年VIP\n二等奖(20 名): 半年VIP\n三等奖(100 名): 季度VIP\n参与奖: 1个月 VIP',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff666666),
                            height: 1.35),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                    text: '剩余名额：',
                                    style: TextStyle(color: Color(0xff777777))),
                                TextSpan(
                                    text: '$remaining',
                                    style: const TextStyle(color: Color(0xff2b77ff))),
                              ],
                            ),
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                          width: contentWidth,
                          child: Center(
                            child: _RewardTable(rows: rankRows),
                          )),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: Container(
                            width: 520,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xfff3f6fb),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: auditLink,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '提交链接',
                                hintStyle: TextStyle(
                                    fontSize: 11, color: Color(0xff999999)),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xff111111)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: SizedBox(
                            width: 92,
                            height: 34,
                            child: TextButton(
                              onPressed: loading ? null : _submit,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: const Color(0xffe8f0ff),
                                foregroundColor: const Color(0xff2b77ff),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                loading ? '提交中' : '发送',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RankRow {
  const _RankRow({required this.name, required this.date, required this.reward});
  final String name;
  final String date;
  final String reward;
}

class _RewardTable extends StatelessWidget {
  const _RewardTable({required this.rows});
  final List<_RankRow> rows;

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff111111));
    const bodyStyle = TextStyle(fontSize: 11, color: Color(0xff111111));

    final displayRows = rows.length >= 5 ? rows : [
      ...rows,
      ...List.generate(5 - rows.length, (_) => const _RankRow(name: '-', date: '-', reward: '-')),
    ];

    return SizedBox(
      width: 520,
      height: 200,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xfff3f6fb),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(child: Center(child: Text('用户名', style: headerStyle))),
                  Expanded(child: Center(child: Text('有效期', style: headerStyle))),
                  Expanded(child: Center(child: Text('奖励', style: headerStyle))),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xffe1e4ec)),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: displayRows.map(
                  (row) => SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        Expanded(
                            child: Center(child: Text(row.name, style: bodyStyle))),
                        Expanded(
                            child: Center(child: Text(row.date, style: bodyStyle))),
                        Expanded(
                            child: Center(child: Text(row.reward, style: bodyStyle))),
                      ],
                    ),
                  ),
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
