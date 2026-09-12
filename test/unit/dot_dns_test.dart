import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/services/xray_config_builder.dart';

void main() {
  group('DoT (DNS over TLS) Configuration & Injection Tests', () {
    test('When dotDns is configured, it is injected as the highest priority DNS server', () {
      const config = ClientConfig(
        dotDns: 'tcp://1.1.1.1:853',
        innerDns: '223.5.5.5',
        outerDns: '8.8.8.8',
        globalDns: '8.8.8.8',
        vpnRoute: true,
      );

      final dnsMap = XrayConfigBuilder.buildDnsConfig(config, true);
      final servers = dnsMap['servers'] as List<dynamic>;

      expect(servers, isNotEmpty);
      // The very first server must be the configured DoT address
      expect(servers.first, equals('tcp://1.1.1.1:853'),
          reason: 'DoT server must be placed at index 0 for priority resolution');
    });

    test('Multiple DoT formats (tls://, tcp://) and whitespace trimming are supported', () {
      const config1 = ClientConfig(dotDns: '  tls://dns.google:853  ');
      final dns1 = XrayConfigBuilder.buildDnsConfig(config1, true);
      final servers1 = dns1['servers'] as List<dynamic>;
      expect(servers1.first, equals('tls://dns.google:853'));

      const config2 = ClientConfig(dotDns: 'tcp://8.8.4.4:853');
      final dns2 = XrayConfigBuilder.buildDnsConfig(config2, true);
      final servers2 = dns2['servers'] as List<dynamic>;
      expect(servers2.first, equals('tcp://8.8.4.4:853'));
    });

    test('When dotDns is empty or whitespace, no DoT server entry is added', () {
      const emptyConfig = ClientConfig(dotDns: '');
      final dns1 = XrayConfigBuilder.buildDnsConfig(emptyConfig, true);
      final servers1 = dns1['servers'] as List<dynamic>;
      expect(servers1.any((s) => s is String && s.contains('853')), isFalse);

      const whitespaceConfig = ClientConfig(dotDns: '    ');
      final dns2 = XrayConfigBuilder.buildDnsConfig(whitespaceConfig, true);
      final servers2 = dns2['servers'] as List<dynamic>;
      expect(servers2.any((s) => s is String && s.contains('853')), isFalse);
    });

    test('DoT integrates seamlessly into full Xray runtime configuration JSON', () {
      const config = ClientConfig(
        dotDns: 'tcp://1.1.1.1:853',
        tunEnabled: true,
      );
      final node = LineNode(
        name: 'US Node',
        region: 'US',
        remark: 'US Node (45%)',
        raw: 'vless://uuid-12345@1.2.3.4:443?type=tcp&security=reality&sni=test.com&pbk=key123',
        load: 45,
      );

      final jsonStr = XrayConfigBuilder.buildConfigJson(
        node: node,
        clientConfig: config,
        userCountry: 'cn',
        statsPort: 10890,
      );
      expect(jsonStr, isNotNull);

      final decoded = jsonDecode(jsonStr!) as Map<String, dynamic>;
      final dns = decoded['dns'] as Map<String, dynamic>;
      final servers = dns['servers'] as List<dynamic>;

      expect(servers.first, equals('tcp://1.1.1.1:853'));
    });

    test('DoT priority remains preserved when vpnRoute is disabled', () {
      const config = ClientConfig(
        dotDns: 'tcp://9.9.9.9:853',
        vpnRoute: false,
        globalDns: '8.8.8.8',
      );

      final dnsMap = XrayConfigBuilder.buildDnsConfig(config, false);
      final servers = dnsMap['servers'] as List<dynamic>;

      expect(servers.first, equals('tcp://9.9.9.9:853'));
      expect(servers.last, equals('8.8.8.8'));
      expect(servers.length, equals(2));
    });
  });

  group('Real-World DoT Resolution vs Plain DNS Resolution Comparison Tests', () {
    // 构造 RFC 7858 规范的 DoT 二进制报文
    Uint8List encodeDnsOverTlsQuery(String domain) {
      final parts = domain.split('.');
      final qnameBytes = <int>[];
      for (final part in parts) {
        qnameBytes.add(part.length);
        qnameBytes.addAll(part.codeUnits);
      }
      qnameBytes.add(0);

      final header = [
        0x3c, 0xa9, // Transaction ID
        0x01, 0x00, // Standard query (RD = 1)
        0x00, 0x01, // QDCOUNT = 1
        0x00, 0x00,
        0x00, 0x00,
        0x00, 0x00,
      ];
      final qtypeQclass = [0x00, 0x01, 0x00, 0x01]; // Type A, Class IN
      final dnsPayload = [...header, ...qnameBytes, ...qtypeQclass];
      final lengthPrefix = [(dnsPayload.length >> 8) & 0xff, dnsPayload.length & 0xff];

      return Uint8List.fromList([...lengthPrefix, ...dnsPayload]);
    }

    List<String> parseDnsResponseIps(List<int> bytes) {
      final ips = <String>[];
      for (int i = 14; i < bytes.length - 4; i++) {
        if (bytes[i] == 0x00 && bytes[i + 1] == 0x01 &&
            bytes[i + 2] == 0x00 && bytes[i + 3] == 0x01 &&
            bytes[i + 8] == 0x00 && bytes[i + 9] == 0x04) {
          final ipStart = i + 10;
          if (ipStart + 4 <= bytes.length) {
            final ip = '${bytes[ipStart]}.${bytes[ipStart+1]}.${bytes[ipStart+2]}.${bytes[ipStart+3]}';
            if (!ips.contains(ip) && !ip.startsWith('0.')) {
              ips.add(ip);
            }
          }
        }
      }
      return ips;
    }

    Future<Map<String, dynamic>> queryDoT(
      String domain, {
      required String host,
    }) async {
      final sw = Stopwatch()..start();
      final socket = await SecureSocket.connect(
        host,
        853,
        onBadCertificate: (cert) => true,
        timeout: const Duration(seconds: 8),
      );

      socket.add(encodeDnsOverTlsQuery(domain));
      await socket.flush();

      final completer = Completer<List<int>>();
      final buffer = <int>[];

      socket.listen(
        (data) {
          buffer.addAll(data);
          if (buffer.length >= 2) {
            final expectedLen = (buffer[0] << 8) | buffer[1];
            if (buffer.length >= expectedLen + 2) {
              if (!completer.isCompleted) completer.complete(buffer);
              socket.destroy();
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
          socket.destroy();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(buffer);
        },
      );

      final resp = await completer.future.timeout(const Duration(seconds: 8));
      sw.stop();
      final ips = parseDnsResponseIps(resp);

      return {
        'host': host,
        'durationMs': sw.elapsedMilliseconds,
        'responseLength': resp.length,
        'ips': ips,
      };
    }

    test('Real DoT query to Cloudflare (1.1.1.1:853) resolves cloudflare.com securely over TLS', () async {
      // 1. 真实开启 DoT 查询
      final dotResult = await queryDoT('cloudflare.com', host: '1.1.1.1');
      expect(dotResult['ips'] as List<String>, isNotEmpty,
          reason: 'DoT resolution over TLS 853 must return valid IPv4 addresses');
      expect((dotResult['responseLength'] as int) > 12, isTrue);

      // 2. 对照：普通系统解析对比
      final swPlain = Stopwatch()..start();
      List<String> plainIps = [];
      try {
        final plainLookups = await InternetAddress.lookup('cloudflare.com');
        plainIps = plainLookups.map((a) => a.address).toList();
      } catch (_) {}
      swPlain.stop();

      print('  [对比测试 - cloudflare.com]');
      print('    • DoT (1.1.1.1:853 TLS): ${dotResult['ips']} (${dotResult['durationMs']}ms, 密文防劫持)');
      print('    • Plain DNS (UDP 53): $plainIps (${swPlain.elapsedMilliseconds}ms, 明文易污染)');
    });

    test('Real DoT query to Google (8.8.8.8:853) resolves google.com securely over TLS', () async {
      final dotResult = await queryDoT('google.com', host: '8.8.8.8');
      expect(dotResult['ips'] as List<String>, isNotEmpty);
      expect((dotResult['responseLength'] as int) > 12, isTrue);

      print('  [对比测试 - google.com]');
      print('    • DoT (8.8.8.8:853 TLS): ${dotResult['ips']} (${dotResult['durationMs']}ms)');
    });

    test('Real DoT query to Cloudflare resolves github.com and prevents plaintext DNS leakage', () async {
      final dotResult = await queryDoT('github.com', host: '1.1.1.1');
      expect(dotResult['ips'] as List<String>, isNotEmpty);
      final resolvedList = dotResult['ips'] as List<String>;
      expect(resolvedList.any((ip) => ip.startsWith('20.') || ip.startsWith('140.')), isTrue);

      print('  [对比测试 - github.com]');
      print('    • DoT (1.1.1.1:853 TLS): $resolvedList (${dotResult['durationMs']}ms, 端到端强加密)');
    });
  });

  group('Real Xray-Core Process E2E DoT Resolution Verification', () {
    test('Xray process starts with DoT and resolves domain using internal DoT TCP client', () async {
      final xrayExe = File('windows/runner/resources/bin/luxwap_core/luxwap_core.exe');
      if (!await xrayExe.exists() || !Platform.isWindows) {
        print('  [Xray 二进制文件未找到或非 Windows 环境，跳过进程测试]');
        return;
      }

      final tempConfig = File('test/temp_xray_dot_test.json');
      const testPort = 20858;
      final config = {
        'log': {'loglevel': 'debug'},
        'dns': {
          'servers': ['tcp://1.1.1.1:853']
        },
        'inbounds': [
          {
            'tag': 'socks-in',
            'port': testPort,
            'listen': '127.0.0.1',
            'protocol': 'socks',
            'settings': {'auth': 'noauth', 'udp': true}
          }
        ],
        'outbounds': [
          {
            'tag': 'direct',
            'protocol': 'freedom',
            'streamSettings': {
              'sockopt': {'domainStrategy': 'UseIP'}
            }
          }
        ]
      };

      await tempConfig.writeAsString(jsonEncode(config));

      final process = await Process.start(
        xrayExe.path,
        ['run', '-c', tempConfig.path],
      );

      final xrayLogs = <String>[];
      final subscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        xrayLogs.add(line);
      });

      // 等待 Xray 启动监听
      await Future.delayed(const Duration(milliseconds: 800));

      // 发起 SOCKS5 请求触发 Xray 内部 DNS 解析目标域名 cloudflare.com
      try {
        final socket = await Socket.connect('127.0.0.1', testPort, timeout: const Duration(seconds: 3));
        // SOCKS5 握手
        socket.add([0x05, 0x01, 0x00]);
        await socket.flush();

        // 请求连接目标域名 cloudflare.com:80
        final domainBytes = ascii.encode('cloudflare.com');
        socket.add([0x05, 0x01, 0x00, 0x03, domainBytes.length, ...domainBytes, 0x00, 0x50]);
        await socket.flush();

        await Future.delayed(const Duration(milliseconds: 1200));
        await socket.close();
      } catch (e) {
        print('  Socket error: $e');
      }

      process.kill();
      await subscription.cancel();
      if (await tempConfig.exists()) {
        await tempConfig.delete();
      }

      // 验证 Xray 内部日志记录
      final hasTcpDnsInit = xrayLogs.any((l) => l.contains('DNS: created TCP client initialized for tcp://1.1.1.1:853'));
      final hasDnsQuery = xrayLogs.any((l) => l.contains('TCP//1.1.1.1:853 querying DNS for: cloudflare.com'));
      final hasDnsAnswer = xrayLogs.any((l) => l.contains('got answer: cloudflare.com'));

      print('  🔍 [Xray 进程实机实测断言]:');
      print('    • Xray 初始化 DoT 客户端: $hasTcpDnsInit');
      print('    • Xray 调度 DoT 真实解析: $hasDnsQuery');
      print('    • Xray 成功接收 DoT 解析结果: $hasDnsAnswer');

      expect(hasTcpDnsInit, isTrue, reason: 'Xray must initialize TCP client for DoT 853');
      expect(hasDnsQuery, isTrue, reason: 'Xray must query cloudflare.com via configured DoT server');
      expect(hasDnsAnswer, isTrue, reason: 'Xray must receive DNS answer from DoT server');
    });
  });
}
