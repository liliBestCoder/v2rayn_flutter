import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../app_toast.dart';
import 'change_password_dialog.dart';

class PersonalCenterPage extends StatelessWidget {
  const PersonalCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.userInfo;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const SizedBox(height: 20),
          const Text(
            '个人资料',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xff1b1b1b),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffdddddd)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                _ProfileRow(
                  label: '用户ID',
                  value: user?.uuid ?? '',
                  trailing: IconButton(
                    tooltip: '复制用户ID',
                    icon: const Icon(
                      Icons.copy,
                      size: 24,
                      color: Color(0xff8d91a3),
                    ),
                    onPressed: () {
                      final uuid = user?.uuid ?? '';
                      if (uuid.isEmpty) {
                        return;
                      }
                      Clipboard.setData(ClipboardData(text: uuid));
                      showAppToast('用户ID已复制', success: true);
                    },
                  ),
                ),
                _ProfileRow(
                  label: '登录邮箱',
                  value: user?.username ?? '',
                  actionText: '更换邮箱',
                  onAction: () => _showEmailDialog(context),
                ),
                _ProfileRow(
                  label: '用户昵称',
                  value: user?.nick ?? '',
                  actionText: '编辑昵称',
                  onAction: () => _showNickDialog(context, user?.nick ?? ''),
                ),
                _ProfileRow(
                  label: '国家',
                  value: user?.country ?? '',
                  actionText: '修改',
                  onAction: () =>
                      _showCountryDialog(context, user?.country ?? ''),
                ),
                _ProfileRow(
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
          Center(
            child: SizedBox(
              width: 115,
              height: 34,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff2a80ff),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => _showLogoutDialog(context),
                child: const Text('退出登录'),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Wrap(
            spacing: 40,
            runSpacing: 15,
            alignment: WrapAlignment.center,
            children: [
              _FeatureCard(
                title: '高匿匿名',
                subtitle: 'HTTPS/CHACHA20加密访问',
                iconAsset: 'assets/images/privacy_icon.png',
              ),
              _FeatureCard(
                title: '隧道自由',
                subtitle: '灵活调节线路',
                iconAsset: 'assets/images/tunel_icon.png',
              ),
              _FeatureCard(
                title: '弹性并发',
                subtitle: '超大带宽，弹性并发',
                iconAsset: 'assets/images/concurrency_icon.png',
              ),
              _FeatureCard(
                title: '安全稳定',
                subtitle: '数据传输稳定可靠',
                iconAsset: 'assets/images/guard_icon.png',
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
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
      height: 60,
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
                    fontWeight: FontWeight.bold,
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
                SizedBox(width: 100, child: Center(child: trailing)),
              if (actionText != null)
                SizedBox(
                  width: 100,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: SizedBox(
                        height: 32,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xfff7f7f8),
                            foregroundColor: const Color(0xff1b1b1b),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: onAction,
                          child: Text(
                            actionText!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (showDivider)
            const Positioned(
              left: 15,
              right: 15,
              bottom: 0,
              child: Divider(height: 1, color: Color(0xffeeeeee)),
            ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
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
      width: 320,
      height: 85,
      decoration: BoxDecoration(
        color: const Color(0xffeaeaec),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(fontSize: 18, color: Color(0xff2a2a2a)),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xffa7a7a8)),
                ),
              ],
            ),
          ),
          Image.asset(iconAsset, width: 56, height: 56, fit: BoxFit.contain),
        ],
      ),
    );
  }
}
