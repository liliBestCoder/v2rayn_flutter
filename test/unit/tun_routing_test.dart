import 'dart:convert';
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
}
