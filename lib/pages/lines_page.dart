import 'dart:convert';
import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/client_config.dart';
import '../models/line_node.dart';
import '../services/tun_route_manager.dart';
import '../services/luxwap_config_builder.dart';
import '../theme/luxwap_theme.dart';
import '../widgets/luxwap_icon.dart';

class LinesPage extends StatefulWidget {
  const LinesPage({super.key});

  @override
  State<LinesPage> createState() => _LinesPageState();
}

class _LinesPageState extends State<LinesPage> {
  bool loading = true;
  bool connected = false;
  bool switching = false;
  bool testingDelays = false;
  int nextSpeedtestPort = 19080;
  String filter = 'all';
  List<LineNode> nodes = [];
  String? selectedRaw;
  Process? coreProcess;
  Process? speedtestProcess;
  Timer? statsTimer;
  int? statsPort;
  int? lastProxyUpKb;
  int? lastProxyDownKb;
  String speedText = '↑ 0kb/s  ↓ 0kb/s';
  bool _userInitiatedStop = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _cleanupBundledCoreProcesses();
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    final state = AppScope.of(context);
    final token = state.token;
    if (token == null) {
      return;
    }
    setState(() => loading = true);
    final result = await state.api.lineList(token);
    final loaded = <LineNode>[];
    final savedRaw = state.clientConfig.selectedLineRaw;
    if (result.success && result.data != null) {
      final data = result.data;
      final list = data is String
          ? data
              .split(RegExp(r'\r?\n'))
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
          : data;
      if (list is List) {
        for (final item in list) {
          loaded.add(
            LineNode.fromSubscriptionLine(item
                    .toString()
                    .replaceAll(r'${uuid}', state.userInfo?.uuid ?? ''))
                .copyWith(testingDelay: true),
          );
        }
      }
    }
    if (!mounted) {
      return;
    }
    final selected =
        loaded.any((node) => node.raw == savedRaw) ? savedRaw : null;
    setState(() {
      nodes = loaded;
      selectedRaw = selected;
      loading = false;
    });
    await _refreshDelays();
  }

  Future<void> _refreshDelays() async {
    if (testingDelays) {
      await _speedtestLog('skip refresh: speedtest already running');
      return;
    }
    final current = List<LineNode>.from(nodes);
    if (current.isEmpty) {
      return;
    }
    testingDelays = true;
    setState(() {
      nodes = current.map((node) => node.copyWith(testingDelay: true)).toList();
    });
    try {
      final measured = await _measureDelaysBatch(current);
      if (!mounted) {
        return;
      }
      setState(() => nodes = measured);
    } finally {
      testingDelays = false;
    }
  }

  Future<List<LineNode>> _measureDelaysBatch(List<LineNode> source) async {
    await _speedtestLog('start nodes=${source.length}');
    final entries = <({LineNode node, int port})>[];
    final inbounds = <Map<String, dynamic>>[];
    final outbounds = <Map<String, dynamic>>[];
    final rules = <Map<String, dynamic>>[];

    for (final node in source) {
      final port = await _nextSpeedtestPort();
      final outbound = _buildVlessOutbound(node, 'proxy$port');
      if (outbound == null) {
        entries.add((node: node, port: -1));
        continue;
      }
      final inboundTag = 'mixed$port';
      entries.add((node: node, port: port));
      inbounds.add({
        'tag': inboundTag,
        'listen': '127.0.0.1',
        'port': port,
        'protocol': 'mixed',
      });
      outbounds.add(outbound);
      rules.add({
        'type': 'field',
        'inboundTag': [inboundTag],
        'outboundTag': 'proxy$port',
      });
    }

    if (inbounds.isEmpty) {
      await _speedtestLog('no valid inbounds');
      return source
          .map((node) => node.copyWith(delayMs: -1, testingDelay: false))
          .toList();
    }

    final configContent = const JsonEncoder.withIndent('  ').convert({
      'log': {'loglevel': 'warning'},
      'inbounds': inbounds,
      'outbounds': outbounds,
      'routing': {'rules': rules},
    });
    Process? process;
    try {
      final corePath = _luxwapCorePath();
      await _speedtestLog(
          'luxwap_core=$corePath exists=${await File(corePath).exists()} inbounds=${inbounds.length}');
      if (!await File(corePath).exists()) {
        return source
            .map((node) => node.copyWith(delayMs: -1, testingDelay: false))
            .toList();
      }
      process = await Process.start(
        corePath,
        ['run', '-c', 'stdin:'],
        runInShell: false,
        workingDirectory: File(Platform.resolvedExecutable).parent.path,
        environment: _luxwapCoreAssetEnvironment(),
      );
      speedtestProcess = process;
      process.exitCode.then((code) {
        _speedtestLog('luxwap_core exitCode=$code');
      });
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
      process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);
      process.stdin.write(configContent);
      await process.stdin.flush();
      await process.stdin.close();
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (await _hasProcessExited(process)) {
        await _speedtestLog(
            'luxwap_core parent exited; continue probing ports stdout=${stdoutBuffer.toString()} stderr=${stderrBuffer.toString()}');
      }

      final measured = await Future.wait(entries.map((entry) async {
        if (entry.port <= 0) {
          await _speedtestLog('invalid outbound node=${entry.node.name}');
          return entry.node.copyWith(delayMs: -1, testingDelay: false);
        }
        final delay = await _curlRealPing(entry.port, entry.node.name);
        return entry.node.copyWith(delayMs: delay, testingDelay: false);
      }));
      await _speedtestLog('curl probes finished');
      return measured;
    } catch (error, stackTrace) {
      await _speedtestLog('batch error=$error stack=$stackTrace');
      return source
          .map((node) => node.copyWith(delayMs: -1, testingDelay: false))
          .toList();
    } finally {
      await _speedtestLog('speedtest finally killing process');
      await _killProcess(process);
      if (identical(speedtestProcess, process)) {
        speedtestProcess = null;
      }
    }
  }

  String _luxwapCoreDir() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isMacOS) {
      // macOS .app bundle: Contents/MacOS/app → Contents/Resources/
      final resDir = '${File(exeDir).parent.path}${Platform.pathSeparator}Resources';
      return '$resDir${Platform.pathSeparator}bin${Platform.pathSeparator}luxwap_core';
    }
    return '$exeDir${Platform.pathSeparator}bin${Platform.pathSeparator}luxwap_core';
  }

  String _luxwapCorePath() {
    final coreName = Platform.isWindows ? 'luxwap_core.exe' : 'luxwap_core';
    final dir = _luxwapCoreDir();
    if (Platform.isMacOS) {
      final arch = _macCpuArch();
      final p1 = '$dir${Platform.pathSeparator}$arch${Platform.pathSeparator}$coreName';
      if (File(p1).existsSync()) return p1;
      final other = arch == 'arm64' ? 'amd64' : 'arm64';
      final p2 = '$dir${Platform.pathSeparator}$other${Platform.pathSeparator}$coreName';
      if (File(p2).existsSync()) return p2;
      return p1;
    }
    return '$dir${Platform.pathSeparator}$coreName';
  }

  String _macCpuArch() {
    if (Abi.current() == Abi.macosArm64) return 'arm64';
    return 'amd64';
  }

  Map<String, String> _luxwapCoreAssetEnvironment() {
    final dir = _luxwapCoreDir();
    final env = {
      'LUXWAP_CORE_LOCATION_ASSET': dir,
      'XRAY_LOCATION_ASSET': dir,
      'V2RAY_LOCATION_ASSET': dir,
    };
    final sysPath = Platform.environment['PATH'];
    if (sysPath != null && sysPath.isNotEmpty) {
      env['PATH'] = '$dir${Platform.isWindows ? ';' : ':'}$sysPath';
    } else {
      env['PATH'] = dir;
    }
    return env;
  }

  Map<String, dynamic>? _buildVlessOutbound(LineNode node, String tag) {
    return LuxwapConfigBuilder.buildVlessOutbound(node, tag);
  }

  Future<int> _nextSpeedtestPort() async {
    for (var i = 0; i < 1000; i++) {
      final port = nextSpeedtestPort;
      nextSpeedtestPort++;
      if (nextSpeedtestPort > 20080) {
        nextSpeedtestPort = 19080;
      }
      if (await _isPortAvailable(port)) {
        return port;
      }
    }
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<bool> _isPortAvailable(int port) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      return true;
    } catch (_) {
      return false;
    } finally {
      await socket?.close();
    }
  }

  Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<int> _curlRealPing(int socksPort, String nodeName) async {
    const testUrl = 'http://www.gstatic.com/generate_204';
    try {
      final result = await Process.run(
        Platform.isWindows ? 'curl.exe' : 'curl',
        [
          '-x',
          'socks5h://127.0.0.1:$socksPort',
          '-o',
          Platform.isWindows ? 'NUL' : '/dev/null',
          '-s',
          '-w',
          '%{time_total}\\n',
          testUrl,
          '-o',
          Platform.isWindows ? 'NUL' : '/dev/null',
          '-s',
          '-w',
          '%{time_total}\\n',
          testUrl,
          '--max-time',
          '10',
        ],
      ).timeout(const Duration(seconds: 12));
      await _speedtestLog(
          'curl node=$nodeName port=$socksPort exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}');
      if (result.exitCode != 0) {
        return -1;
      }
      final seconds = result.stdout
          .toString()
          .split(RegExp(r'\s+'))
          .map(double.tryParse)
          .whereType<double>()
          .where((value) => value > 0)
          .toList()
        ..sort();
      if (seconds.isEmpty) {
        return -1;
      }
      return (seconds.first * 1000).round();
    } catch (error, stackTrace) {
      await _speedtestLog(
          'curl error node=$nodeName port=$socksPort error=$error stack=$stackTrace');
      return -1;
    }
  }

  Future<void> _speedtestLog(String message) async {
    try {
      final dir = await _appDataDir();
      final file = File('${dir.path}${Platform.pathSeparator}speedtest.log');
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Diagnostic logging must never affect speed testing.
    }
  }

  Future<Directory> _appDataDir() async {
    Directory dir;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
      dir = Directory('$appData\\luxwap');
    } else {
      final appSupportDir = await getApplicationSupportDirectory();
      dir = Directory('${appSupportDir.path}${Platform.pathSeparator}luxwap');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  void dispose() {
    _stopStatsPolling(resetText: false);
    _killProcess(speedtestProcess);
    _stopProxy(updateState: false);
    _cleanupBundledCoreProcesses();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = nodes
        .where(
            (n) => filter == 'all' || n.keyword.toLowerCase().contains(filter))
        .toList();
    final groups = <String, List<LineNode>>{};
    for (final node in filtered) {
      groups.putIfAbsent(node.region, () => []).add(node);
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 18, 30, 0),
      child: Column(
        children: [
          _StatusBar(
              connected: connected,
              switching: switching,
              speedText: speedText,
              onChanged: _toggleProxy),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
            child: Row(
              children: [
                const Text('线路列表',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: LuxwapColors.neutral900)),
                const Spacer(),
                _ToolbarButton(
                    label: '筛选',
                    iconWidget: const LuxwapIcon(LuxwapIcons.down, size: 12, color: LuxwapColors.brand500),
                    onTap: _showFilterMenu),
                const SizedBox(width: 8),
                _ToolbarButton(
                    label: '刷新',
                    iconWidget: const LuxwapIcon(LuxwapIcons.refresh, size: 12, color: LuxwapColors.brand500),
                    onTap: _load),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.zero,
                    children: groups.entries
                        .map(
                          (entry) => _RegionGroup(
                            title: entry.key,
                            nodes: entry.value,
                            selectedRaw: selectedRaw,
                            onSelected: _selectNode,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleProxy(bool enable) async {
    if (switching) {
      return;
    }
    setState(() => switching = true);
    try {
      if (enable) {
        await _startProxy();
      } else {
        await _stopProxy();
      }
    } finally {
      if (mounted) {
        setState(() => switching = false);
      }
    }
  }

  Future<void> _startProxy() async {
    final state = AppScope.of(context);
    LineNode? node;
    for (final item in nodes) {
      if (item.raw == selectedRaw) {
        node = item;
        break;
      }
    }
    if (node == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择节点!')),
        );
      }
      return;
    }

    await _stopProxy(updateState: false);
    await _cleanupBundledCoreProcesses();
    final config = await _buildLuxwapCoreRuntimeConfig(
      node,
      state.clientConfig,
      state.userInfo?.country,
    );
    if (config == null) {
      return;
    }
    final corePath = _luxwapCorePath();
    if (!await File(corePath).exists()) {
      return;
    }

    final isTun = state.clientConfig.tunEnabled;
    if (isTun && node.host.isNotEmpty) {
      // 官方 TUN 原理：在 TUN 全局接管生效前，为节点公网 IP 建立物理网关直连主机路由 (/32)，
      // 杜绝出站握手流量被 0.0.0.0/1 捕获造成 infinite network loop。
      await TunRouteManager.addDirectNodeRoute(node.host);
    }

    _userInitiatedStop = false;
    coreProcess = await Process.start(
      corePath,
      ['run', '-c', 'stdin:'],
      runInShell: false,
      workingDirectory: File(Platform.resolvedExecutable).parent.path,
      environment: _luxwapCoreAssetEnvironment(),
    );
    coreProcess!.exitCode.then((code) {
      _speedtestLog('runtime luxwap_core exitCode=$code');
      if (isTun) {
        TunRouteManager.removeDirectNodeRoute();
      }
      if (mounted && connected) {
        setState(() => connected = false);
        _stopStatsPolling();
        if (!_userInitiatedStop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1F2329),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF71AFFC), size: 18),
                  SizedBox(width: 8),
                  Text('网络连接已断开', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
    coreProcess!.stdin.write(config);
    await coreProcess!.stdin.flush();
    await coreProcess!.stdin.close();
    coreProcess!.stdout.transform(utf8.decoder).listen((text) {
      _speedtestLog('runtime stdout=$text');
    });
    coreProcess!.stderr.transform(utf8.decoder).listen((text) {
      _speedtestLog('runtime stderr=$text');
    });
    final proxyReady = await _waitTcpPort(10809);
    if (!proxyReady) {
      await _speedtestLog('runtime luxwap_core proxy port 10809 not ready');
      if (isTun) {
        await TunRouteManager.removeDirectNodeRoute();
      }
      await _killProcess(coreProcess);
      coreProcess = null;
      return;
    }
    if (isTun) {
      // TUN 虚拟网卡模式已由虚拟网卡(Wintun/utun)在网络层接管系统全局流量。
      // 此时必须确保关闭/清除系统代理，防止 TUN 与系统代理同时存在发生路由冲突或双重代理。
      await _setSystemProxy(false);
      // 等待 Wintun / utun 设备就绪并校验进程存活
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (await _hasProcessExited(coreProcess)) {
        await _speedtestLog('runtime luxwap_core exited unexpectedly during tun init');
        coreProcess = null;
        await TunRouteManager.removeDirectNodeRoute();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TUN 虚拟网卡创建失败，请确保以管理员权限运行')),
          );
        }
        return;
      }
      // 优化 TUN 虚拟网卡接口跃点数，确保 TUN 虚拟网卡 DNS 优先级高于物理内网 DNS
      await TunRouteManager.optimizeTunInterface();
    } else {
      // 非 TUN 模式（普通代理），通过系统代理指向 127.0.0.1:10809 接管应用层流量。
      await _setSystemProxy(true);
    }
    _startStatsPolling();
    if (mounted) {
      setState(() => connected = true);
    }
  }

  Future<void> _stopProxy({bool updateState = true}) async {
    _userInitiatedStop = true;
    _stopStatsPolling();
    await _killProcess(coreProcess);
    coreProcess = null;
    await TunRouteManager.removeDirectNodeRoute();
    await _cleanupBundledCoreProcesses();
    await _setSystemProxy(false);
    if (updateState && mounted) {
      setState(() => connected = false);
    }
  }

  Future<bool> _hasProcessExited(Process? process) async {
    if (process == null) {
      return true;
    }
    try {
      await process.exitCode.timeout(const Duration(milliseconds: 1));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitTcpPort(int port) async {
    for (var i = 0; i < 30; i++) {
      Socket? socket;
      try {
        socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 200),
        );
        return true;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } finally {
        socket?.destroy();
      }
    }
    return false;
  }

  Future<void> _killProcess(Process? process) async {
    if (process == null) {
      return;
    }
    try {
      await _speedtestLog(
          'kill process pid=${process.pid} stack=${StackTrace.current}');
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      // ignored
    }
  }

  Future<void> _cleanupBundledCoreProcesses() async {
    try {
      const MethodChannel('luxwap/window').invokeMethod('killCore');
    } catch (_) {}
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/f', '/im', 'luxwap_core.exe'])
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    } else {
      try {
        await Process.run('pkill', ['-f', 'luxwap_core'])
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  void _startStatsPolling() {
    _stopStatsPolling(resetText: false);
    lastProxyUpKb = null;
    lastProxyDownKb = null;
    if (mounted) {
      setState(() => speedText = '↑ 0kb/s  ↓ 0kb/s');
    }
    statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateProxySpeed();
    });
    _updateProxySpeed();
  }

  void _stopStatsPolling({bool resetText = true}) {
    statsTimer?.cancel();
    statsTimer = null;
    lastProxyUpKb = null;
    lastProxyDownKb = null;
    if (resetText && mounted) {
      setState(() => speedText = '↑ 0kb/s  ↓ 0kb/s');
    }
  }

  Future<void> _updateProxySpeed() async {
    final port = statsPort;
    if (port == null) {
      return;
    }
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      try {
        final request =
            await client.getUrl(Uri.parse('http://127.0.0.1:$port/debug/vars'));
        final response =
            await request.close().timeout(const Duration(seconds: 2));
        if (response.statusCode != HttpStatus.ok) {
          return;
        }
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        if (json is! Map<String, dynamic>) {
          return;
        }
        final current = _parseProxyStats(json);
        if (current == null) {
          return;
        }

        final previousUp = lastProxyUpKb;
        final previousDown = lastProxyDownKb;
        lastProxyUpKb = current.$1;
        lastProxyDownKb = current.$2;
        if (previousUp == null || previousDown == null) {
          return;
        }

        final up = (current.$1 - previousUp).clamp(0, 1 << 31);
        final down = (current.$2 - previousDown).clamp(0, 1 << 31);
        if (mounted) {
          setState(() => speedText = '↑ ${_formatSpeed(up)}  ↓ ${_formatSpeed(down)}');
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // The metrics endpoint is unavailable while core is still starting or stopping.
    }
  }

  String _formatSpeed(int kbPerSec) {
    if (kbPerSec >= 1024) {
      return '${(kbPerSec / 1024).toStringAsFixed(1)}MB/s';
    }
    return '${kbPerSec}KB/s';
  }

  (int, int)? _parseProxyStats(Map<String, dynamic> root) {
    final stats = root['stats'];
    if (stats is! Map) {
      return null;
    }
    final outbound = stats['outbound'];
    if (outbound is! Map) {
      return null;
    }

    var up = 0;
    var down = 0;
    for (final entry in outbound.entries) {
      final key = entry.key.toString();
      if (!key.startsWith('proxy')) {
        continue;
      }
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      up += ((value['uplink'] as num?)?.toInt() ?? 0) ~/ 1024;
      down += ((value['downlink'] as num?)?.toInt() ?? 0) ~/ 1024;
    }
    return (up, down);
  }

  Future<void> _setSystemProxy(bool enable) async {
    if (Platform.isWindows) {
      if (!enable) {
        try {
          MethodChannel('luxwap/window').invokeMethod('cleanProxy');
        } catch (_) {}
      }
      final script = enable
          ? r'''
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-ItemProperty -Path $path -Name ProxyEnable -Type DWord -Value 1
Set-ItemProperty -Path $path -Name ProxyServer -Type String -Value '127.0.0.1:10809'
Set-ItemProperty -Path $path -Name ProxyOverride -Type String -Value '<local>'
'''
          : r'''
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-ItemProperty -Path $path -Name ProxyEnable -Type DWord -Value 0
Remove-ItemProperty -Path $path -Name ProxyServer -ErrorAction SilentlyContinue
''';
      const notify = r"""
Add-Type -Namespace WinInet -Name NativeMethods -MemberDefinition '[DllImport("wininet.dll", SetLastError=true)] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
[WinInet.NativeMethods]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
""";
      await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script + notify,
      ]);
    } else if (Platform.isMacOS) {
      if (!enable) {
        try {
          const MethodChannel('luxwap/window').invokeMethod('cleanProxy');
        } catch (_) {}
      }
      for (final iface in ['Wi-Fi', 'Ethernet', 'Thunderbolt Bridge']) {
        try {
          if (enable) {
            await Process.run('networksetup', ['-setwebproxy', iface, '127.0.0.1', '10809']);
            await Process.run('networksetup', ['-setwebproxystate', iface, 'on']);
            await Process.run('networksetup', ['-setsocksfirewallproxy', iface, '127.0.0.1', '10808']);
            await Process.run('networksetup', ['-setsocksfirewallproxystate', iface, 'on']);
          } else {
            await Process.run('networksetup', ['-setwebproxystate', iface, 'off']);
            await Process.run('networksetup', ['-setsocksfirewallproxystate', iface, 'off']);
          }
        } catch (_) {}
      }
    } else {
      const iface = 'eth0';
      if (enable) {
        await Process.run('networksetup', ['-setwebproxy', iface, '127.0.0.1', '10809']);
        await Process.run('networksetup', ['-setwebproxystate', iface, 'on']);
        await Process.run('networksetup', ['-setsocksfirewallproxy', iface, '127.0.0.1', '10808']);
        await Process.run('networksetup', ['-setsocksfirewallproxystate', iface, 'on']);
      } else {
        await Process.run('networksetup', ['-setwebproxystate', iface, 'off']);
        await Process.run('networksetup', ['-setsocksfirewallproxystate', iface, 'off']);
      }
    }
  }

  Future<String?> _buildLuxwapCoreRuntimeConfig(
    LineNode node,
    ClientConfig clientConfig,
    String? userCountry,
  ) async {
    statsPort = await _freePort();
    return LuxwapConfigBuilder.buildConfigJson(
      node: node,
      clientConfig: clientConfig,
      userCountry: userCountry,
      statsPort: statsPort,
    );
  }

  String _normalizeCountryCode(String? country) =>
      LuxwapConfigBuilder.normalizeCountryCode(country);

  Map<String, dynamic> _buildDnsConfig(ClientConfig config, bool isChina) =>
      LuxwapConfigBuilder.buildDnsConfig(config, isChina);

  List<Map<String, dynamic>> _buildRoutingRules(
    ClientConfig config,
    String countryCode,
    bool isChina,
  ) =>
      LuxwapConfigBuilder.buildRoutingRules(config, countryCode, isChina);

  Future<void> _showFilterMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(900, 230, 100, 0),
      items: const [
        PopupMenuItem(value: 'all', child: Text('All')),
        PopupMenuItem(value: 'high', child: Text('High')),
        PopupMenuItem(value: 'medium', child: Text('Medium')),
        PopupMenuItem(value: 'low', child: Text('Low')),
      ],
    );
    if (selected != null) {
      setState(() => filter = selected);
    }
  }

  Future<void> _selectNode(LineNode node) async {
    final prevRaw = selectedRaw;
    setState(() => selectedRaw = node.raw);
    final state = AppScope.of(context);
    await state.updateClientConfig(
      state.clientConfig.copyWith(selectedLineRaw: node.raw),
    );
    if (connected && prevRaw != node.raw) {
      await _startProxy();
    }
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.connected,
    required this.switching,
    required this.speedText,
    required this.onChanged,
  });

  final bool connected;
  final bool switching;
  final String speedText;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: connected ? LuxwapColors.stateSuccess : LuxwapColors.brand500,
        borderRadius: LuxwapRadius.rMd,
        boxShadow: LuxwapShadows.card,
      ),
      child: Row(
        children: [
          const LuxwapIcon(LuxwapIcons.rocket, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            connected ? '已连接' : '未连接',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (connected) ...[
            const SizedBox(width: 18),
            Text(
              speedText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
          const Spacer(),
          Text(
            connected ? 'STOP' : 'START',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: switching ? null : () => onChanged(!connected),
            customBorder: const CircleBorder(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected
                    ? const Color(0xffff8a18)
                    : Colors.white.withValues(alpha: 0.85),
              ),
              child: switching
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(connected ? Icons.stop : Icons.play_arrow,
                      color: connected ? Colors.white : LuxwapColors.brand500,
                      size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.iconWidget,
    required this.onTap,
  });

  final String label;
  final Widget iconWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: LuxwapRadius.rLg,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: LuxwapColors.brand50,
          borderRadius: LuxwapRadius.rLg,
          border: Border.all(color: LuxwapColors.brand100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: LuxwapColors.brand500,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionGroup extends StatelessWidget {
  const _RegionGroup({
    required this.title,
    required this.nodes,
    required this.selectedRaw,
    required this.onSelected,
  });

  final String title;
  final List<LineNode> nodes;
  final String? selectedRaw;
  final ValueChanged<LineNode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: LuxwapColors.neutral200,
              borderRadius: LuxwapRadius.rSm,
            ),
            child: Row(
              children: [
                const LuxwapIcon(LuxwapIcons.global, size: 14, color: LuxwapColors.brand500),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: LuxwapColors.neutral900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...nodes.asMap().entries.map(
                (entry) => _LineRow(
                  node: entry.value,
                  index: entry.key,
                  selected: selectedRaw == entry.value.raw,
                  onTap: () => onSelected(entry.value),
                ),
              ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow(
      {required this.node,
      required this.index,
      required this.selected,
      required this.onTap});

  final LineNode node;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crowdColor = node.crowdColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: LuxwapRadius.rMd,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? LuxwapColors.brand500 : LuxwapColors.borderLight,
              width: selected ? 1.2 : 1.0,
            ),
            borderRadius: LuxwapRadius.rMd,
            color: selected ? LuxwapColors.brand50 : Colors.white,
            boxShadow: selected ? LuxwapShadows.card : null,
          ),
          child: Stack(
            children: [
              const Positioned(
                  left: 145, right: 108, top: 26, child: _DashLine()),
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? LuxwapColors.brand500 : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? LuxwapColors.brand500
                                : LuxwapColors.neutral400,
                            width: selected ? 2 : 1.2,
                          ),
                        ),
                        child: selected
                            ? Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: LuxwapColors.neutral900),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(width: 70, child: _DelayText(node: node)),
                  SizedBox(
                    width: 42,
                    child: Center(
                        child: Icon(Icons.groups, size: 17, color: crowdColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DelayText extends StatelessWidget {
  const _DelayText({required this.node});

  final LineNode node;

  @override
  Widget build(BuildContext context) {
    if (node.testingDelay) {
      return const Text('测试中',
          textAlign: TextAlign.right,
          style: TextStyle(
              color: LuxwapColors.brand500,
              fontSize: 11,
              fontWeight: FontWeight.w500));
    }
    if (node.delayMs == null) {
      return const Text('-',
          textAlign: TextAlign.right,
          style: TextStyle(
              color: LuxwapColors.brand500,
              fontSize: 11,
              fontWeight: FontWeight.w500));
    }
    if (node.delayMs! < 0) {
      return const Text('超时',
          textAlign: TextAlign.right,
          style: TextStyle(
              color: LuxwapColors.brand500,
              fontSize: 11,
              fontWeight: FontWeight.w500));
    }
    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        children: [
          TextSpan(
              text: '${node.delayMs}',
              style: const TextStyle(
                  color: LuxwapColors.brand500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const TextSpan(
              text: ' /ms',
              style: TextStyle(color: LuxwapColors.neutral900, fontSize: 10)),
        ],
      ),
    );
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffcfd6df)
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), paint);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashLine extends StatelessWidget {
  const _DashLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _DashLinePainter(), child: const SizedBox(height: 1));
  }
}
