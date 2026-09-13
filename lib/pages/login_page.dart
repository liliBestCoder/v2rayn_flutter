import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_toast.dart';
import '../theme/luxwap_theme.dart';
import '../widgets/luxwap_icon.dart';
import 'help_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _codePattern = RegExp(r'^\d{6}$');

  int mode = 0;
  bool loading = false;
  bool oauthLoading = false;
  String? notice;
  HttpServer? oauthCallbackServer;
  int registerCountdown = 0;
  int resetCountdown = 0;
  Timer? registerTimer;
  Timer? resetTimer;

  final loginEmail = TextEditingController();
  final loginPassword = TextEditingController();
  final registerEmail = TextEditingController();
  final registerPassword = TextEditingController();
  final registerConfirm = TextEditingController();
  final registerCode = TextEditingController();
  final resetEmail = TextEditingController();
  final resetPassword = TextEditingController();
  final resetConfirm = TextEditingController();
  final resetCode = TextEditingController();

  @override
  void dispose() {
    registerTimer?.cancel();
    resetTimer?.cancel();
    oauthCallbackServer?.close(force: true);
    for (final c in [
      loginEmail,
      loginPassword,
      registerEmail,
      registerPassword,
      registerConfirm,
      registerCode,
      resetEmail,
      resetPassword,
      resetConfirm,
      resetCode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    final username = loginEmail.text.trim();
    final password = loginPassword.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _toast('用户名或密码不能为空');
      return;
    }
    setState(() => loading = true);
    try {
      final state = AppScope.of(context);
      final result = await state.login(username, password);
      if (!mounted) {
        return;
      }
      setState(() => loading = false);
      if (result.success) {
        showAppToast('登录成功', success: true);
      } else {
        _toast(result.msg.isEmpty ? '登录失败' : result.msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _toast('登录失败：$e');
      }
    }
  }

  Future<void> _sendRegisterCode() async {
    if (!_validateRegisterBase()) {
      return;
    }
    setState(() => loading = true);
    final result =
        await AppScope.of(context).api.sendCode(registerEmail.text.trim());
    if (!mounted) {
      return;
    }
    setState(() => loading = false);
    if (result.success) {
      _startRegisterCountdown();
      setState(() {
        notice = null;
        mode = 3;
      });
    } else {
      _toast(result.msg.isEmpty ? '验证码发送失败' : result.msg);
    }
  }

  Future<void> _resendRegisterCode() async {
    if (registerCountdown > 0) {
      return;
    }
    await _sendRegisterCode();
  }

  Future<void> _confirmRegister() async {
    final code = registerCode.text.trim();
    if (!_validateRegisterBase()) {
      setState(() => mode = 1);
      return;
    }
    if (!_codePattern.hasMatch(code)) {
      _toast('验证码格式不正确');
      return;
    }
    setState(() => loading = true);
    final result = await AppScope.of(context).api.register(
          username: registerEmail.text.trim(),
          email: registerEmail.text.trim(),
          password: registerPassword.text.trim(),
          deviceId: _deviceId(),
          verifyCode: code,
        );
    if (!mounted) {
      return;
    }
    setState(() => loading = false);
    if (result.success) {
      loginEmail.text = registerEmail.text.trim();
      loginPassword.text = registerPassword.text.trim();
      registerEmail.clear();
      registerPassword.clear();
      registerConfirm.clear();
      registerCode.clear();
      registerTimer?.cancel();
      setState(() {
        registerCountdown = 0;
        mode = 0;
      });
      _toast('注册成功');
    } else {
      _toast(result.msg.isEmpty ? '注册失败' : result.msg);
    }
  }

  Future<void> _sendResetCode() async {
    final email = resetEmail.text.trim();
    if (email.isEmpty) {
      _toast('邮箱不能为空');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      _toast('邮箱格式不正确');
      return;
    }
    setState(() => loading = true);
    final result = await AppScope.of(context).api.sendCode(email);
    if (!mounted) {
      return;
    }
    setState(() => loading = false);
    if (result.success) {
      _startResetCountdown();
      _toast('验证码已发送');
    } else {
      _toast(result.msg.isEmpty ? '验证码发送失败' : result.msg);
    }
  }

  Future<void> _resetPassword() async {
    final email = resetEmail.text.trim();
    final password = resetPassword.text.trim();
    final confirm = resetConfirm.text.trim();
    final code = resetCode.text.trim();
    if (email.isEmpty) {
      _toast('邮箱不能为空');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      _toast('邮箱格式不正确');
      return;
    }
    if (password.isEmpty || confirm.isEmpty) {
      _toast('密码不能为空');
      return;
    }
    if (password != confirm) {
      _toast('两次输入密码不一致');
      return;
    }
    if (!_codePattern.hasMatch(code)) {
      _toast('验证码格式不正确');
      return;
    }
    setState(() => loading = true);
    final result = await AppScope.of(context).api.resetPassword(
          email: email,
          newPassword: password,
          verifyCode: code,
        );
    if (!mounted) {
      return;
    }
    setState(() => loading = false);
    if (result.success) {
      loginEmail.text = email;
      loginPassword.text = password;
      resetEmail.clear();
      resetPassword.clear();
      resetConfirm.clear();
      resetCode.clear();
      resetTimer?.cancel();
      setState(() {
        resetCountdown = 0;
        mode = 0;
      });
      _toast('密码重置成功');
    } else {
      _toast(result.msg.isEmpty ? '密码重置失败' : result.msg);
    }
  }

  Future<void> _oauthLogin(String provider) async {
    setState(() => oauthLoading = true);
    try {
      final state = AppScope.of(context);
      final api = state.api;
      await _startOauthCallbackServer();
      final create = await api.createOauthLoginTask(
        provider: provider,
        deviceId: _deviceId(),
        os: Platform.operatingSystemVersion,
        deviceType: 'PC',
        deviceName: Platform.localHostname,
      );
      if (!mounted) {
        return;
      }
      if (!create.success || create.data is! Map<String, dynamic>) {
        _toast(create.msg.isEmpty ? '授权任务创建失败' : create.msg);
        return;
      }
      final data = create.data as Map<String, dynamic>;
      final authUrl = data['authUrl']?.toString();
      final taskId = data['taskId']?.toString();
      if (authUrl != null && authUrl.isNotEmpty) {
        await _openExternalUrl(authUrl);
      }
      if (taskId == null || taskId.isEmpty) {
        _toast('授权任务异常');
        return;
      }
      for (var i = 0; i < 90 && mounted; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final poll = await api.pollOauthLogin(taskId);
        if (poll.data is! Map<String, dynamic>) {
          continue;
        }
        final pollData = poll.data as Map<String, dynamic>;
        final status = pollData['status']?.toString();
        if (poll.success && status == 'success') {
          final token = pollData['token']?.toString();
          if (token == null || token.isEmpty) {
            _toast('授权结果缺少 token');
            return;
          }
          state.token = token;
          await state.tokenStore.saveToken(token);
          await state.refreshUserInfo();
          showAppToast('登录成功', success: true);
          return;
        }
        if (status == 'failed') {
          _toast(pollData['msg']?.toString() ?? '授权登录失败');
          return;
        }
      }
      _toast('授权登录超时');
    } catch (e) {
      if (mounted) {
        _toast('授权登录异常：$e');
      }
    } finally {
      if (mounted) {
        setState(() => oauthLoading = false);
      }
    }
  }

  Future<void> _openExternalUrl(String url) async {
    if (Platform.isWindows) {
      await Process.start(
        'rundll32',
        ['url.dll,FileProtocolHandler', url],
        runInShell: false,
      );
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [url], runInShell: false);
      return;
    }
    await Process.start('xdg-open', [url], runInShell: false);
  }

  Future<void> _startOauthCallbackServer() async {
    if (oauthCallbackServer != null) {
      return;
    }
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
      oauthCallbackServer = server;
      server.listen(_handleOauthCallback);
    } catch (_) {
      throw Exception('本地3000端口被占用，无法接收Google/X授权回调');
    }
  }

  Future<void> _handleOauthCallback(HttpRequest request) async {
    final path = request.uri.path;
    final isOauthPath = path == '/api/auth/callback/google' ||
        path == '/api/auth/callback/x' ||
        path == '/api/client/oauth/callback';
    if (!isOauthPath) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
      await request.response.close();
      return;
    }

    final error = request.uri.queryParameters['error'];
    final code = request.uri.queryParameters['code'];
    final state = request.uri.queryParameters['state'];
    if (error != null && error.isNotEmpty) {
      await _writeOauthCallbackPage(request, false, '授权失败：$error');
      return;
    }
    if (code == null || code.isEmpty || state == null || state.isEmpty) {
      await _writeOauthCallbackPage(request, false, '授权回调缺少 code 或 state');
      return;
    }

    try {
      await AppScope.of(context)
          .api
          .completeOauthCallback(code: code, state: state);
      await _writeOauthCallbackPage(request, true, '授权完成，请返回 Luxwap');
    } catch (e) {
      await _writeOauthCallbackPage(request, false, '授权回调处理失败：$e');
    }
  }

  Future<void> _writeOauthCallbackPage(
    HttpRequest request,
    bool success,
    String message,
  ) async {
    request.response.headers.contentType =
        ContentType('text', 'html', charset: 'utf-8');
    request.response.write('''
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Luxwap</title></head>
<body style="font-family:Arial,sans-serif;background:#f3f6fb;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
  <div style="background:#fff;border-radius:16px;padding:32px 42px;box-shadow:0 12px 36px rgba(0,0,0,.12);text-align:center;">
    <h2 style="margin:0 0 12px;color:${success ? '#238b45' : '#c62828'};">${success ? '授权成功' : '授权失败'}</h2>
    <p style="margin:0;color:#333;">$message</p>
  </div>
</body>
</html>
''');
    await request.response.close();
  }

  bool _validateRegisterBase() {
    final email = registerEmail.text.trim();
    final password = registerPassword.text.trim();
    final confirm = registerConfirm.text.trim();
    if (email.isEmpty) {
      _toast('邮箱不能为空');
      return false;
    }
    if (!_emailPattern.hasMatch(email)) {
      _toast('邮箱格式不正确');
      return false;
    }
    if (password.isEmpty || confirm.isEmpty) {
      _toast('密码不能为空');
      return false;
    }
    if (password != confirm) {
      _toast('两次输入密码不一致');
      return false;
    }
    return true;
  }

  void _startRegisterCountdown() {
    registerTimer?.cancel();
    setState(() => registerCountdown = 300);
    registerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || registerCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => registerCountdown = 0);
        }
        return;
      }
      setState(() => registerCountdown--);
    });
  }

  void _startResetCountdown() {
    resetTimer?.cancel();
    setState(() => resetCountdown = 300);
    resetTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || resetCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => resetCountdown = 0);
        }
        return;
      }
      setState(() => resetCountdown--);
    });
  }

  String _deviceId() {
    final host = Platform.localHostname;
    return host.isEmpty ? 'flutter-windows' : host;
  }

  void _toast(String message) {
    showAppToast(message);
    setState(() => notice = message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && notice == message) {
        setState(() => notice = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final panels = [
      _loginPanel(),
      _registerPanel(),
      _resetPanel(),
      _registerCodePanel(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xffefefef),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Center(
            child: SizedBox(
              width: 540,
              height: 900,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Top gradient banner (Frame 19: 540x374, r=[0,0,30,30], gradient #3E98F3 -> #2A72E1)
                  Container(
                    width: 540,
                    height: 374,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xff3e98f3), Color(0xff2a72e1)],
                      ),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                  ),
                  // Language pill button (80x30, r=148)
                  Positioned(
                    top: 24,
                    right: 30,
                    child: Container(
                      width: 80,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(148),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(148),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.language, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              '语言',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // White brand logo (主logo白色, 145x135)
                  const Positioned(
                    top: 36,
                    child: LuxwapIcon(
                      'icon-logo-white',
                      width: 145,
                      height: 136,
                    ),
                  ),
                  // Floating white card (Frame 18: 480x688, r=30, white, shadow)
                  Positioned(
                    top: 187,
                    child: Container(
                      width: 480,
                      height: 688,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (mode == 0 || mode == 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildTabItem(
                                    title: '账号登录',
                                    isSelected: mode == 0,
                                    onTap: () => setState(() {
                                      notice = null;
                                      mode = 0;
                                    }),
                                  ),
                                  const SizedBox(width: 48),
                                  _buildTabItem(
                                    title: '账号注册',
                                    isSelected: mode == 1,
                                    onTap: () => setState(() {
                                      notice = null;
                                      mode = 1;
                                    }),
                                  ),
                                ],
                              ),
                            )
                          else if (mode == 2)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                '重置密码',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xff1b1b1b),
                                ),
                              ),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: notice == null
                                ? SizedBox(height: mode == 3 ? 0 : 12)
                                : Padding(
                                    key: ValueKey(notice),
                                    padding:
                                        const EdgeInsets.only(top: 4, bottom: 8),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 32),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfffff7e6),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xffffd591)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline,
                                              size: 16, color: Color(0xffd46b08)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              notice!,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xff873800)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          Expanded(child: panels[mode]),
                          if (loading) const LinearProgressIndicator(minHeight: 2),
                        ],
                      ),
                    ),
                  ),
                  if (oauthLoading)
                    Container(
                      width: 540,
                      height: 900,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            child: LinearProgressIndicator(),
                          ),
                          SizedBox(height: 12),
                          Text('登录中...',
                              style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected ? LuxwapColors.neutral800 : LuxwapColors.neutral500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? LuxwapColors.brand500 : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _input(
          controller: loginEmail,
          hint: '用户名/账号',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 10),
        _input(
          controller: loginPassword,
          hint: '密码',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        SizedBox(
          height: 32,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                notice = null;
                mode = 2;
              }),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: LuxwapColors.brand500,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('忘记密码？'),
            ),
          ),
        ),
        _primaryButton('登录', _login),
        const SizedBox(height: 10),
        _secondaryButton(
            '免费试用',
            () => setState(() {
                  notice = null;
                  mode = 1;
                })),
        const SizedBox(height: 25),
        _oauthSection(),
      ],
    );
  }

  Widget _registerPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _input(
          controller: registerEmail,
          hint: '用户名/账号 (邮箱)',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 10),
        _input(
          controller: registerPassword,
          hint: '密码',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const SizedBox(height: 10),
        _input(
          controller: registerConfirm,
          hint: '请再次输入密码',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const SizedBox(height: 20),
        _primaryButton('验证邮箱', _sendRegisterCode),
        const SizedBox(height: 16),
        const Text(
          '注册即表示您同意《用户协议》和《隐私政策》，仅用于账户登录和服务通知。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xffb2b2b2), fontSize: 10, height: 1.5),
        ),
        const SizedBox(height: 8),
        _backToLoginButton(center: true),
        const Spacer(),
      ],
    );
  }

  Widget _registerCodePanel() {
    final email = registerEmail.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.near_me_outlined, size: 38, color: Color(0xff6b7280)),
        const SizedBox(height: 14),
        const Text(
          '我们已向邮箱发送验证码',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Color(0xff1b1b1b),
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff6b7280), fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _plainInput(controller: registerCode, hint: '请输入邮箱验证码'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 74,
              height: 42,
              child: TextButton(
                onPressed: registerCountdown == 0 ? _resendRegisterCode : null,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff2a80ff),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(
                    registerCountdown > 0 ? '${registerCountdown}s' : '重新发送'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _primaryButton('确认注册', _confirmRegister),
        const Spacer(),
        _backToLoginButton(),
      ],
    );
  }

  Widget _resetPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _input(
            controller: resetEmail, hint: '请输入注册邮箱', icon: Icons.mail_outline),
        const SizedBox(height: 10),
        _input(
            controller: resetPassword,
            hint: '请输入新密码',
            icon: Icons.lock_outline,
            obscure: true),
        const SizedBox(height: 10),
        _input(
            controller: resetConfirm,
            hint: '请再次输入新密码',
            icon: Icons.lock_outline,
            obscure: true),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _input(
                  controller: resetCode,
                  hint: '请输入验证码',
                  icon: Icons.verified_outlined),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              height: 60,
              child: TextButton(
                onPressed: resetCountdown == 0 ? _sendResetCode : null,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff2a80ff),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(resetCountdown > 0 ? '${resetCountdown}s' : '验证码'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _primaryButton('重置密码', _resetPassword),
        TextButton(
          onPressed: () => setState(() {
            notice = null;
            mode = 0;
          }),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text('← 返回登录'),
          ),
        ),
      ],
    );
  }

  Widget _oauthSection({bool compact = false}) {
    return SizedBox(
      width: 320,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 1,
                color: const Color(0xffd7dce6),
              ),
              const SizedBox(width: 10),
              const Text(
                '使用以下服务登陆',
                style: TextStyle(
                  color: Color(0xff666666),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 1,
                color: const Color(0xffd7dce6),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          SizedBox(
            width: 260,
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _OauthButton(
                  label: 'Google',
                  asset: 'assets/images/icon_Google_logo.png',
                  iconSize: 24,
                  onTap: () => _oauthLogin('google'),
                ),
                _OauthButton(
                  label: 'Facebook',
                  asset: 'assets/images/icon_facebook_logo.png',
                  iconSize: 24,
                  onTap: () => _oauthLogin('facebook'),
                ),
                _OauthButton(
                  label: 'X账户',
                  asset: 'assets/images/icon_X_logo.png',
                  iconSize: 22,
                  onTap: () => _oauthLogin('x'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '查看《用户协议》及《隐私政策》。我们将依法保护您的数据安全。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xffb2b2b2),
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backToLoginButton({bool center = false}) {
    return Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: TextButton(
        onPressed: () => setState(() {
          notice = null;
          mode = 0;
        }),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xff286afc),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 28),
        ),
        child: const Text('← 返回登录'),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xfff3f6fb),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xff666666)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle:
                    const TextStyle(fontSize: 14, color: Color(0xffb2b2b2)),
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xff1b1b1b)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainInput({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xfff3f6fb),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xffb2b2b2)),
        ),
        style: const TextStyle(fontSize: 14, color: Color(0xff1b1b1b)),
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 53,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xff297ce7),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: loading || oauthLoading ? null : onPressed,
        child: Text(text),
      ),
    );
  }

  Widget _secondaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xffe9f0ff),
          foregroundColor: const Color(0xff286afc),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: loading || oauthLoading ? null : onPressed,
        child: Text(text),
      ),
    );
  }
}

class _OauthButton extends StatelessWidget {
  const _OauthButton({
    required this.label,
    required this.asset,
    required this.iconSize,
    required this.onTap,
  });

  final String label;
  final String asset;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 62,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: Image.asset(asset, width: iconSize, height: iconSize),
              ),
            ),
            Container(
              height: 20,
              margin: const EdgeInsets.only(top: 5),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12.5, color: Color(0xff666666)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
