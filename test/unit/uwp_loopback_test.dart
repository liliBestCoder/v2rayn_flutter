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
}
