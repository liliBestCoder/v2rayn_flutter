import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Native Dart Chrome DevTools Protocol (CDP) Headless Browser Driver.
/// Automatically detects Chrome or Edge and drives it via standard WebSockets.
class CdpBrowserDriver {
  CdpBrowserDriver._({
    required this.browserProcess,
    required this.port,
    required this.tempDir,
    required this.targetId,
    required this.ws,
    required this.browserName,
  }) {
    _listenWebSocket();
  }

  final Process browserProcess;
  final int port;
  final Directory tempDir;
  final String targetId;
  final WebSocket ws;
  final String browserName;

  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pendingCommands = {};
  final List<void Function(String method, Map<String, dynamic> params)> _eventListeners = [];
  bool _closed = false;

  void _listenWebSocket() {
    ws.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json.containsKey('id')) {
            final id = json['id'] as int;
            final completer = _pendingCommands.remove(id);
            if (completer != null && !completer.isCompleted) {
              if (json.containsKey('error')) {
                completer.completeError(json['error'] as Object);
              } else {
                completer.complete((json['result'] as Map<String, dynamic>?) ?? {});
              }
            }
          } else if (json.containsKey('method')) {
            final method = json['method'] as String;
            final params = (json['params'] as Map<String, dynamic>?) ?? {};
            for (final listener in List.of(_eventListeners)) {
              listener(method, params);
            }
          }
        } catch (_) {}
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  void addEventListener(void Function(String method, Map<String, dynamic> params) listener) {
    _eventListeners.add(listener);
  }

  void removeEventListener(void Function(String method, Map<String, dynamic> params) listener) {
    _eventListeners.remove(listener);
  }

  /// Sends a raw CDP command and awaits its result
  Future<Map<String, dynamic>> sendCommand(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    if (_closed) {
      throw StateError('CDP Browser is closed');
    }
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingCommands[id] = completer;

    final payload = jsonEncode({
      'id': id,
      'method': method,
      'params': params ?? {},
    });
    ws.add(payload);
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _pendingCommands.remove(id);
        throw TimeoutException('CDP command "$method" timed out after 15s');
      },
    );
  }

  /// Navigates to [url] and waits for load or frame navigation
  Future<Map<String, dynamic>> navigate(
    String url, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await sendCommand('Page.enable');
    final loadCompleter = Completer<void>();

    void onEvent(String method, Map<String, dynamic> params) {
      if (method == 'Page.loadEventFired' || method == 'Page.frameNavigated') {
        if (!loadCompleter.isCompleted) {
          loadCompleter.complete();
        }
      }
    }

    addEventListener(onEvent);
    try {
      final navResult = await sendCommand('Page.navigate', {'url': url});
      try {
        await loadCompleter.future.timeout(timeout);
      } catch (_) {
        // Continue even if load event took longer
      }
      return navResult;
    } finally {
      removeEventListener(onEvent);
    }
  }

  /// Evaluates a JavaScript expression and returns the value
  Future<dynamic> evaluate(String expression) async {
    final result = await sendCommand('Runtime.evaluate', {
      'expression': expression,
      'returnByValue': true,
      'awaitPromise': true,
    });
    final val = result['result'];
    if (val is Map) {
      return val['value'];
    }
    return null;
  }

  /// Finds installed Chrome or Edge executable on the system
  static String? findBrowserExecutable() {
    final candidates = [
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
      r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      '/usr/bin/google-chrome',
      '/usr/bin/chromium-browser',
      '/usr/bin/microsoft-edge',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  /// Launches a headless browser instance with CDP enabled
  static Future<CdpBrowserDriver> launch({
    String? proxyServer,
    bool headless = true,
  }) async {
    final browserExe = findBrowserExecutable();
    if (browserExe == null) {
      throw UnsupportedError('No Chrome or Edge browser executable found on system');
    }

    final rand = DateTime.now().microsecondsSinceEpoch % 10000;
    final port = 19400 + (rand % 500);
    final tempDir = Directory.systemTemp.createTempSync('cdp_test_$port');

    final args = <String>[
      if (headless) '--headless=new',
      '--remote-debugging-port=$port',
      '--user-data-dir=${tempDir.path}',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-gpu',
      '--disable-background-networking',
      '--disable-sync',
      '--disable-default-apps',
      '--disable-extensions',
      if (proxyServer != null && proxyServer.isNotEmpty)
        '--proxy-server=$proxyServer',
      'about:blank',
    ];

    final process = await Process.start(browserExe, args);

    // Wait for the CDP HTTP port to respond
    String? wsUrl;
    String? targetId;
    String browserName = 'Chromium';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        try {
          final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/json/version'));
          final resp = await req.close();
          if (resp.statusCode == 200) {
            final body = await resp.transform(utf8.decoder).join();
            final json = jsonDecode(body) as Map<String, dynamic>;
            browserName = json['Browser']?.toString() ?? 'Chromium';
            break;
          }
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }

      // Query target page
      final reqPages = await client.getUrl(Uri.parse('http://127.0.0.1:$port/json'));
      final respPages = await reqPages.close();
      final bodyPages = await respPages.transform(utf8.decoder).join();
      final listPages = jsonDecode(bodyPages) as List;
      if (listPages.isNotEmpty) {
        final first = listPages.first as Map<String, dynamic>;
        wsUrl = first['webSocketDebuggerUrl']?.toString();
        targetId = first['id']?.toString();
      }

      if (wsUrl == null) {
        // Create new page if needed
        final reqNew = await client.getUrl(Uri.parse('http://127.0.0.1:$port/json/new'));
        final respNew = await reqNew.close();
        final bodyNew = await respNew.transform(utf8.decoder).join();
        final pageJson = jsonDecode(bodyNew) as Map<String, dynamic>;
        wsUrl = pageJson['webSocketDebuggerUrl']?.toString();
        targetId = pageJson['id']?.toString();
      }
    } finally {
      client.close(force: true);
    }

    if (wsUrl == null || targetId == null) {
      process.kill();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
      throw StateError('Failed to obtain CDP WebSocket debugger URL on port $port');
    }

    final webSocket = await WebSocket.connect(wsUrl);

    return CdpBrowserDriver._(
      browserProcess: process,
      port: port,
      tempDir: tempDir,
      targetId: targetId,
      ws: webSocket,
      browserName: browserName,
    );
  }

  /// Closes the WebSocket and terminates the headless browser process
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await ws.close();
    } catch (_) {}
    try {
      browserProcess.kill();
      await browserProcess.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}
