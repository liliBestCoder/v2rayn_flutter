import 'dart:io';

class UwpLoopbackService {
  static const String powershellCommand =
      r'Get-AppxPackage | ForEach-Object { & CheckNetIsolation LoopbackExempt -a -p=$($_.PackageFamilyName) }';

  static List<String> buildPowerShellArgs() {
    return [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      powershellCommand,
    ];
  }

  static Future<bool> exemptLoopback({
    Future<ProcessResult> Function(String executable, List<String> arguments)? processRunner,
    bool? isWindows,
  }) async {
    final onWindows = isWindows ?? Platform.isWindows;
    if (!onWindows) {
      return false;
    }
    final runner = processRunner ?? Process.run;
    final res = await runner('powershell', buildPowerShellArgs());
    return res.exitCode == 0;
  }
}
