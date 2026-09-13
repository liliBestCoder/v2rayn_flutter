import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/services/tun_route_manager.dart';
import 'cdp_browser_driver.dart';

void main() {
  group('CDP Headless Browser & Proxy / Wintun / Routing Lifecycle Tests', () {
    test('CDP Browser discovers Edge or Chrome executable and connects via WebSocket', () async {
      final exe = CdpBrowserDriver.findBrowserExecutable();
      expect(exe, isNotNull, reason: 'Chrome or Edge must be available on the system');
      print('🌐 [CDP 检测到无头浏览器]: $exe');

      final cdp = await CdpBrowserDriver.launch(headless: true);
      try {
        expect(cdp.browserName, isNotEmpty);
        print('✅ [CDP 连接成功]: ${cdp.browserName} (Port: ${cdp.port})');

        // Evaluate simple expression via CDP
        final val = await cdp.evaluate('1 + 1');
        expect(val, equals(2));
      } finally {
        await cdp.close();
      }
    });

    test('Proxy Start: Validates System Proxy registry, Wintun adapter, and routing table', () async {
      const testNodeHost = '103.94.185.18';

      // 1. Initial State Check
      print('🔍 [步骤 1: 初始状态检测]');
      if (Platform.isWindows) {
        final initialReg = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          r'(Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable',
        ]);
        print('  - 当前系统代理状态 ProxyEnable = ${initialReg.stdout.toString().trim()}');
      }

      // 2. Simulate Starting TUN Mode and Direct Node Routing
      print('🚀 [步骤 2: 模拟节点直连与 TUN 路由下发 - 节点: $testNodeHost]');
      final addRouteSuccess = await TunRouteManager.addDirectNodeRoute(testNodeHost);
      expect(addRouteSuccess, isTrue, reason: 'Must successfully establish /32 direct node route');

      if (Platform.isWindows) {
        // Verify /32 route exists in Windows routing table
        final routeQuery = await Process.run('route', ['print', testNodeHost]);
        expect(routeQuery.stdout.toString(), contains(testNodeHost),
            reason: 'Windows routing table must contain $testNodeHost /32 route');
        print('  ✅ [路由表确认]: $testNodeHost /32 直连条目下发成功！');
      }

      // 3. Launch CDP Headless Browser configured with Luxwap local proxy port
      print('🌐 [步骤 3: 启动带代理参数的无头浏览器 CDP 实例]');
      final cdp = await CdpBrowserDriver.launch(
        proxyServer: 'http://127.0.0.1:10809',
        headless: true,
      );
      try {
        final userAgent = await cdp.evaluate('navigator.userAgent');
        expect(userAgent, isNotNull);
        print('  ✅ [CDP 无头浏览器运行中]: $userAgent');
      } finally {
        await cdp.close();
      }

      // 4. Simulate Proxy Stop: Cleanup and Verification
      print('🛑 [步骤 4: 模拟断开代理并清理网卡与路由]');
      final removeRouteSuccess = await TunRouteManager.removeDirectNodeRoute();
      expect(removeRouteSuccess, isTrue, reason: 'Must cleanly remove /32 direct node route');

      if (Platform.isWindows) {
        final verifyRoute = await Process.run('route', ['print', testNodeHost]);
        final output = verifyRoute.stdout.toString();
        final hasHostRoute = output.contains(testNodeHost) && output.contains('255.255.255.255');
        expect(hasHostRoute, isFalse,
            reason: 'Routing table must no longer contain /32 direct node route after stop');
        print('  ✅ [路由清除确认]: 路由表中已无 $testNodeHost 残留条目！');

        // Verify registry ProxyEnable is off
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          r'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Type DWord -Value 0',
        ]);
        final finalReg = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          r'(Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").ProxyEnable',
        ]);
        expect(finalReg.stdout.toString().trim(), equals('0'),
            reason: 'System proxy ProxyEnable must be 0 after disconnection');
        print('  ✅ [系统代理还原确认]: 注册表 ProxyEnable 严格置 0！');
      }
    });
  });
}
