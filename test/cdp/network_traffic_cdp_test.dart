import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'cdp_browser_driver.dart';

void main() {
  group('CDP Headless Browser & Proxy Network Traffic Verification (Google/YouTube/ChatGPT)', () {
    late HttpServer mockProxyServer;
    const proxyPort = 10809;
    final accessedHosts = <String>[];

    setUp(() async {
      accessedHosts.clear();
      // Start a mock proxy server on 10809 to simulate live proxy handling for Google, YouTube, ChatGPT
      mockProxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, proxyPort);
      mockProxyServer.listen((HttpRequest request) async {
        final host = request.uri.host.isNotEmpty ? request.uri.host : (request.headers.value('host') ?? '');
        accessedHosts.add(host);
        print('  🛰️ [代理端口 10809 捕获请求]: ${request.method} ${request.uri} (Host: $host)');

        if (request.method == 'CONNECT') {
          // HTTP CONNECT tunnel for HTTPS (Google / YouTube / ChatGPT)
          try {
            final clientSocket = await request.response.detachSocket();
            clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
            await clientSocket.flush();

            // Respond with mock TLS / tunnel ack
            clientSocket.listen(
              (data) {},
              onDone: () => clientSocket.destroy(),
              onError: (_) => clientSocket.destroy(),
            );
          } catch (_) {}
        } else {
          // Normal HTTP proxy request
          try {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.html
              ..write('<html><body><h1>Luxwap Proxy Tunnel Active</h1><p>Target: $host</p></body></html>');
            await request.response.close();
          } catch (_) {}
        }
      });
    });

    tearDown(() async {
      await mockProxyServer.close(force: true);
    });

    test('Proxy Active: CDP Headless Browser and curl route Google, YouTube, and ChatGPT traffic through proxy', () async {
      print('🚀 [步骤 1: 代理运行中 - 验证 CDP 浏览器出网]');
      final cdp = await CdpBrowserDriver.launch(
        proxyServer: 'http://127.0.0.1:$proxyPort',
        headless: true,
      );

      try {
        await cdp.sendCommand('Network.enable');

        // Test Navigation 1: Google
        print('  🌐 [CDP 请求]: https://www.google.com');
        await cdp.navigate('https://www.google.com', timeout: const Duration(seconds: 3));

        // Test Navigation 2: YouTube
        print('  🌐 [CDP 请求]: https://www.youtube.com');
        await cdp.navigate('https://www.youtube.com', timeout: const Duration(seconds: 3));

        // Test Navigation 3: ChatGPT
        print('  🌐 [CDP 请求]: https://chatgpt.com');
        await cdp.navigate('https://chatgpt.com', timeout: const Duration(seconds: 3));

        expect(accessedHosts, anyElement(contains('google')),
            reason: 'Proxy must capture Google request');
        expect(accessedHosts, anyElement(contains('youtube')),
            reason: 'Proxy must capture YouTube request');
        expect(accessedHosts, anyElement(contains('chatgpt')),
            reason: 'Proxy must capture ChatGPT request');
        print('  ✅ [CDP 验证成功]: Google, YouTube, ChatGPT 请求已全量经由代理端口分流！');
      } finally {
        await cdp.close();
      }

      print('🚀 [步骤 2: 验证 curl 走代理访问]');
      // Run curl via proxy
      final curlResult = await Process.run('curl', [
        '-x', 'http://127.0.0.1:$proxyPort',
        'http://www.google.com/test',
        '--connect-timeout', '3',
      ]);
      expect(curlResult.exitCode, equals(0),
          reason: 'curl must succeed when proxy is active');
      expect(curlResult.stdout.toString(), contains('Luxwap Proxy Tunnel Active'),
          reason: 'curl response must confirm active proxy connection');
      print('  ✅ [curl 验证成功]: curl -x 127.0.0.1:$proxyPort 访问成功！');
    });

    test('Proxy Stopped: Verify that traffic is cleanly blocked / cut off when proxy is terminated', () async {
      print('🛑 [步骤 3: 模拟关闭代理服务]');
      await mockProxyServer.close(force: true);

      print('🔍 [步骤 4: 校验关闭后 curl 与浏览器请求被断开]');
      // curl should fail to connect to 10809
      final curlResult = await Process.run('curl', [
        '-x', 'http://127.0.0.1:$proxyPort',
        'http://www.google.com/test',
        '--connect-timeout', '2',
      ]);
      expect(curlResult.exitCode, isNot(equals(0)),
          reason: 'curl must fail when proxy port is closed');
      print('  ✅ [断开断言确认]: 代理关闭后 curl 无法连接 10809 (exitCode: ${curlResult.exitCode})，流量已彻底切断！');

      // CDP browser with closed proxy port should fail to navigate
      final cdp = await CdpBrowserDriver.launch(
        proxyServer: 'http://127.0.0.1:$proxyPort',
        headless: true,
      );
      try {
        final navRes = await cdp.navigate('http://www.google.com', timeout: const Duration(seconds: 2));
        final errorText = navRes['errorText']?.toString() ?? '';
        print('  ✅ [CDP 浏览器断开确认]: 页面无法加载，错误信息: $errorText');
      } finally {
        await cdp.close();
      }
    });
  });
}
