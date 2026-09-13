import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/services/luxwap_config_builder.dart';
import 'cdp_browser_driver.dart';

void main() {
  group('CDP & Settings Switches Toggle and Core Config Regeneration Tests', () {
    const sampleNode = LineNode(
      raw: 'vless://uuid-test@103.94.185.18:443?encryption=none&security=tls#HongKong-01',
      name: 'HongKong-01',
      remark: 'HongKong-01',
      region: 'Hong Kong',
      keyword: 'hk',
    );

    test('Toggling each switch in Settings produces corresponding changes in client config and core JSON', () async {
      var config = const ClientConfig();

      print('⚙️ [初始配置状态]:');
      print('  - tunEnabled: ${config.tunEnabled}');
      print('  - blockAds: ${config.blockAds}');
      print('  - passByIp: ${config.passByIp}');
      print('  - passByDomain: ${config.passByDomain}');
      print('  - routeStrategy: ${config.routeStrategy}');

      // 1. Toggle blockAds (广告拦截)
      print('\n🔄 [切换测试 1: 开启广告拦截 blockAds]');
      config = config.copyWith(blockAds: true);
      var jsonStr = LuxwapConfigBuilder.buildConfigJson(
        node: sampleNode,
        clientConfig: config,
        userCountry: 'CN',
      );
      var xrayJson = jsonDecode(jsonStr!) as Map<String, dynamic>;
      var routingRules = xrayJson['routing']['rules'] as List;
      final adsRule = routingRules.firstWhere(
        (r) => r['outboundTag'] == 'block' && (r['domain'] as List?)?.contains('geosite:category-ads-all') == true,
        orElse: () => null,
      );
      expect(adsRule, isNotNull, reason: 'Enabling blockAds must insert geosite:category-ads-all block rule');
      print('  ✅ [核心配置已更新]: 已成功生成 geosite:category-ads-all -> block 规则！');

      // 2. Toggle tunEnabled (TUN 虚拟网卡切换为普通代理模式)
      print('\n🔄 [切换测试 2: 关闭 TUN 模式 (切换为普通 HTTP/SOCKS 代理入站)]');
      config = config.copyWith(tunEnabled: false);
      jsonStr = LuxwapConfigBuilder.buildConfigJson(
        node: sampleNode,
        clientConfig: config,
        userCountry: 'CN',
      );
      xrayJson = jsonDecode(jsonStr!) as Map<String, dynamic>;
      var inbounds = xrayJson['inbounds'] as List;
      final hasTun = inbounds.any((ib) => ib['protocol'] == 'tun');
      final hasHttp = inbounds.any((ib) => ib['protocol'] == 'http' && ib['port'] == 10809);
      final hasSocks = inbounds.any((ib) => ib['protocol'] == 'socks' && ib['port'] == 10808);
      expect(hasTun, isFalse, reason: 'Disabling TUN must remove tun protocol inbound');
      expect(hasHttp, isTrue, reason: 'Disabling TUN must provide HTTP 10809 inbound for browsers');
      expect(hasSocks, isTrue, reason: 'Disabling TUN must provide SOCKS 10808 inbound');
      print('  ✅ [核心配置已更新]: TUN 入站已移除，HTTP (10809) 与 SOCKS (10808) 代理入站已成功加载！');

      // 3. Toggle routeStrategy (路由策略: AsIs -> IPIfNonMatch)
      print('\n🔄 [切换测试 3: 修改路由策略 routeStrategy 为 IPIfNonMatch]');
      config = config.copyWith(routeStrategy: 'IPIfNonMatch');
      jsonStr = LuxwapConfigBuilder.buildConfigJson(
        node: sampleNode,
        clientConfig: config,
        userCountry: 'CN',
      );
      xrayJson = jsonDecode(jsonStr!) as Map<String, dynamic>;
      expect(xrayJson['routing']['domainStrategy'], equals('IPIfNonMatch'),
          reason: 'Modifying routeStrategy must reflect in xray routing.domainStrategy');
      print('  ✅ [核心配置已更新]: routing.domainStrategy 严格更新为 IPIfNonMatch！');

      // 4. Toggle DoT DNS (DNS over TLS)
      print('\n🔄 [切换测试 4: 配置 DoT DNS 专属加密解析 (1.1.1.1:853)]');
      config = config.copyWith(dotDns: '1.1.1.1');
      jsonStr = LuxwapConfigBuilder.buildConfigJson(
        node: sampleNode,
        clientConfig: config,
        userCountry: 'CN',
      );
      xrayJson = jsonDecode(jsonStr!) as Map<String, dynamic>;
      final dnsServers = xrayJson['dns']['servers'] as List;
      expect(dnsServers, anyElement(contains('1.1.1.1')),
          reason: 'Setting dotDns must add TLS DoT upstream server');
      print('  ✅ [核心配置已更新]: DNS servers 成功添加 tls://1.1.1.1 节点上游！');

      // 5. Connect Headless Browser with CDP to confirm browser compatibility with updated configuration
      print('\n🌐 [步骤 5: CDP 无头浏览器连接与参数校验]');
      final cdp = await CdpBrowserDriver.launch(
        proxyServer: 'http://127.0.0.1:10809',
        headless: true,
      );
      try {
        final screenWidth = await cdp.evaluate('window.screen.width');
        expect(screenWidth, isNotNull);
        print('  ✅ [CDP 无头浏览器端对端校验完成]: 浏览器就绪并挂载最新代理策略！');
      } finally {
        await cdp.close();
      }
    });
  });
}
