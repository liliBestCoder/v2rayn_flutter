import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/client_config.dart';

void main() {
  group('ClientConfig Model Tests', () {
    test('Default values verification', () {
      const config = ClientConfig();
      expect(config.tunEnabled, isTrue, reason: 'tunEnabled should default to true');
      expect(config.closeToTray, isTrue, reason: 'closeToTray should default to true');
      expect(config.dotDns, equals(''), reason: 'dotDns should default to empty string');
      expect(config.passByIp, isTrue);
      expect(config.passByDomain, isTrue);
      expect(config.vpnRoute, isTrue);
    });

    test('copyWith updates tunEnabled, closeToTray, and dotDns properly', () {
      const initial = ClientConfig();
      final updated = initial.copyWith(
        tunEnabled: false,
        closeToTray: false,
        dotDns: 'tcp://1.1.1.1:853',
      );

      expect(updated.tunEnabled, isFalse);
      expect(updated.closeToTray, isFalse);
      expect(updated.dotDns, equals('tcp://1.1.1.1:853'));
      // Unmodified fields remain unchanged
      expect(updated.outerDns, equals(initial.outerDns));
      expect(updated.innerDns, equals(initial.innerDns));
    });

    test('Json serialization and deserialization roundtrip', () {
      const original = ClientConfig(
        tunEnabled: false,
        closeToTray: false,
        dotDns: 'tcp://8.8.8.8:853',
        routeStrategy: 'IPIfNonMatch',
        language: 'English',
        outerDns: '1.1.1.1',
        innerDns: '223.6.6.6',
        globalDns: '1.0.0.1',
        passByIp: false,
        passByDomain: false,
        passByLanIp: false,
        passByLanDomain: true,
        blockAds: true,
        vpnRoute: false,
      );

      final jsonMap = original.toJson();
      expect(jsonMap['tunEnabled'], isFalse);
      expect(jsonMap['closeToTray'], isFalse);
      expect(jsonMap['dotDns'], equals('tcp://8.8.8.8:853'));

      final reconstructed = ClientConfig.fromJson(jsonMap);
      expect(reconstructed.tunEnabled, equals(original.tunEnabled));
      expect(reconstructed.closeToTray, equals(original.closeToTray));
      expect(reconstructed.dotDns, equals(original.dotDns));
      expect(reconstructed.routeStrategy, equals(original.routeStrategy));
      expect(reconstructed.language, equals(original.language));
      expect(reconstructed.outerDns, equals(original.outerDns));
    });

    test('fromJson handles legacy JSON with missing fields gracefully', () {
      final legacyJson = <String, dynamic>{
        'outerDns': '8.8.8.8',
        'innerDns': '223.5.5.5',
      };

      final parsed = ClientConfig.fromJson(legacyJson);
      expect(parsed.tunEnabled, isTrue, reason: 'Missing tunEnabled should default to true');
      expect(parsed.closeToTray, isTrue, reason: 'Missing closeToTray should default to true');
      expect(parsed.dotDns, equals(''), reason: 'Missing dotDns should default to empty string');
    });

    test('selectedLineName serializes cleanly and selectedLineRaw is strictly omitted', () {
      const config = ClientConfig(
        selectedLineName: '香港 01 优质专线',
      );

      final json = config.toJson();
      expect(json['selectedLineName'], equals('香港 01 优质专线'));
      expect(json.containsKey('selectedLineRaw'), isFalse,
          reason: 'Raw vless link must never be serialized to disk config.json');

      final reconstructed = ClientConfig.fromJson(json);
      expect(reconstructed.selectedLineName, equals('香港 01 优质专线'));
    });
  });
}
