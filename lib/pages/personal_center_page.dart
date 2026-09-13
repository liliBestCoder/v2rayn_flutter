import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../app_toast.dart';
import '../theme/luxwap_theme.dart';
import 'change_password_dialog.dart';

class PersonalCenterPage extends StatelessWidget {
  const PersonalCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.userInfo;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(40, 14, 40, 14),
      child: ListView(
        children: [
          const Text(
            '积分',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          const PointsCard(),
          const SizedBox(height: 14),
          const Text(
            '个人资料',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFEEEEEE)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ProfileRow(
                  label: '登录邮箱',
                  value: user?.username ?? '1289371123@168.com',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '复制邮箱',
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: Color(0xFF286AFC),
                        ),
                        onPressed: () {
                          final em = user?.username ?? '';
                          if (em.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: em));
                            showAppToast('邮箱已复制', success: true);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _PillButton(
                        text: '更换邮箱',
                        onTap: () => _showEmailDialog(context),
                      ),
                    ],
                  ),
                ),
                ProfileRow(
                  label: '用户昵称',
                  value: user?.nick ?? '用户JHSJD98',
                  actionText: '修改昵称',
                  onAction: () => _showNickDialog(context, user?.nick ?? ''),
                ),
                ProfileRow(
                  label: '密码',
                  value: '••••••••',
                  actionText: '修改密码',
                  onAction: () => showDialog(
                    context: context,
                    builder: (_) => const ChangePasswordDialog(),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Logout button (Figma: 160x40, r=20, fill=#297CE7)
          Center(
            child: SizedBox(
              width: 160,
              height: 40,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF297CE7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => _showLogoutDialog(context),
                child: const Text('退出登录'),
              ),
            ),
          ),
          const SizedBox(height: 56),
          // Feature cards grid (Frame 63: 4 cards, r=16, fill=#F7F7F8)
          const Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FeatureCard(
                      title: '高匿名',
                      subtitle: 'HTTPS/CHACHA20加密访问',
                      iconAsset: 'assets/images/privacy_icon.png',
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: FeatureCard(
                      title: '隧道自由',
                      subtitle: '灵活调节线路',
                      iconAsset: 'assets/images/tunel_icon.png',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FeatureCard(
                      title: '弹性并发',
                      subtitle: '超大带宽，弹性并发',
                      iconAsset: 'assets/images/concurrency_icon.png',
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: FeatureCard(
                      title: '安全稳定',
                      subtitle: '数据传输稳定可靠',
                      iconAsset: 'assets/images/guard_icon.png',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) {
      return;
    }
    await AppScope.of(context).logout();
    showAppToast('已退出登录', success: true);
  }

  Future<void> _showNickDialog(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    await _showUpdateDialog(
      context: context,
      title: '编辑昵称',
      fields: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '新昵称'),
        ),
      ],
      onSubmit: () async {
        final state = AppScope.of(context);
        final token = state.token;
        if (token == null) return;
        final result = await state.api.updateUserInfo(
          token: token,
          nick: controller.text.trim(),
        );
        if (result.success) {
          await state.refreshUserInfo();
        }
        showAppToast(
          result.success ? '昵称修改成功' : result.msg,
          success: result.success,
        );
        if (context.mounted && result.success) Navigator.pop(context);
      },
    );
    controller.dispose();
  }

  Future<void> _showEmailDialog(BuildContext context) async {
    final email = TextEditingController();
    final code = TextEditingController();
    await _showUpdateDialog(
      context: context,
      title: '更换邮箱',
      fields: [
        TextField(
          controller: email,
          decoration: const InputDecoration(labelText: '新邮箱'),
        ),
        TextField(
          controller: code,
          decoration: const InputDecoration(labelText: '验证码'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () async {
              final state = AppScope.of(context);
              final token = state.token;
              final value = email.text.trim();
              if (token == null || value.isEmpty) return;
              final result = await state.api.sendCode(value, token: token);
              showAppToast(
                result.success ? '验证码已发送' : result.msg,
                success: result.success,
              );
            },
            child: const Text('发送验证码'),
          ),
        ),
      ],
      onSubmit: () async {
        final state = AppScope.of(context);
        final token = state.token;
        if (token == null) return;
        final result = await state.api.updateUserInfo(
          token: token,
          username: email.text.trim(),
          verifyCode: code.text.trim(),
        );
        if (result.success) {
          await state.refreshUserInfo();
        }
        showAppToast(
          result.success ? '邮箱修改成功' : result.msg,
          success: result.success,
        );
        if (context.mounted && result.success) Navigator.pop(context);
      },
    );
    email.dispose();
    code.dispose();
  }

  Future<void> _showCountryDialog(BuildContext context, String current) async {
    const countries = [
      ('CN', '中国'),
      ('RU', '俄罗斯'),
      ('TM', '土库曼斯坦'),
      ('IN', '印度'),
      ('TR', '土耳其'),
      ('VN', '越南'),
      ('IR', '伊朗'),
      ('SA', '沙特阿拉伯'),
      ('MM', '缅甸'),
      ('EG', '埃及'),
      ('PK', '巴基斯坦'),
      ('AE', '阿联酋'),
      ('CU', '古巴'),
      ('UZ', '乌兹别克斯坦'),
      ('BD', '孟加拉国'),
      ('KP', '朝鲜'),
      ('ER', '厄立特里亚'),
    ];
    var selected = current.isEmpty ? countries.first.$1 : current;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('修改国家'),
            content: SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                initialValue: countries.any((c) => c.$1 == selected)
                    ? selected
                    : countries.first.$1,
                decoration: const InputDecoration(labelText: '国家'),
                items: countries
                    .map((c) => DropdownMenuItem(
                          value: c.$1,
                          child: Text(c.$2),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selected = v ?? selected),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  final state = AppScope.of(dialogContext);
                  final token = state.token;
                  if (token == null) return;
                  final result = await state.api.updateUserInfo(
                    token: token,
                    country: selected,
                  );
                  if (result.success) {
                    await state.refreshUserInfo();
                  }
                  showAppToast(
                    result.success ? '国家修改成功' : result.msg,
                    success: result.success,
                  );
                  if (dialogContext.mounted && result.success) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showUpdateDialog({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    required Future<void> Function() onSubmit,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: fields),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: onSubmit, child: const Text('保存')),
        ],
      ),
    );
  }
}

