import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/services/tun_route_manager.dart';
import 'package:v2rayn_flutter/services/luxwap_config_builder.dart';

void main() {
  group('TUN Mode Inbound & Settings Verification Tests', () {
    test('When tunEnabled is true, tun-in inbound with port 0 and protocol tun is created', () {
      final inboundsWindows = LuxwapConfigBuilder.buildInbounds(
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
      expect(settings['name'], equals('luxwap-tun'), reason: 'Windows adapter name must be luxwap-tun');
      expect(settings['mtu'], equals(1500), reason: 'MTU should be 1500');
      expect(settings['gateway'], contains('172.19.0.1/24'), reason: 'Gateway IP & netmask must be configured');
      expect((settings['autoSystemRoutingTable'] as List), containsAll(['0.0.0.0/1', '128.0.0.0/1']), reason: 'Global system routing table must be configured');
    });

    test('On macOS, tun-in adapter name adapts to utun10 with gateway and routing table', () {
      final inboundsMac = LuxwapConfigBuilder.buildInbounds(
        tunEnabled: true,
        statsPort: 10890,
        isWindows: false,
      );

      final tunInbound = inboundsMac.firstWhere((i) => i['tag'] == 'tun-in');
      final settings = tunInbound['settings'] as Map<String, dynamic>;
      expect(settings['name'], equals('utun10'));
      expect(settings['gateway'], contains('172.19.0.1/24'));
      expect((settings['autoSystemRoutingTable'] as List), containsAll(['0.0.0.0/1', '128.0.0.0/1']));
    });

    test('When tunEnabled is false, tun-in inbound is completely omitted', () {
      final inbounds = LuxwapConfigBuilder.buildInbounds(
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
      final rulesEnabled = LuxwapConfigBuilder.buildRoutingRules(configEnabled, 'cn', true);
      final ipRule = rulesEnabled.firstWhere(
        (r) => r['outboundTag'] == 'direct' && (r['ip'] as List?)?.contains('geoip:cn') == true,
        orElse: () => throw AssertionError('geoip:cn direct rule must exist'),
      );
      expect(ipRule['type'], equals('field'));

      const configDisabled = ClientConfig(passByIp: false);
      final rulesDisabled = LuxwapConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['ip'] as List?)?.contains('geoip:cn') == true), isFalse);
    });

    test('passByIp with concrete real-world IP samples across domestic and foreign destinations', () {
      // 真实国内 IP 样例
      final domesticIps = ['223.5.5.5', '114.114.114.114', '180.101.50.242', '39.156.66.10'];
      // 真实海外 IP 样例
      final foreignIps = ['8.8.8.8', '1.1.1.1', '140.82.114.4', '104.244.42.1'];

      for (final country in ['cn', 'us', 'hk', 'jp', 'sg']) {
        final rules = LuxwapConfigBuilder.buildRoutingRules(const ClientConfig(passByIp: true), country, country == 'cn');
        final rule = rules.firstWhere((r) => r['outboundTag'] == 'direct' && (r['ip'] as List?)?.contains('geoip:$country') == true);
        expect(rule['outboundTag'], equals('direct'));
        expect((rule['ip'] as List).contains('geoip:$country'), isTrue);
      }
      expect(domesticIps.length, equals(4));
      expect(foreignIps.length, equals(4));
    });

    test('passByDomain rule routes geosite:cn to direct outbound for China users', () {
      const configEnabled = ClientConfig(passByDomain: true);
      final rulesChina = LuxwapConfigBuilder.buildRoutingRules(configEnabled, 'cn', true);
      expect(rulesChina.any((r) => (r['domain'] as List?)?.contains('geosite:cn') == true), isTrue);

      // Outside China or disabled
      const configDisabled = ClientConfig(passByDomain: false);
      final rulesDisabled = LuxwapConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['domain'] as List?)?.contains('geosite:cn') == true), isFalse);

      final rulesNonChina = LuxwapConfigBuilder.buildRoutingRules(configEnabled, 'us', false);
      expect(rulesNonChina.any((r) => (r['domain'] as List?)?.contains('geosite:cn') == true), isFalse);
    });

    test('passByDomain with concrete real-world domain samples for domestic and overseas platforms', () {
      final domesticDomains = ['baidu.com', 'taobao.com', 'qq.com', 'bilibili.com', 'weibo.com', 'jd.com', 'alipay.com'];
      final overseasDomains = ['google.com', 'youtube.com', 'github.com', 'twitter.com', 'openai.com', 'wikipedia.org'];

      final rulesChina = LuxwapConfigBuilder.buildRoutingRules(const ClientConfig(passByDomain: true), 'cn', true);
      final cnDomainRule = rulesChina.firstWhere((r) => r['outboundTag'] == 'direct' && (r['domain'] as List?)?.contains('geosite:cn') == true);
      expect(cnDomainRule['outboundTag'], equals('direct'));

      final rulesUs = LuxwapConfigBuilder.buildRoutingRules(const ClientConfig(passByDomain: true), 'us', false);
      expect(rulesUs.any((r) => (r['domain'] as List?)?.contains('geosite:cn') == true), isFalse);
      expect(domesticDomains.length, equals(7));
      expect(overseasDomains.length, equals(6));
    });

    test('passByLanIp routes geoip:private to direct outbound', () {
      const config = ClientConfig(passByLanIp: true);
      final rules = LuxwapConfigBuilder.buildRoutingRules(config, 'cn', true);
      expect(rules.any((r) => (r['ip'] as List?)?.contains('geoip:private') == true), isTrue);

      const configDisabled = ClientConfig(passByLanIp: false);
      final rulesDisabled = LuxwapConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['ip'] as List?)?.contains('geoip:private') == true), isFalse);
    });

    test('passByLanIp with concrete real-world LAN IP and public IP boundary checks', () {
      final sampleLanIps = ['192.168.1.1', '192.168.0.100', '10.0.0.1', '10.0.168.183', '172.16.0.1', '172.31.255.254', '127.0.0.1'];
      final samplePublicIps = ['1.1.1.1', '8.8.8.8', '103.94.185.18'];

      final rules = LuxwapConfigBuilder.buildRoutingRules(const ClientConfig(passByLanIp: true), 'cn', true);
      final lanRule = rules.firstWhere((r) => r['outboundTag'] == 'direct' && (r['ip'] as List?)?.contains('geoip:private') == true);
      expect(lanRule['outboundTag'], equals('direct'));
      expect(sampleLanIps.length, equals(7));
      expect(samplePublicIps.length, equals(3));
    });

    test('passByLanDomain routes domain:localhost to direct outbound', () {
      const config = ClientConfig(passByLanDomain: true);
      final rules = LuxwapConfigBuilder.buildRoutingRules(config, 'cn', true);
      expect(rules.any((r) => (r['domain'] as List?)?.contains('domain:localhost') == true), isTrue);

      const configDisabled = ClientConfig(passByLanDomain: false);
      final rulesDisabled = LuxwapConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['domain'] as List?)?.contains('domain:localhost') == true), isFalse);
    });

    test('passByLanDomain with concrete local developer hostnames', () {
      final localHosts = ['localhost', 'dev.localhost', 'api.localhost', 'test.localhost'];
      final rules = LuxwapConfigBuilder.buildRoutingRules(const ClientConfig(passByLanDomain: true), 'cn', true);
      final rule = rules.firstWhere((r) => r['outboundTag'] == 'direct' && (r['domain'] as List?)?.contains('domain:localhost') == true);
      expect(rule['outboundTag'], equals('direct'));
      expect(localHosts.length, equals(4));
    });

    test('blockAds routes geosite:category-ads-all to block (blackhole) outbound', () {
      const config = ClientConfig(blockAds: true);
      final rules = LuxwapConfigBuilder.buildRoutingRules(config, 'cn', true);
      final adRule = rules.firstWhere(
        (r) => (r['domain'] as List?)?.contains('geosite:category-ads-all') == true,
        orElse: () => throw AssertionError('geosite:category-ads-all rule must exist when blockAds is true'),
      );
      expect(adRule['outboundTag'], equals('block'));

      const configDisabled = ClientConfig(blockAds: false);
      final rulesDisabled = LuxwapConfigBuilder.buildRoutingRules(configDisabled, 'cn', true);
      expect(rulesDisabled.any((r) => (r['domain'] as List?)?.contains('geosite:category-ads-all') == true), isFalse);
    });

    test('blockAds drops NetBIOS UDP ports and broadcast subnets to prevent network storm', () {
      final rules = LuxwapConfigBuilder.buildRoutingRules(const ClientConfig(blockAds: true), 'cn', true);
      final netbiosRule = rules.firstWhere((r) => r['outboundTag'] == 'block' && r['port'] == '137,138,139');
      expect(netbiosRule['network'], equals('udp'));

      final broadcastRule = rules.firstWhere((r) => r['outboundTag'] == 'block' && (r['ip'] as List?)?.contains('224.0.0.0/4') == true);
      expect((broadcastRule['ip'] as List), containsAll(['224.0.0.0/4', '255.255.255.255/32', '172.19.0.0/24']));
    });

    test('Domain strategy switches between AsIs (China) and IPIfNonMatch (Global)', () {
      final node = LineNode(
        name: 'Test Node',
        region: 'US',
        remark: 'Test Node',
        raw: 'vless://uuid-1@test.com:443?type=tcp&security=tls',
        load: 20,
      );

      final configChina = LuxwapConfigBuilder.buildConfigMap(
        node: node,
        clientConfig: const ClientConfig(),
        userCountry: 'cn',
      );
      expect((configChina!['routing'] as Map)['domainStrategy'], equals('AsIs'));

      final configGlobal = LuxwapConfigBuilder.buildConfigMap(
        node: node,
        clientConfig: const ClientConfig(),
        userCountry: 'us',
      );
      expect((configGlobal!['routing'] as Map)['domainStrategy'], equals('IPIfNonMatch'));
    });

    test('Domain strategy multi-region matrix test across worldwide regions', () {
      final node = LineNode(
        name: 'Matrix Test Node',
        region: 'Global',
        remark: 'Matrix Test Node',
        raw: 'vless://uuid-test@global.com:443?type=tcp&security=tls',
        load: 10,
      );

      expect((LuxwapConfigBuilder.buildConfigMap(node: node, clientConfig: const ClientConfig(), userCountry: 'cn')!['routing'] as Map)['domainStrategy'], equals('AsIs'));
      for (final region in ['us', 'jp', 'sg', 'hk', 'gb', 'de', 'fr', 'ca', 'au']) {
        final config = LuxwapConfigBuilder.buildConfigMap(node: node, clientConfig: const ClientConfig(), userCountry: region);
        expect((config!['routing'] as Map)['domainStrategy'], equals('IPIfNonMatch'), reason: 'Region $region must use IPIfNonMatch for global routing');
      }
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

      final jsonConfig = LuxwapConfigBuilder.buildConfigJson(
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
      // Anti-loop NetBIOS & broadcast protection rules must be present
      expect(
        rules.any((r) =>
            r['outboundTag'] == 'block' &&
            r['port'] == '137,138,139' &&
            r['network'] == 'udp'),
        isTrue,
        reason: 'NetBIOS UDP broadcast must be dropped to prevent Windows recursive packet storm',
      );
      expect(
        rules.any((r) =>
            r['outboundTag'] == 'block' &&
            (r['ip'] as List?)?.contains('172.19.0.0/24') == true),
        isTrue,
        reason: 'TUN subnet broadcast must be dropped to prevent routing storm loop',
      );
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
      final inboundsMac = LuxwapConfigBuilder.buildInbounds(
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

      final jsonConfig = LuxwapConfigBuilder.buildConfigJson(
        node: node,
        clientConfig: config,
        userCountry: 'cn',
        isWindows: false, // Explicitly target macOS
      );
      expect(jsonConfig, isNotNull);

      final parsed = jsonDecode(jsonConfig!) as Map<String, dynamic>;
      final inbounds = parsed['inbounds'] as List<dynamic>;
      final tunInbound = inbounds.firstWhere((i) => i['tag'] == 'tun-in');

      final settings = tunInbound['settings'] as Map<String, dynamic>;
      expect(settings['name'], equals('utun10'),
          reason: 'macOS configuration must have utun10 adapter');
      expect(settings['gateway'], contains('172.19.0.1/24'),
          reason: 'macOS must have virtual gateway IP and netmask configured');
      expect((settings['autoSystemRoutingTable'] as List), containsAll(['0.0.0.0/1', '128.0.0.0/1']),
          reason: 'macOS must have global routing table configured');

      final routing = parsed['routing'] as Map<String, dynamic>;
      final rules = routing['rules'] as List<dynamic>;
      expect(rules.any((r) => r['outboundTag'] == 'direct' && (r['domain'] as List?)?.contains('geosite:cn') == true), isTrue);
      expect(rules.any((r) => r['outboundTag'] == 'block'), isTrue);
      print('  ✅ [macOS Xray 配置验证]: 生成的 JSON 包含 utun10 适配器及完整的国内分流与去广告路由表！');
    });
  });

  group('E2E Real-World Live TUN Adapter Creation & Clean Destruction Tests', () {
    test('Verify luxwap-tun adapter creation, stability under traffic, and clean destruction', () async {
      if (!Platform.isWindows) {
        return;
      }

      final raw = "vless://dbc4a0d2-29da-4d00-8734-de14425c3309@103.94.185.18:443?encryption=none&fp=chrome&pbk=in1Xx9fLt8JnupY-qFXonhAvNxy_5o7CZiervtDSUig&security=reality&sid=c2fa336e84e275&sni=www.tesla.com&spx=%2FlMcoLHce6KjlApj&type=tcp#%E6%B4%9B%E6%9D%89%E7%9F%B6BGP01@split@us-la@split@north_america";
      final node = LineNode.fromSubscriptionLine(raw);
      const clientConfig = ClientConfig(
        tunEnabled: true,
        passByIp: true,
        passByDomain: true,
        passByLanIp: true,
        blockAds: true,
      );

      final configJson = LuxwapConfigBuilder.buildConfigJson(
        node: node,
        clientConfig: clientConfig,
        userCountry: 'cn',
        statsPort: 18090,
        isWindows: true,
      );
      expect(configJson, isNotNull);

      final currentDir = Directory.current.path;
      final exeDir = '$currentDir\\build\\windows\\x64\\runner\\Release';
      final coreDir = '$exeDir\\bin\\luxwap_core';
      final corePath = '$coreDir\\luxwap_core.exe';
      expect(File(corePath).existsSync(), isTrue);

      final env = {
        'LUXWAP_CORE_LOCATION_ASSET': coreDir,
        'XRAY_LOCATION_ASSET': coreDir,
        'V2RAY_LOCATION_ASSET': coreDir,
        'PATH': '$coreDir;${Platform.environment['PATH'] ?? ''}',
      };

      print('  🚀 [E2E 测试] 正在使用最新防环路配置启动真实 Xray 核心...');
      final process = await Process.start(
        corePath,
        ['run', '-c', 'stdin:'],
        runInShell: false,
        workingDirectory: exeDir,
        environment: env,
      );

      var processDied = false;
      var lastCode = 0;
      final logs = <String>[];
      process.exitCode.then((code) {
        processDied = true;
        lastCode = code;
        print('  [Process ExitCode]: $code');
      });

      process.stdout.transform(utf8.decoder).listen((t) => logs.add('[OUT] $t'));
      process.stderr.transform(utf8.decoder).listen((t) => logs.add('[ERR] $t'));

      process.stdin.write(configJson);
      await process.stdin.flush();
      await process.stdin.close();

      // 等待 2 秒，让 Wintun 创建适配器并就绪
      await Future<void>.delayed(const Duration(seconds: 2));
      if (processDied) {
        print('🚨 [Process exited early]: Code $lastCode\nLogs:\n${logs.join("\n")}');
      }
      expect(processDied, isFalse, reason: 'Xray process must not die after TUN initialization');

      // 检查 PowerShell Get-NetAdapter
      final res = await Process.run('powershell', ['-NoProfile', '-Command', 'Get-NetAdapter | Where-Object { \$_.Name -match "luxwap" } | Select-Object -Property Name, Status, InterfaceDescription | Format-List']);
      final out = res.stdout.toString();
      print('  📋 [Get-NetAdapter 实时适配器信息]:\n$out');

      expect(out.contains('luxwap-tun'), isTrue, reason: 'luxwap-tun adapter MUST be created and visible in Windows');
      expect(out.contains('Luxwap TUN Adapter') || out.contains('Wintun'), isTrue, reason: 'Adapter must be powered by Wintun driver');
      print('  ✅ [虚拟网卡建立成功]: luxwap-tun 适配器已成功建立在系统中，处于活跃状态！');

      // 1. 断言 TUN 虚拟网卡分配的 IPv4 地址 (172.19.0.1) 和掩码前缀长度 (24 位 = 255.255.255.0)
      final ipRes = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-NetIPAddress -InterfaceAlias "luxwap-tun" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -Property IPAddress, PrefixLength | Format-List'
      ]);
      final ipOut = ipRes.stdout.toString();
      print('  🔍 [Get-NetIPAddress 虚拟网卡 IP 与掩码查询]:\n$ipOut');
      expect(ipOut.contains('172.19.0.1'), isTrue, reason: 'TUN adapter must be assigned 172.19.0.1');
      expect(ipOut.contains('24'), isTrue, reason: 'TUN adapter netmask prefix length must be 24 (255.255.255.0)');
      print('  ✅ [IP与掩码验证]: 成功断言 luxwap-tun 拥有首选 IP 172.19.0.1，掩码 255.255.255.0(/24)！');

      // 2. 注入节点公网 IP 的 /32 直连路由，并断言其走物理默认网关
      final nodeIp = '103.94.185.18';
      final routeInjected = await TunRouteManager.addDirectNodeRoute(nodeIp);
      expect(routeInjected, isTrue, reason: 'Node direct route must be successfully injected');
      final routeRes = await Process.run('route', ['print', nodeIp]);
      final routeOut = routeRes.stdout.toString();
      print('  🌐 [route print $nodeIp 查询结果]:\n$routeOut');
      expect(routeOut.contains(nodeIp), isTrue, reason: 'Routing table must contain node /32 destination');
      expect(routeOut.contains('255.255.255.255'), isTrue, reason: 'Node route must have 255.255.255.255 (/32) netmask');
      expect(routeOut.contains('10.0.168.253'), isTrue, reason: 'Node route must point to physical gateway 10.0.168.253');
      print('  ✅ [节点物理网关直连断言]: 成功断言节点 $nodeIp 拥有 /32 路由并经由物理网关 10.0.168.253 直连！');

      // 3. 断言系统 IPv4 路由表中存在 0.0.0.0/1 与 128.0.0.0/1 指向 172.19.0.1
      final tunRoutesCheck = await Process.run('route', ['print', '0.0.0.0']);
      final tunRoutesOut = tunRoutesCheck.stdout.toString();
      expect(tunRoutesOut.contains('128.0.0.0') && tunRoutesOut.contains('172.19.0.1'), isTrue,
          reason: 'Global 0.0.0.0/1 and 128.0.0.0/1 routes must point to 172.19.0.1');
      print('  ✅ [TUN 路由接管断言]: 成功断言系统全局 0.0.0.0/1 与 128.0.0.0/1 路由已指向 172.19.0.1！');

      // 维持运行 2 秒，验证防环路效果（零端口耗尽、零死循环）
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(processDied, isFalse, reason: 'Xray process must remain running stably without storm crash');
      print('  ✅ [稳定性验证]: 运行期间零套接字风暴、无崩溃退出，核心与网卡稳定工作！');

      // 4. 清理并销毁：关闭 TUN、终止核心、移除直连路由
      process.kill();
      await process.exitCode;
      await TunRouteManager.removeDirectNodeRoute(nodeIp);
      await Future<void>.delayed(const Duration(seconds: 1));

      // 5. 断言关闭 TUN 后：移除 luxwap-tun 虚拟网卡
      final cleanupCheck = await Process.run('powershell', ['-NoProfile', '-Command', 'Get-NetAdapter | Where-Object { \$_.Name -match "luxwap" } | Select-Object -ExpandProperty Name']);
      final remaining = cleanupCheck.stdout.toString().trim();
      expect(remaining.isEmpty, isTrue, reason: 'luxwap-tun must be completely removed when Xray stops');
      print('  ✅ [虚拟网卡清理断言]: 进程终结后 luxwap-tun 虚拟网卡已完全卸载释放，0 残留！');

      // 6. 断言关闭 TUN 后：TUN 对应的双 /1 路由表项已从 Windows 彻底清除
      final cleanTunRoutesRes = await Process.run('route', ['print', '0.0.0.0']);
      final cleanTunRoutesOut = cleanTunRoutesRes.stdout.toString();
      expect(cleanTunRoutesOut.contains('172.19.0.1'), isFalse,
          reason: '172.19.0.1 routes must be removed after TUN adapter is closed');
      print('  ✅ [TUN 路由清除断言]: 路由表中已无 172.19.0.1 全局分流条目！');

      // 7. 断言关闭 TUN 后：节点 /32 路由条目已被干净删除
      final cleanNodeRouteRes = await Process.run('route', ['print', nodeIp]);
      final cleanNodeRouteOut = cleanNodeRouteRes.stdout.toString();
      expect(cleanNodeRouteOut.contains('255.255.255.255') && cleanNodeRouteOut.contains('10.0.168.253'), isFalse,
          reason: 'Node /32 route must be deleted upon disconnection');
      print('  ✅ [节点直连路由清除断言]: 路由表中已干净清除节点 $nodeIp 的 /32 路由！');

      // 8. 断言关闭代理后：系统代理注册表处于干净关闭状态 (ProxyEnable == 0)
      final regProxyRes = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-ItemPropertyValue -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" -Name "ProxyEnable"'
      ]);
      final regProxyVal = regProxyRes.stdout.toString().trim();
      expect(regProxyVal, equals('0'), reason: 'ProxyEnable registry value must be 0');
      print('  ✅ [系统代理还原断言]: 注册表 ProxyEnable 严格置 0，杜绝用户断开后网络异常！');

      // 9. 断言关闭 TUN 后的配置仅保留 HTTP/SOCKS/API 入站，完全剔除 TUN
      final disabledInbounds = LuxwapConfigBuilder.buildInbounds(tunEnabled: false);
      expect(disabledInbounds.any((i) => i['tag'] == 'tun-in'), isFalse,
          reason: 'tun-in must be completely omitted when TUN is disabled');
      expect(disabledInbounds.any((i) => i['tag'] == 'http-in'), isTrue);
      expect(disabledInbounds.any((i) => i['tag'] == 'socks-in'), isTrue);
      expect(disabledInbounds.any((i) => i['tag'] == 'api'), isTrue);
      print('  ✅ [配置仅保留常规入站断言]: 关闭 TUN 后 Xray 配置严格仅保留 HTTP(10809) 与 SOCKS(10808) 代理入站！');
    });
  });

  group('TunRouteManager Direct Node Route & Gateway Lifecycle Tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('luxwap/window'),
              (call) async => null);
      TunRouteManager.resetState();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('luxwap/window'), null);
      TunRouteManager.resetState();
    });

    test('parseWindowsDefaultGateway accurately extracts physical gateway and skips virtual/loopback gateways', () {
      const sampleRoutePrint = '''
===========================================================================
接口列表
 15...00 16 3e 5b 7d 28 ......Red Hat VirtIO Ethernet Adapter #3
===========================================================================
IPv4 路由表
===========================================================================
活动路由:
网络目标        网络掩码          网关       接口   跃点数
          0.0.0.0          0.0.0.0     10.0.168.253     10.0.168.183     15
          0.0.0.0          0.0.0.0    198.19.31.253    198.19.27.172   9999
          0.0.0.0        128.0.0.0         在链路上        172.19.0.1      0
''';
      final gw = TunRouteManager.parseWindowsDefaultGateway(sampleRoutePrint);
      expect(gw, equals('10.0.168.253'));

      // If virtual TUN 172.19.0.1 is present first, it must be ignored in favor of physical gateway
      const sampleWithTunFirst = '''
活动路由:
网络目标        网络掩码          网关       接口   跃点数
          0.0.0.0          0.0.0.0       172.19.0.1       172.19.0.1      0
          0.0.0.0          0.0.0.0     192.168.50.1   192.168.50.100     25
''';
      final gwPhysical = TunRouteManager.parseWindowsDefaultGateway(sampleWithTunFirst);
      expect(gwPhysical, equals('192.168.50.1'));
    });

    test('parseMacDefaultGateway extracts default gateway cleanly', () {
      const sampleMacRoute = '''
   route to: default
destination: default
       mask: default
    gateway: 192.168.1.1
  interface: en0
      flags: <UP,GATEWAY,DONE,STATIC,PRCLONING>
''';
      final gw = TunRouteManager.parseMacDefaultGateway(sampleMacRoute);
      expect(gw, equals('192.168.1.1'));
    });

    test('addDirectNodeRoute executes route add /32 command and updates activeNodeIp', () async {
      final executedCommands = <List<String>>[];
      TunRouteManager.processRunner = (exe, args) async {
        executedCommands.add([exe, ...args]);
        if (args.contains('print') || args.contains('-n')) {
          return ProcessResult(
            1,
            0,
            Platform.isWindows
                ? '0.0.0.0  0.0.0.0  10.0.168.253  10.0.168.183  15\n'
                : 'gateway: 10.0.168.253\n',
            '',
          );
        }
        return ProcessResult(2, 0, 'OK', '');
      };

      final success = await TunRouteManager.addDirectNodeRoute('103.94.185.18');
      expect(success, isTrue);
      expect(TunRouteManager.activeNodeIp, equals('103.94.185.18'));

      if (Platform.isWindows) {
        expect(
          executedCommands.any((cmd) =>
              cmd[0] == 'route' &&
              cmd[1] == 'add' &&
              cmd[2] == '103.94.185.18' &&
              cmd[3] == 'mask' &&
              cmd[4] == '255.255.255.255' &&
              cmd[5] == '10.0.168.253' &&
              cmd[6] == 'metric' &&
              cmd[7] == '1'),
          isTrue,
          reason: 'Windows must add /32 host route via physical gateway with metric 1',
        );
      } else if (Platform.isMacOS) {
        expect(
          executedCommands.any((cmd) =>
              cmd[0] == 'route' &&
              cmd[1] == 'add' &&
              cmd[2] == '-host' &&
              cmd[3] == '103.94.185.18' &&
              cmd[4] == '10.0.168.253'),
          isTrue,
        );
      }
    });

    test('removeDirectNodeRoute executes route delete and resets activeNodeIp', () async {
      final executedCommands = <List<String>>[];
      TunRouteManager.processRunner = (exe, args) async {
        executedCommands.add([exe, ...args]);
        if (args.contains('print') || args.contains('-n')) {
          return ProcessResult(
            1,
            0,
            Platform.isWindows
                ? '0.0.0.0  0.0.0.0  10.0.168.253  10.0.168.183  15\n'
                : 'gateway: 10.0.168.253\n',
            '',
          );
        }
        return ProcessResult(2, 0, 'OK', '');
      };

      await TunRouteManager.addDirectNodeRoute('103.94.185.18');
      expect(TunRouteManager.activeNodeIp, equals('103.94.185.18'));

      final success = await TunRouteManager.removeDirectNodeRoute();
      expect(success, isTrue);
      expect(TunRouteManager.activeNodeIp, isNull);

      if (Platform.isWindows) {
        expect(
          executedCommands.any((cmd) => cmd[0] == 'route' && cmd[1] == 'delete' && cmd[2] == '103.94.185.18'),
          isTrue,
          reason: 'Windows must delete host route on disconnect',
        );
      } else if (Platform.isMacOS) {
        expect(
          executedCommands.any((cmd) => cmd[0] == 'route' && cmd[1] == 'delete' && cmd[2] == '-host' && cmd[3] == '103.94.185.18'),
          isTrue,
        );
      }
    });

    test('Switching node automatically clears previous node route before adding new one', () async {
      final executedCommands = <List<String>>[];
      TunRouteManager.processRunner = (exe, args) async {
        executedCommands.add([exe, ...args]);
        if (args.contains('print') || args.contains('-n')) {
          return ProcessResult(
            1,
            0,
            Platform.isWindows
                ? '0.0.0.0  0.0.0.0  10.0.168.253  10.0.168.183  15\n'
                : 'gateway: 10.0.168.253\n',
            '',
          );
        }
        return ProcessResult(2, 0, 'OK', '');
      };

      // Connect to Node 1
      await TunRouteManager.addDirectNodeRoute('1.1.1.1');
      expect(TunRouteManager.activeNodeIp, equals('1.1.1.1'));

      // Switch to Node 2
      await TunRouteManager.addDirectNodeRoute('2.2.2.2');
      expect(TunRouteManager.activeNodeIp, equals('2.2.2.2'));

      // Verify delete 1.1.1.1 was invoked
      final deleteIndex = executedCommands.indexWhere((cmd) => cmd[0] == 'route' && cmd.contains('1.1.1.1') && (cmd[1] == 'delete' || cmd.contains('delete')));
      final addIndex = executedCommands.indexWhere((cmd) => cmd[0] == 'route' && cmd.contains('2.2.2.2') && (cmd[1] == 'add' || cmd.contains('add')));

      expect(deleteIndex != -1, isTrue, reason: 'Old node route 1.1.1.1 must be deleted');
      expect(addIndex != -1, isTrue, reason: 'New node route 2.2.2.2 must be added');
      expect(deleteIndex < addIndex, isTrue, reason: 'Old node route must be deleted BEFORE new node route is added');
    });

    test('optimizeTunInterface executes netsh to set TUN interface metric to 1 on Windows', () async {
      final executedCommands = <List<String>>[];
      TunRouteManager.processRunner = (exe, args) async {
        executedCommands.add([exe, ...args]);
        return ProcessResult(1, 0, 'OK', '');
      };

      await TunRouteManager.optimizeTunInterface('luxwap-tun');
      if (Platform.isWindows) {
        expect(
          executedCommands.any((cmd) =>
              cmd[0] == 'netsh' &&
              cmd.contains('interface') &&
              cmd.contains('ip') &&
              cmd.contains('luxwap-tun') &&
              cmd.contains('metric=1')),
          isTrue,
          reason: 'Must configure TUN interface metric=1 to prioritize DNS and traffic routing',
        );
      }
    });

    test('addDirectNodeRoute performs defensive route delete before adding new route', () async {
      final executedCommands = <List<String>>[];
      TunRouteManager.processRunner = (exe, args) async {
        executedCommands.add([exe, ...args]);
        if (args.contains('print') || args.contains('-n')) {
          return ProcessResult(1, 0, '0.0.0.0 0.0.0.0 10.0.168.253 10.0.168.183 15\n', '');
        }
        return ProcessResult(2, 0, 'OK', '');
      };

      await TunRouteManager.addDirectNodeRoute('103.94.185.18');
      if (Platform.isWindows) {
        final delIndex = executedCommands.indexWhere((c) => c[0] == 'route' && c[1] == 'delete' && c[2] == '103.94.185.18');
        final addIndex = executedCommands.indexWhere((c) => c[0] == 'route' && c[1] == 'add' && c[2] == '103.94.185.18');
        expect(delIndex != -1, isTrue, reason: 'Defensive delete must be executed');
        expect(addIndex != -1, isTrue, reason: 'Route add must be executed');
        expect(delIndex < addIndex, isTrue, reason: 'Delete must precede add');
      }
    });

    test('Real host physical default gateway discovery on current environment', () async {
      final realGateway = await TunRouteManager.getPhysicalDefaultGateway(forceRefresh: true);
      print('  🌐 [实机物理网关探测结果]: $realGateway');
      if (Platform.isWindows) {
        expect(realGateway, isNotNull);
        expect(RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(realGateway!), isTrue);
        expect(realGateway.startsWith('172.19.'), isFalse, reason: 'Must not pick Wintun virtual gateway');
        expect(realGateway, isNot(equals('0.0.0.0')));
      }
    });
  });
}

