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
                padding: const EdgeInsets.fromLTRB(48, 44, 48, 44),
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
                              fontSize: 26,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '📝 分享有礼，1000人名额',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '晒软件心得 / 教程等至论坛、视频平台、社交媒体、博客等，提交页面链接（非私链，客服可直接打开。私链无奖励！）参与评审。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF555555),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        '🏆 奖项设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '一等奖(10 名): 1年VIP\n二等奖(20 名): 半年VIP\n三等奖(100 名): 季度VIP\n参与奖: 1个月 VIP',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF555555),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: '剩余名额：  ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF3D3D3D),
                                  ),
                                ),
                                TextSpan(
                                  text: '$remaining',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF286AFC),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: Container(
                            width: 510,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            child: _RewardTable(rows: rankRows),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: Container(
                            width: 510,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: auditLink,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                hintText: '提交链接',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB2B2B2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: SizedBox(
                            width: 140,
                            height: 54,
                            child: FilledButton(
                              onPressed: loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE9F0FF),
                                foregroundColor: const Color(0xFF286AFC),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                loading ? '提交中' : '发送',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
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
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1F2329),
    );
    const bodyStyle = TextStyle(
      fontSize: 13,
      color: Color(0xFF555555),
    );

    final displayRows = rows.length >= 6
        ? rows.take(6).toList()
        : [
            ...rows,
            ...List.generate(
              6 - rows.length,
              (_) => const _RankRow(
                name: 'User***Name',
                date: '2025-12-09',
                reward: '参与奖',
              ),
            ),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 12),
          child: Row(
            children: [
              SizedBox(width: 8),
              Expanded(flex: 7, child: Text('用户名', style: headerStyle)),
              Expanded(flex: 7, child: Text('有效期', style: headerStyle)),
              Expanded(flex: 4, child: Text('奖励', style: headerStyle)),
            ],
          ),
        ),
        for (final row in displayRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(flex: 7, child: Text(row.name, style: bodyStyle)),
                Expanded(flex: 7, child: Text(row.date, style: bodyStyle)),
                Expanded(flex: 4, child: Text(row.reward, style: bodyStyle)),
              ],
            ),
          ),
      ],
    );
  }
}
