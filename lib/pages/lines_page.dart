import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/client_config.dart';
import '../models/line_node.dart';

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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _cleanupBundledXrayProcesses();
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
    await _writeSpeedtestConfig(configContent);

    Process? process;
    try {
      final xray = _xrayPath();
      await _speedtestLog(
          'xray=$xray exists=${await File(xray).exists()} inbounds=${inbounds.length}');
      if (!await File(xray).exists()) {
        return source
            .map((node) => node.copyWith(delayMs: -1, testingDelay: false))
            .toList();
      }
      process = await Process.start(
        xray,
        ['run', '-c', 'stdin:'],
        runInShell: false,
        workingDirectory: File(Platform.resolvedExecutable).parent.path,
        environment: _xrayAssetEnvironment(),
      );
      speedtestProcess = process;
      process.exitCode.then((code) {
        _speedtestLog('xray exitCode=$code');
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
            'xray parent exited; continue probing ports stdout=${stdoutBuffer.toString()} stderr=${stderrBuffer.toString()}');
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

  String _xrayDir() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isMacOS) {
      // macOS .app bundle: Contents/MacOS/app → Contents/Resources/
      final resDir = '${File(exeDir).parent.path}${Platform.pathSeparator}Resources';
      return '$resDir${Platform.pathSeparator}bin${Platform.pathSeparator}xray';
    }
    return '$exeDir${Platform.pathSeparator}bin${Platform.pathSeparator}xray';
  }

  String _xrayPath() {
    final binName = Platform.isWindows ? 'xray.exe' : 'xray';
    final dir = _xrayDir();
    if (Platform.isMacOS) {
      // Detect arch: arm64 (Apple Silicon) or amd64 (Intel)
      final arm64Path =
          '$dir${Platform.pathSeparator}arm64${Platform.pathSeparator}$binName';
      if (File(arm64Path).existsSync()) return arm64Path;
      final amd64Path =
          '$dir${Platform.pathSeparator}amd64${Platform.pathSeparator}$binName';
      if (File(amd64Path).existsSync()) return amd64Path;
    }
    return '$dir${Platform.pathSeparator}$binName';
  }

  Map<String, String> _xrayAssetEnvironment() {
    return {
      'XRAY_LOCATION_ASSET': _xrayDir(),
      'V2RAY_LOCATION_ASSET': _xrayDir(),
    };
  }

  Map<String, dynamic>? _buildVlessOutbound(LineNode node, String tag) {
    final uri = Uri.tryParse(node.raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'vless' ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        uri.userInfo.isEmpty) {
      return null;
    }

    final query = uri.queryParameters;
    final user = <String, dynamic>{
      'id': uri.userInfo,
      'encryption': query['encryption'] ?? 'none',
    };
    if ((query['flow'] ?? '').isNotEmpty) {
      user['flow'] = query['flow'];
    }

    final streamSettings = <String, dynamic>{
      'network': query['type'] ?? 'tcp',
      'security': query['security'] ?? 'none',
    };
    if (streamSettings['security'] == 'reality') {
      streamSettings['realitySettings'] = {
        'serverName': query['sni'] ?? '',
        'fingerprint': query['fp'] ?? 'chrome',
        'publicKey': query['pbk'] ?? '',
        'shortId': query['sid'] ?? '',
        'spiderX': query['spx'] ?? '',
      };
    } else if (streamSettings['security'] == 'tls') {
      streamSettings['tlsSettings'] = {
        'serverName': query['sni'] ?? '',
        'allowInsecure': false,
      };
    }

    return {
      'tag': tag,
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': uri.host,
            'port': uri.port,
            'users': [user],
          }
        ],
      },
      'streamSettings': streamSettings,
    };
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

  Future<void> _writeSpeedtestConfig(String content) async {
    try {
      final dir = await _appDataDir();
      await File('${dir.path}${Platform.pathSeparator}speedtest-config.json')
          .writeAsString(content, flush: true);
    } catch (_) {
      // Diagnostic config dump must never affect speed testing.
    }
  }

  Future<Directory> _appDataDir() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
      return Directory('$appData\v2rayn_flutter');
    }
    final appSupportDir = await getApplicationSupportDirectory();
    return Directory('${appSupportDir.path}${Platform.pathSeparator}v2rayn_flutter');
  }

  @override
  void dispose() {
    _stopStatsPolling(resetText: false);
    _killProcess(speedtestProcess);
    _stopProxy(updateState: false);
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
                        fontWeight: FontWeight.bold,
                        color: Color(0xff1b1b1b))),
                const Spacer(),
                _ToolbarButton(
                    label: '筛选',
                    iconAsset: 'assets/images/select.png',
                    onTap: _showFilterMenu),
                const SizedBox(width: 10),
                _ToolbarButton(
                    label: '刷新',
                    iconAsset: 'assets/images/fresh.png',
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
    await _cleanupBundledXrayProcesses();
    final config = await _buildXrayRuntimeConfig(
      node,
      state.clientConfig,
      state.userInfo?.country,
    );
    if (config == null) {
      return;
    }
    final xray = _xrayPath();
    if (!await File(xray).exists()) {
      return;
    }

    coreProcess = await Process.start(
      xray,
      ['run', '-c', 'stdin:'],
      runInShell: false,
      workingDirectory: File(Platform.resolvedExecutable).parent.path,
      environment: _xrayAssetEnvironment(),
    );
    coreProcess!.exitCode.then((code) {
      _speedtestLog('runtime xray exitCode=$code');
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
      await _speedtestLog('runtime xray proxy port 10809 not ready');
      await _killProcess(coreProcess);
      coreProcess = null;
      return;
    }
    await _setWindowsProxy(true);
    _startStatsPolling();
    if (mounted) {
      setState(() => connected = true);
    }
  }

  Future<void> _stopProxy({bool updateState = true}) async {
    _stopStatsPolling();
    await _killProcess(coreProcess);
    coreProcess = null;
    await _setWindowsProxy(false);
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

  Future<void> _cleanupBundledXrayProcesses() async {
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/f', '/im', 'xray.exe'])
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    } else {
      try {
        await Process.run('pkill', ['-f', 'xray']).timeout(const Duration(seconds: 5));
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
      // The metrics endpoint is unavailable while xray is still starting or stopping.
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

  Future<void> _setWindowsProxy(bool enable) async {
    if (Platform.isWindows) {
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
    } else {
      final iface = Platform.isMacOS ? 'Wi-Fi' : 'eth0';
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

  Future<String?> _buildXrayRuntimeConfig(
    LineNode node,
    ClientConfig clientConfig,
    String? userCountry,
  ) async {
    final uri = Uri.tryParse(node.raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'vless' ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        uri.userInfo.isEmpty) {
      return null;
    }

    statsPort = await _freePort();
    final proxyOutbound = _buildVlessOutbound(node, 'proxy');
    if (proxyOutbound == null) {
      return null;
    }
    final countryCode = _normalizeCountryCode(userCountry);
    final isChina = countryCode == 'cn';

    final config = {
      'log': {'loglevel': 'warning'},
      'dns': _buildDnsConfig(clientConfig, isChina),
      'stats': {},
      'metrics': {'tag': 'api'},
      'policy': {
        'system': {
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        }
      },
      'inbounds': [
        {
          'tag': 'http-in',
          'listen': '127.0.0.1',
          'port': 10809,
          'protocol': 'http',
          'settings': {'timeout': 0},
        },
        {
          'tag': 'socks-in',
          'listen': '127.0.0.1',
          'port': 10808,
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true},
        },
        {
          'tag': 'api',
          'listen': '127.0.0.1',
          'port': statsPort,
          'protocol': 'dokodemo-door',
          'settings': {'address': '127.0.0.1'},
        },
      ],
      'outbounds': [
        proxyOutbound,
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
      'routing': {
        'domainStrategy': isChina ? 'AsIs' : 'IPIfNonMatch',
        'rules': [
          {
            'type': 'field',
            'inboundTag': ['api'],
            'outboundTag': 'api',
          },
          ..._buildRoutingRules(clientConfig, countryCode, isChina),
        ],
      },
    };

    return const JsonEncoder.withIndent('  ').convert(config);
  }

  String _normalizeCountryCode(String? country) {
    final code = (country ?? '').trim().toLowerCase();
    if (RegExp(r'^[a-z]{2}$').hasMatch(code)) {
      return code;
    }
    return 'cn';
  }

  Map<String, dynamic> _buildDnsConfig(ClientConfig config, bool isChina) {
    final servers = <dynamic>[];
    if (config.vpnRoute) {
      if (isChina) {
        servers.add({
          'address': config.innerDns,
          'domains': ['geosite:cn'],
          'expectIPs': ['geoip:cn'],
        });
        servers.add({
          'address': config.outerDns,
          'domains': ['geosite:geolocation-!cn'],
        });
      } else {
        servers.add(config.outerDns);
      }
    }
    servers.add(config.globalDns);
    return {'servers': servers};
  }

  List<Map<String, dynamic>> _buildRoutingRules(
    ClientConfig config,
    String countryCode,
    bool isChina,
  ) {
    final rules = <Map<String, dynamic>>[];
    if (config.blockAds) {
      rules.add({
        'type': 'field',
        'domain': ['geosite:category-ads-all'],
        'outboundTag': 'block',
      });
    }
    if (config.passByDomain && isChina) {
      rules.add({
        'type': 'field',
        'domain': ['geosite:cn'],
        'outboundTag': 'direct',
      });
    }
    if (config.passByLanDomain) {
      rules.add({
        'type': 'field',
        'domain': ['domain:localhost'],
        'outboundTag': 'direct',
      });
    }
    if (config.passByIp) {
      rules.add({
        'type': 'field',
        'ip': ['geoip:$countryCode'],
        'outboundTag': 'direct',
      });
    }
    if (config.passByLanIp) {
      rules.add({
        'type': 'field',
        'ip': ['geoip:private'],
        'outboundTag': 'direct',
      });
    }
    return rules;
  }

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
    setState(() => selectedRaw = node.raw);
    final state = AppScope.of(context);
    await state.updateClientConfig(
      state.clientConfig.copyWith(selectedLineRaw: node.raw),
    );
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
          color: const Color(0xff23cc66),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Image.asset('assets/images/rocket.png', width: 18, height: 18),
          const SizedBox(width: 10),
          Text(
            connected ? '已连接' : '未连接',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          if (connected) ...[
            const SizedBox(width: 18),
            Text(
              speedText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
          const Spacer(),
          Text(
            connected ? 'STOP' : 'START',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                    : Colors.white.withValues(alpha: 0.8),
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
                      color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton(
      {required this.label, required this.iconAsset, required this.onTap});

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 54,
        height: 24,
        decoration: BoxDecoration(
            color: const Color(0xfff2f2f4),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconAsset, width: 11, height: 11),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Color(0xff1b1b1b), fontSize: 10)),
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
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: const Color(0xfff3f3f5),
                borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                Image.asset('assets/images/area.png', width: 13, height: 13),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff1b1b1b))),
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
    final crowdColor = switch (index % 3) {
      0 => const Color(0xff18ad3e),
      1 => const Color(0xffff9822),
      _ => const Color(0xffff2d2d),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
                color: selected ? Colors.transparent : const Color(0xffeeeeee)),
            borderRadius: BorderRadius.circular(6),
            color: selected ? const Color(0xffeaf1ff) : Colors.white,
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
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected
                                  ? const Color(0xff2b77ff)
                                  : const Color(0xffe1e1e1),
                              width: selected ? 3 : 1),
                        ),
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
                          color: Color(0xff1b1b1b)),
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
              color: Color(0xff286afc),
              fontSize: 11,
              fontWeight: FontWeight.bold));
    }
    if (node.delayMs == null) {
      return const Text('-',
          textAlign: TextAlign.right,
          style: TextStyle(
              color: Color(0xff286afc),
              fontSize: 11,
              fontWeight: FontWeight.bold));
    }
    if (node.delayMs! < 0) {
      return const Text('超时',
          textAlign: TextAlign.right,
          style: TextStyle(
              color: Color(0xff286afc),
              fontSize: 11,
              fontWeight: FontWeight.bold));
    }
    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        children: [
          TextSpan(
              text: '${node.delayMs}',
              style: const TextStyle(
                  color: Color(0xff286afc),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const TextSpan(
              text: ' /ms',
              style: TextStyle(color: Color(0xff1b1b1b), fontSize: 10)),
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
