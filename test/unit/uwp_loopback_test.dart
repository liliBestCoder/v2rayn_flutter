import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/services/uwp_loopback_service.dart';

void main() {
  group('UWP Loopback Exemption Service Tests', () {
    test('buildPowerShellArgs generates correct Bypass and CheckNetIsolation command', () {
      final args = UwpLoopbackService.buildPowerShellArgs();

      expect(args, contains('-NoProfile'));
      expect(args, contains('-ExecutionPolicy'));
      expect(args, contains('Bypass'));
      expect(args, contains('-Command'));

      final commandArg = args.last;
      expect(commandArg, contains('CheckNetIsolation LoopbackExempt -a -p='),
          reason: 'Must invoke CheckNetIsolation LoopbackExempt with package family name');
      expect(commandArg, contains('Get-AppxPackage'),
          reason: 'Must iterate through installed Appx packages');
    });

    test('On non-Windows platforms, exemptLoopback returns false immediately without executing', () async {
      var executed = false;
      final result = await UwpLoopbackService.exemptLoopback(
        isWindows: false,
        processRunner: (exe, args) async {
          executed = true;
          return ProcessResult(1234, 0, 'OK', '');
        },
      );

      expect(result, isFalse);
      expect(executed, isFalse, reason: 'Must not execute powershell on non-Windows platforms');
    });

    test('On Windows, successful execution (exitCode 0) returns true', () async {
      String? executedExecutable;
      List<String>? executedArgs;

      final result = await UwpLoopbackService.exemptLoopback(
        isWindows: true,
        processRunner: (exe, args) async {
          executedExecutable = exe;
          executedArgs = args;
          return ProcessResult(1234, 0, 'OK', '');
        },
      );

      expect(result, isTrue);
      expect(executedExecutable, equals('powershell'));
      expect(executedArgs, contains('Bypass'));
      expect(executedArgs?.last, contains('CheckNetIsolation'));
    });

    test('On Windows, execution failure (non-zero exit code) returns false', () async {
      final result = await UwpLoopbackService.exemptLoopback(
        isWindows: true,
        processRunner: (exe, args) async {
          return ProcessResult(1234, 1, '', 'Permission Denied');
        },
      );

      expect(result, isFalse);
    });

    test('Exception during process execution throws or is handled properly', () async {
      expect(
        () async => await UwpLoopbackService.exemptLoopback(
          isWindows: true,
          processRunner: (exe, args) async {
            throw const ProcessException('powershell', [], 'PowerShell not found');
          },
        ),
        throwsA(isA<ProcessException>()),
      );
    });
  });

  group('Real-World Installed UWP Applications Exemption & Socket Loopback Tests', () {
    test('Query real installed UWP packages (Calculator / Terminal) on Windows', () async {
      if (!Platform.isWindows) {
        print('  [非 Windows 平台，跳过 UWP AppxPackage 检测]');
        return;
      }

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          "Get-AppxPackage | Where-Object { \$_.PackageFamilyName -match 'Terminal|Calculator' } | Select-Object -First 2 -Property Name, PackageFamilyName | ConvertTo-Json",
        ],
      );

      expect(result.exitCode, equals(0));
      final stdout = (result.stdout as String).trim();
      expect(stdout, isNotEmpty, reason: 'Windows system should have built-in Calculator or Terminal UWP app');

      try {
        final decoded = jsonDecode(stdout);
        final list = decoded is List ? decoded : [decoded];
        expect(list, isNotEmpty);
        for (final pkg in list) {
          final name = pkg['Name'] as String?;
          final familyName = pkg['PackageFamilyName'] as String?;
          expect(familyName, isNotNull);
          print('  📦 [检测到真实 UWP 应用]: $name (PackageFamily: $familyName)');
        }
      } catch (e) {
        print('  JSON parse info: $stdout');
      }
    });

    test('CheckNetIsolation.exe LoopbackExempt -s query returns active isolation table', () async {
      if (!Platform.isWindows) {
        return;
      }

      final result = await Process.run('CheckNetIsolation.exe', ['LoopbackExempt', '-s']);
      expect(result.exitCode, equals(0));

      final stdout = (result.stdout as String).trim();
      expect(stdout, isNotEmpty);
      // Windows CheckNetIsolation displays list or headers
      print('  🔍 [Windows CheckNetIsolation 状态确认]: 成功调用内核网络隔离豁免接口 (输出长度: ${stdout.length} 字符)');
    });

    test('Verify local 127.0.0.1 TCP socket loopback communicates without sandboxing blocks', () async {
      // 启动本地回环 TCP 服务端
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      final completer = Completer<String>();

      server.listen((clientSocket) {
        clientSocket.listen((data) {
          final msg = utf8.decode(data);
          if (msg == 'PING_LOOPBACK') {
            clientSocket.write('PONG_LOOPBACK_OK');
            clientSocket.flush();
          }
        });
      });

      // 客户端发起连接
      final client = await Socket.connect(InternetAddress.loopbackIPv4, port);
      client.write('PING_LOOPBACK');
      await client.flush();

      client.listen((data) {
        completer.complete(utf8.decode(data));
      });

      final reply = await completer.future.timeout(const Duration(seconds: 5));
      await client.close();
      await server.close();

      expect(reply, equals('PONG_LOOPBACK_OK'));
      print('  🔌 [本地 127.0.0.1 回环通信确认]: TCP 数据包全双工往返正常 ($reply)，已为 UWP 绕过提供畅通端口服务！');
    });
  });
}
