import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_toast.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final oldPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = AppScope.of(context);
    final token = state.token;
    if (token == null) {
      return;
    }
    if (newPassword.text.isEmpty || confirmPassword.text.isEmpty) {
      showAppToast('请填写新密码和确认密码', success: false);
      return;
    }
    if (newPassword.text != confirmPassword.text) {
      showAppToast('两次输入的新密码不一致', success: false);
      return;
    }
    setState(() => loading = true);
    final result = await state.api.changePassword(
      token: token,
      oldPassword: oldPassword.text,
      newPassword: newPassword.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => loading = false);
    showAppToast(result.success ? '密码修改成功' : result.msg, success: result.success);
    if (result.success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改密码'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPassword, obscureText: true, decoration: const InputDecoration(labelText: '旧密码')),
            TextField(controller: newPassword, obscureText: true, decoration: const InputDecoration(labelText: '新密码')),
            const SizedBox(height: 8),
            TextField(controller: confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: '确认新密码')),
            if (loading) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: loading ? null : _submit, child: const Text('保存')),
      ],
    );
  }
}
