import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/services/tun_route_manager.dart';

/// Reproduces the reported failure: with the TUN switch on, starting and
/// stopping the proxy a few times leaves the adapter unable to reach the
/// network.
///
/// The proxy lifecycle touches the routing table on both edges — `_startProxy`
/// injects a /32 host route for the node via the physical gateway, `_stopProxy`
/// removes it. Anything asymmetric across a cycle accumulates in the system
/// routing table, which is exactly what "works the first time, dead after a
/// few" looks like. These tests drive that cycle through the manager's own
/// `processRunner` seam and assert the table comes back clean every time.
void main() {
  /// Commands the manager issued, as `[exe, ...args]`.
  late List<List<String>> commands;

  /// Simulated system routing table: destinations with a live /32 route.
  late Set<String> routingTable;

  /// Gateway that `route print` reports. Mutable so a test can simulate the
  /// physical gateway changing between cycles.
  late String reportedGateway;

  /// When non-null, `route add` fails for this destination.
  String? failAddFor;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('luxwap/window'), (call) async => null);
    TunRouteManager.resetState();

    commands = [];
    routingTable = {};
    reportedGateway = '10.0.168.253';
    failAddFor = null;

    TunRouteManager.processRunner = (exe, args) async {
      commands.add([exe, ...args]);

      // `route print 0.0.0.0` / `route -n get default`
      if (args.contains('print') || args.contains('-n')) {
        return ProcessResult(
          1,
          0,
          Platform.isWindows
              ? '          0.0.0.0          0.0.0.0     $reportedGateway     10.0.168.183     15\n'
              : 'gateway: $reportedGateway\n',
          '',
        );
      }

      if (args.isNotEmpty && args.first == 'add') {
        final dest = args.firstWhere(_looksLikeIp, orElse: () => '');
        if (dest == failAddFor) {
          return ProcessResult(2, 1, '', 'The route addition failed.');
        }
        routingTable.add(dest);
        return ProcessResult(2, 0, 'OK!', '');
      }

      if (args.isNotEmpty && args.first == 'delete') {
        final dest = args.firstWhere(_looksLikeIp, orElse: () => '');
        final existed = routingTable.remove(dest);
        // Windows `route delete` returns a non-zero code when the route is not
        // in the table, which is what the defensive pre-delete relies on.
        return existed
            ? ProcessResult(2, 0, 'OK!', '')
            : ProcessResult(2, 1, '', 'The route deletion failed.');
      }

      return ProcessResult(2, 0, '', '');
    };
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('luxwap/window'), null);
    TunRouteManager.resetState();
  });

  /// One proxy session: start injects the node route, stop removes it.
  Future<void> cycle(String nodeIp) async {
    await TunRouteManager.addDirectNodeRoute(nodeIp);
    await TunRouteManager.removeDirectNodeRoute();
  }

  test('五次开关之后路由表不残留', () async {
    for (var i = 0; i < 5; i++) {
      await cycle('103.94.185.18');
    }

    expect(routingTable, isEmpty,
        reason: '每轮注入的 /32 主机路由都应在停止时清掉，残留会累积到系统路由表');
    expect(TunRouteManager.activeNodeIp, isNull);
  }, skip: !Platform.isWindows && !Platform.isMacOS);

  test('每轮切换不同节点也不残留', () async {
    const nodes = [
      '103.94.185.18',
      '45.76.100.7',
      '172.104.88.9',
      '103.94.185.18',
    ];
    for (final ip in nodes) {
      await cycle(ip);
    }

    expect(routingTable, isEmpty,
        reason: '切换节点时旧节点的路由必须先撤销，否则每换一个节点就多留一条');
    expect(TunRouteManager.activeNodeIp, isNull);
  }, skip: !Platform.isWindows && !Platform.isMacOS);

  test('route add 失败时不应把失败的目标记为已激活', () async {
    failAddFor = '103.94.185.18';
    final ok = await TunRouteManager.addDirectNodeRoute('103.94.185.18');

    expect(ok, isFalse);
    expect(TunRouteManager.activeNodeIp, isNull,
        reason: '注入失败却记成激活，下一轮 stop 会去删一条不存在的路由，'
            '而真正残留的那条没人管');
  }, skip: !Platform.isWindows && !Platform.isMacOS);

  test('物理网关变化后重新探测，而不是复用首轮缓存', () async {
    await cycle('103.94.185.18');

    // The machine moves to another network between sessions.
    reportedGateway = '192.168.50.1';
    commands.clear();
    await TunRouteManager.addDirectNodeRoute('103.94.185.18');

    final addCmd = commands.firstWhere(
      (c) => c.length > 1 && c[1] == 'add',
      orElse: () => const [],
    );
    expect(addCmd, isNotEmpty, reason: '应发出 route add');
    expect(addCmd, contains('192.168.50.1'),
        reason: '网关缓存永不失效，换网络后仍把路由指向旧网关，'
            '节点流量被送进不存在的下一跳，TUN 就断了');
  }, skip: !Platform.isWindows && !Platform.isMacOS);
}

bool _looksLikeIp(String value) =>
    RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(value);
