import 'dart:convert';
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
}