class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.label,
    required this.value,
    this.actionText,
    this.trailing,
    this.onAction,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final String? actionText;
  final Widget? trailing;
  final VoidCallback? onAction;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 15),
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xff1b1b1b),
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: trailing!,
                ),
              if (actionText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: _PillButton(
                    text: actionText!,
                    onTap: onAction ?? () {},
                  ),
                ),
            ],
          ),
          if (showDivider)
            const Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: Divider(height: 1, color: Color(0xFFF5F5F7)),
            ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF333333),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class PointsCard extends StatelessWidget {
  const PointsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    '等级',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111111),
                    ),
                  ),
                  SizedBox(width: 14),
                  Text('👑 🌞 🌙 ⭐ ⭐', style: TextStyle(fontSize: 15)),
                ],
              ),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('积分兑换功能开发中')),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: Color(0xFFFF8800)),
                    SizedBox(width: 4),
                    Text(
                      '积分换流量>>',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFF8800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '下一级',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF666666),
                    ),
                  ),
                  Text(
                    '1000/3000',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  const trackHeight = 12.0;
                  const thumbWidth = 24.0;
                  const factor = 1000 / 3000;
                  final activeWidth =
                      (barWidth * factor).clamp(thumbWidth, barWidth);
                  return Container(
                    width: barWidth,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFDFDF),
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
                              colors: [Color(0xFF3E98F3), Color(0xFF286AFC)],
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
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 3,
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
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
  });

  final String title;
  final String subtitle;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xfff7f7f8),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff1b1b1b),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xff666666),
                  ),
                ),
              ],
            ),
          ),
          Image.asset(iconAsset, width: 44, height: 44, fit: BoxFit.contain),
        ],
      ),
    );
  }
}
