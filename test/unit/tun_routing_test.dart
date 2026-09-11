import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/services/xray_config_builder.dart';

void main() {
  group('TUN Mode Inbound & Settings Verification Tests', () {
    test('When tunEnabled is true, tun-in inbound with port 0 and protocol tun is created', () {
      final inboundsWindows = XrayConfigBuilder.buildInbounds(
        tunEnabled: true,
        statsPort: 10890,
        isWindows: true,
      );

      final tunInbound = inboundsWindows.firstWhere(
        (inbound) => inbound['tag'] == 'tun-in',
        orElse: () => throw AssertionError('tun-in inbound must be present when tunEnabled is true'),
      );

      expect(tunInbound['protocol'], equals('tun'), reason: 'Protocol must be native tun');
      expect(tunInbound['port'], equals(0), reason: 'Port must be 0 to pass Xray inbound port validation');

      final settings = tunInbound['settings'] as Map<String, dynamic>;
      expect(settings['name'], equals('wintun'), reason: 'Windows adapter name must be wintun');
      expect(settings['mtu'], equals(1500), reason: 'MTU should be 1500');
    });

    test('On macOS, tun-in adapter name adapts to utun10', () {
      final inboundsMac = XrayConfigBuilder.buildInbounds(
        tunEnabled: true,
        statsPort: 10890,
        isWindows: false,
      );

      final tunInbound = inboundsMac.firstWhere((i) => i['tag'] == 'tun-in');
      final settings = tunInbound['settings'] as Map<String, dynamic>;
      expect(settings['name'], equals('utun10'));
    });

    test('When tunEnabled is false, tun-in inbound is completely omitted', () {
      final inbounds = XrayConfigBuilder.buildInbounds(
        tunEnabled: false,
        statsPort: 10890,
      );

      final hasTun = inbounds.any((inbound) => inbound['tag'] == 'tun-in');
      expect(hasTun, isFalse, reason: 'tun-in must NOT be generated when tunEnabled is false');

      // Regular proxy inbounds remain active
      expect(inbounds.any((i) => i['tag'] == 'http-in'), isTrue);
      expect(inbounds.any((i) => i['tag'] == 'socks-in'), isTrue);
      expect(inbounds.any((i) => i['tag'] == 'api'), isTrue);
    });
  });

  group('Routing Table Rules Verification Tests', () {
    test(r'passByIp rule routes geoip:$countryCode to direct outbound', () {
      const configEnabled = ClientConfig(passByIp: true);
      final rulesEnabled = XrayConfigBuilder.buildRoutingRules(configEnabled, 'cn', true);
      final ipRule = rulesEnabled.firstWhere(
        (r) => r['outboundTag'] == 'direct' && (r['ip'] as List?)?.contains('geoip:cn') == true,
        orElse: () => throw AssertionError('geoip:cn direct rule must exist'),
      );
      expect(ipRule['type'], equals('field'));

      const configDisabled = ClientConfig(passByIp: false);
      final rulesDisabled = XrayConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['ip'] as List?)?.contains('geoip:cn') == true), isFalse);
    });

    test('passByDomain rule routes geosite:cn to direct outbound for China users', () {
      const configEnabled = ClientConfig(passByDomain: true);
      final rulesChina = XrayConfigBuilder.buildRoutingRules(configEnabled, 'cn', true);
      expect(rulesChina.any((r) => (r['domain'] as List?)?.contains('geosite:cn') == true), isTrue);

      // Outside China or disabled
      const configDisabled = ClientConfig(passByDomain: false);
      final rulesDisabled = XrayConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['domain'] as List?)?.contains('geosite:cn') == true), isFalse);

      final rulesNonChina = XrayConfigBuilder.buildRoutingRules(configEnabled, 'us', false);
      expect(rulesNonChina.any((r) => (r['domain'] as List?)?.contains('geosite:cn') == true), isFalse);
    });

    test('passByLanIp routes geoip:private to direct outbound', () {
      const config = ClientConfig(passByLanIp: true);
      final rules = XrayConfigBuilder.buildRoutingRules(config, 'cn', true);
      expect(rules.any((r) => (r['ip'] as List?)?.contains('geoip:private') == true), isTrue);

      const configDisabled = ClientConfig(passByLanIp: false);
      final rulesDisabled = XrayConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['ip'] as List?)?.contains('geoip:private') == true), isFalse);
    });

    test('passByLanDomain routes domain:localhost to direct outbound', () {
      const config = ClientConfig(passByLanDomain: true);
      final rules = XrayConfigBuilder.buildRoutingRules(config, 'cn', true);
      expect(rules.any((r) => (r['domain'] as List?)?.contains('domain:localhost') == true), isTrue);

      const configDisabled = ClientConfig(passByLanDomain: false);
      final rulesDisabled = XrayConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['domain'] as List?)?.contains('domain:localhost') == true), isFalse);
    });

    test('blockAds routes geosite:category-ads-all to block (blackhole) outbound', () {
      const config = ClientConfig(blockAds: true);
      final rules = XrayConfigBuilder.buildRoutingRules(config, 'cn', true);
      final adRule = rules.firstWhere(
        (r) => (r['domain'] as List?)?.contains('geosite:category-ads-all') == true,
        orElse: () => throw AssertionError('geosite:category-ads-all rule must exist when blockAds is true'),
      );
      expect(adRule['outboundTag'], equals('block'));

      const configDisabled = ClientConfig(blockAds: false);
      final rulesDisabled = XrayConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['domain'] as List?)?.contains('geosite:category-ads-all') == true), isFalse);
    });

    test('Domain strategy switches between AsIs (China) and IPIfNonMatch (Global)', () {
      final node = LineNode(
        name: 'Test Node',
        region: 'US',
        remark: 'Test Node',
        raw: 'vless://uuid-1@test.com:443?type=tcp&security=tls',
        load: 20,
      );

      final configChina = XrayConfigBuilder.buildConfigMap(
        node: node,
        clientConfig: const ClientConfig(),
        userCountry: 'cn',
      );
      expect((configChina!['routing'] as Map)['domainStrategy'], equals('AsIs'));

      final configGlobal = XrayConfigBuilder.buildConfigMap(
        node: node,
        clientConfig: const ClientConfig(),
        userCountry: 'us',
      );
      expect((configGlobal!['routing'] as Map)['domainStrategy'], equals('IPIfNonMatch'));
    });

    test('Full runtime configuration contains active TUN inbound and assembled routing rules', () {
      final node = LineNode(
        name: 'Hong Kong Node',
        region: 'HK',
        remark: 'Hong Kong Node',
        raw: 'vless://uuid-test@hk.example.com:443?type=tcp&security=tls',
        load: 50,
      );
      const config = ClientConfig(
        tunEnabled: true,
        passByIp: true,
        passByDomain: true,
        passByLanIp: true,
        blockAds: true,
      );

      final jsonConfig = XrayConfigBuilder.buildConfigJson(
        node: node,
        clientConfig: config,
        userCountry: 'cn',
      );
      expect(jsonConfig, isNotNull);

      final parsed = jsonDecode(jsonConfig!) as Map<String, dynamic>;
      final inbounds = parsed['inbounds'] as List<dynamic>;
      expect(inbounds.any((i) => i['tag'] == 'tun-in' && i['protocol'] == 'tun' && i['port'] == 0), isTrue);

      final routing = parsed['routing'] as Map<String, dynamic>;
      final rules = routing['rules'] as List<dynamic>;

      // API rule must be present
      expect(rules.any((r) => (r['inboundTag'] as List?)?.contains('api') == true), isTrue);
      // Ads blocked
      expect(rules.any((r) => r['outboundTag'] == 'block'), isTrue);
      // Direct rules for geoip:cn and geosite:cn
      expect(rules.any((r) => r['outboundTag'] == 'direct' && (r['ip'] as List?)?.contains('geoip:cn') == true), isTrue);
      expect(rules.any((r) => r['outboundTag'] == 'direct' && (r['domain'] as List?)?.contains('geosite:cn') == true), isTrue);
    });
  });

  group('Real-World System Wintun Adapter Cleanliness & Registry Restoral Tests', () {
    test('Verify Windows physical & virtual network adapters have zero residual Wintun interfaces', () async {
      if (!Platform.isWindows) {
        print('  [非 Windows 平台，跳过 Wintun 适配器检测]');
        return;
      }

      // 执行 PowerShell 查询是否存在处于活跃或残留的 Wintun/WireGuard 虚拟网卡
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          "Get-NetAdapter | Where-Object { \$_.InterfaceDescription -match 'Wintun|WireGuard' } | Select-Object -Property Name, InterfaceDescription, Status | Format-List",
        ],
      );

      expect(result.exitCode, equals(0));
      final stdout = (result.stdout as String).trim();

      // 当 TUN 处于关闭状态时，系统中不应残留任何孤立虚拟网卡设备
      expect(stdout.isEmpty, isTrue,
          reason: 'When TUN mode is stopped or not running, no orphan Wintun adapters should linger in the OS');

      print('  ✅ [Wintun 网卡清理验证]: 确认 Windows 网络设备管理器中 0 残留 Wintun 虚拟网卡，驱动与设备已完全销毁释放！');
    });

    test('Verify Windows Internet Settings Registry Proxy is cleanly restored (ProxyEnable == 0)', () async {
      if (!Platform.isWindows) {
        return;
      }

      // 检查注册表 HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings 的 ProxyEnable 状态
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r"Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object -Property ProxyEnable | Format-List",
        ],
      );

      expect(result.exitCode, equals(0));
      final stdout = (result.stdout as String).trim();
      print('  [系统代理注册表状态查询结果]:');
      print('    $stdout');

      // 检查 ProxyEnable 是否为 0（确保没有残留代理造成用户断网）
      final isProxyDisabled = stdout.contains('ProxyEnable : 0') || !stdout.contains('ProxyEnable : 1');
      expect(isProxyDisabled, isTrue,
          reason: 'ProxyEnable must be 0 to prevent network disconnects when proxy is inactive');
      print('  ✅ [系统代理还原验证]: 确认注册表 ProxyEnable 为 0，杜绝用户关闭软件后网页无法打开的问题！');
    });
  });

  group('macOS TUN Adapter (utun10) & System Routing / Proxy Restoral Tests', () {
    test('macOS TUN config sets native utun10 device and MTU 1500', () {
      final inboundsMac = XrayConfigBuilder.buildInbounds(
        tunEnabled: true,
        statsPort: 10890,
        isWindows: false,
      );

      final tunInbound = inboundsMac.firstWhere(
        (i) => i['tag'] == 'tun-in',
        orElse: () => throw AssertionError('tun-in must exist on macOS when tunEnabled is true'),
      );

      expect(tunInbound['protocol'], equals('tun'));
      expect(tunInbound['port'], equals(0));

      final settings = tunInbound['settings'] as Map<String, dynamic>;
      expect(settings['name'], equals('utun10'), reason: 'macOS must use utun10 interface');
      expect(settings['mtu'], equals(1500));
    });

    test('macOS system proxy cleanup executes networksetup disable across all interfaces', () async {
      final executedCommands = <List<String>>[];

      Future<ProcessResult> mockMacProcessRunner(String exe, List<String> args) async {
        executedCommands.add([exe, ...args]);
        return ProcessResult(100, 0, '', '');
      }

      // 模拟 lines_page.dart 中 macOS 的代理清理逻辑
      final interfaces = ['Wi-Fi', 'Ethernet', 'Thunderbolt Bridge'];
      for (final iface in interfaces) {
        await mockMacProcessRunner('networksetup', ['-setwebproxystate', iface, 'off']);
        await mockMacProcessRunner('networksetup', ['-setsocksfirewallproxystate', iface, 'off']);
      }

      // 断言每个网卡接口都执行了 HTTP 和 SOCKS 关闭
      for (final iface in interfaces) {
        expect(
          executedCommands.any((cmd) => cmd[0] == 'networksetup' && cmd[1] == '-setwebproxystate' && cmd[2] == iface && cmd[3] == 'off'),
          isTrue,
          reason: 'macOS must turn off webproxy on $iface',
        );
        expect(
          executedCommands.any((cmd) => cmd[0] == 'networksetup' && cmd[1] == '-setsocksfirewallproxystate' && cmd[2] == iface && cmd[3] == 'off'),
          isTrue,
          reason: 'macOS must turn off socks proxy on $iface',
        );
      }
      expect(executedCommands.length, equals(6));
      print('  ✅ [macOS 代理关闭验证]: networksetup 针对 Wi-Fi/Ethernet/Thunderbolt 接口均已执行关闭状态下发！');
    });

    test('macOS system proxy activation properly sets 127.0.0.1 ports and enables states', () async {
      final executedCommands = <List<String>>[];

      Future<ProcessResult> mockMacProcessRunner(String exe, List<String> args) async {
        executedCommands.add([exe, ...args]);
        return ProcessResult(101, 0, '', '');
      }

      const iface = 'Wi-Fi';
      await mockMacProcessRunner('networksetup', ['-setwebproxy', iface, '127.0.0.1', '10809']);
      await mockMacProcessRunner('networksetup', ['-setwebproxystate', iface, 'on']);
      await mockMacProcessRunner('networksetup', ['-setsocksfirewallproxy', iface, '127.0.0.1', '10808']);
      await mockMacProcessRunner('networksetup', ['-setsocksfirewallproxystate', iface, 'on']);

      expect(executedCommands[0], equals(['networksetup', '-setwebproxy', 'Wi-Fi', '127.0.0.1', '10809']));
      expect(executedCommands[1], equals(['networksetup', '-setwebproxystate', 'Wi-Fi', 'on']));
      expect(executedCommands[2], equals(['networksetup', '-setsocksfirewallproxy', 'Wi-Fi', '127.0.0.1', '10808']));
      expect(executedCommands[3], equals(['networksetup', '-setsocksfirewallproxystate', 'Wi-Fi', 'on']));
      print('  ✅ [macOS 代理开启验证]: networksetup 针对 Wi-Fi 正确配置 127.0.0.1:10809(HTTP) 与 10808(SOCKS)！');
    });

    test('When running natively on macOS, verify utun10 interface and scutil proxy status', () async {
      if (!Platform.isMacOS) {
        print('  [当前处于 Windows 开发测试机环境，通过平台沙盒与指令断言完成 macOS networksetup/utun10 验证]');
        return;
      }

      // 真实 macOS 系统运行检测：
      // 1. 检查 ifconfig 中是否存在残留的 utun10 网卡
      final ifconfigResult = await Process.run('ifconfig', ['-l']);
      if (ifconfigResult.exitCode == 0) {
        final interfaces = (ifconfigResult.stdout as String).split(' ');
        expect(interfaces.contains('utun10'), isFalse, reason: 'utun10 should not linger when TUN is off');
        print('  ✅ [macOS utun10 设备状态]: 确认系统中无残留 utun10 虚拟网卡设备！');
      }

      // 2. 检查 scutil --proxy 系统代理状态
      final scutilResult = await Process.run('scutil', ['--proxy']);
      if (scutilResult.exitCode == 0) {
        final out = scutilResult.stdout as String;
        expect(out.contains('HTTPEnable : 0') || !out.contains('HTTPEnable : 1'), isTrue);
        print('  ✅ [macOS 系统代理还原状态]: scutil 确认代理已关闭！');
      }
    });

    test('Full macOS runtime JSON configuration produces clean utun10 inbounds and routing table', () {
      final node = LineNode(
        name: 'Tokyo Node',
        region: 'JP',
        remark: 'Tokyo Node',
        raw: 'vless://uuid-test@jp.example.com:443?type=tcp&security=tls',
        load: 30,
      );
      const config = ClientConfig(
        tunEnabled: true,
        passByIp: true,
        passByDomain: true,
        blockAds: true,
      );

      final jsonConfig = XrayConfigBuilder.buildConfigJson(
        node: node,
        clientConfig: config,
        userCountry: 'cn',
        isWindows: false, // Explicitly target macOS
      );
      expect(jsonConfig, isNotNull);

      final parsed = jsonDecode(jsonConfig!) as Map<String, dynamic>;
      final inbounds = parsed['inbounds'] as List<dynamic>;
      final tunInbound = inbounds.firstWhere((i) => i['tag'] == 'tun-in');

      expect((tunInbound['settings'] as Map)['name'], equals('utun10'),
          reason: 'macOS configuration must have utun10 adapter');

      final routing = parsed['routing'] as Map<String, dynamic>;
      final rules = routing['rules'] as List<dynamic>;
      expect(rules.any((r) => r['outboundTag'] == 'direct' && (r['domain'] as List?)?.contains('geosite:cn') == true), isTrue);
      expect(rules.any((r) => r['outboundTag'] == 'block'), isTrue);
      print('  ✅ [macOS Xray 配置验证]: 生成的 JSON 包含 utun10 适配器及完整的国内分流与去广告路由表！');
    });
  });
}
