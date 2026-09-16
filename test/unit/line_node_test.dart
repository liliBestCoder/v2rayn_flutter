import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/line_node.dart';

void main() {
  group('LineNode Congestion and Load Tests', () {
    test('Effective load parsed from explicit load field', () {
      const node = LineNode(
        id: '1',
        name: 'Node 1',
        region: 'HK',
        load: 45,
      );
      expect(node.effectiveLoad, equals(45));
    });

    test('Effective load extracted from remark regex', () {
      const node1 = LineNode(
        id: '1',
        name: 'Node 1',
        region: 'HK',
        remark: '香港01 [负载: 75%]',
      );
      expect(node1.effectiveLoad, equals(75));

      const node2 = LineNode(
        id: '2',
        name: 'Node 2',
        region: 'US',
        remark: 'US-Fast-load 90',
      );
      expect(node2.effectiveLoad, equals(90));
    });

    test('Effective load defaults to 30 when unspecified', () {
      const node = LineNode(
        id: '1',
        name: 'Node 1',
        region: 'JP',
      );
      expect(node.effectiveLoad, equals(30));
    });

    test('Boundary conditions for congestion color rules', () {
      // Rule 1: Green < 60
      const node0 = LineNode(id: '0', name: 'N', region: 'R', load: 0);
      expect(node0.crowdColor, equals(const Color(0xff18ad3e)),
          reason: '0 load must be green');

      const node59 = LineNode(id: '59', name: 'N', region: 'R', load: 59);
      expect(node59.crowdColor, equals(const Color(0xff18ad3e)),
          reason: '59 load must be green');

      // Rule 2: Yellow 60 <= yellow <= 85
      const node60 = LineNode(id: '60', name: 'N', region: 'R', load: 60);
      expect(node60.crowdColor, equals(const Color(0xffff9822)),
          reason: '60 load must be yellow');

      const node72 = LineNode(id: '72', name: 'N', region: 'R', load: 72);
      expect(node72.crowdColor, equals(const Color(0xffff9822)),
          reason: '72 load must be yellow');

      const node85 = LineNode(id: '85', name: 'N', region: 'R', load: 85);
      expect(node85.crowdColor, equals(const Color(0xffff9822)),
          reason: '85 load must be yellow');

      // Rule 3: Red > 85
      const node86 = LineNode(id: '86', name: 'N', region: 'R', load: 86);
      expect(node86.crowdColor, equals(const Color(0xffff2d2d)),
          reason: '86 load must be red');

      const node100 = LineNode(id: '100', name: 'N', region: 'R', load: 100);
      expect(node100.crowdColor, equals(const Color(0xffff2d2d)),
          reason: '100 load must be red');
    });

    test('Host and port getters parse raw vless URI correctly', () {
      const node = LineNode(
        id: '1',
        name: 'HK Vless',
        region: 'HK',
        raw:
            'vless://uuid-1234@hk01.example.com:443?encryption=none&security=tls#HK-01',
      );

      expect(node.host, equals('hk01.example.com'));
      expect(node.port, equals(443));
    });

    test('Host and port fallback gracefully for invalid or empty raw URI', () {
      const node = LineNode(
          id: '1', name: 'Invalid', region: 'HK', raw: 'not-a-valid-uri');
      expect(node.host, equals(''));
      expect(node.port, equals(0));
    });

    test('Subscription metadata parses keyword separately from region', () {
      const raw =
          'vless://uuid@example.com:443#%E6%B4%9B%E6%9D%89%E7%9F%B6BGP01@split@us-la@split@north_america';
      final node = LineNode.fromSubscriptionLine(raw);

      expect(node.name, equals('洛杉矶BGP01'));
      expect(node.keyword, equals('us-la'));
      expect(node.region, equals('北美洲'));
    });
  });
}
