import 'dart:io';
import 'package:flutter/services.dart';

/// 管理 TUN 模式下远端代理服务器（节点 IP）的物理网关直连主机路由 (/32)。
///
/// 官方原理 (见 Xray proxy/tun/README.md):
/// 当 TUN 接管 0.0.0.0/1 与 128.0.0.0/1 时，发往远端节点的底层报文会被重复捕获进 TUN，
/// 造成无限回环死锁 (infinite network loop)。
/// 必须通过 /32 主机路由显式指定节点公网 IP 走物理网关直连。
class TunRouteManager {
  static String? _activeNodeIp;
  static String? _cachedGateway;

  /// 当前激活直连路由的节点 IP
  static String? get activeNodeIp => _activeNodeIp;

  /// 允许在单元测试中注入自定义的进程执行器
  static Future<ProcessResult> Function(String exe, List<String> args)? processRunner;

  static Future<ProcessResult> _runProcess(String exe, List<String> args) async {
    if (processRunner != null) {
      return processRunner!(exe, args);
    }
    return Process.run(exe, args);
  }

  /// 提取/探测操作系统的活动物理默认网关 (如 10.0.168.253)
  static Future<String?> getPhysicalDefaultGateway({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedGateway != null && _cachedGateway!.isNotEmpty) {
      return _cachedGateway;
    }

    if (Platform.isWindows) {
      try {
        final result = await _runProcess('route', ['print', '0.0.0.0']);
        if (result.exitCode == 0) {
          final stdout = result.stdout.toString();
          final gw = parseWindowsDefaultGateway(stdout);
          if (gw != null) {
            _cachedGateway = gw;
            return gw;
          }
        }
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        final result = await _runProcess('route', ['-n', 'get', 'default']);
        if (result.exitCode == 0) {
          final stdout = result.stdout.toString();
          final gw = parseMacDefaultGateway(stdout);
          if (gw != null) {
            _cachedGateway = gw;
            return gw;
          }
        }
      } catch (_) {}
    }
    return _cachedGateway;
  }

  /// 从 Windows route print 0.0.0.0 输出中解析物理默认网关（选取跃点数最小的真实互联网物理网关）
  static String? parseWindowsDefaultGateway(String output) {
    final lines = output.split('\n');
    String? bestGw;
    int lowestMetric = 999999;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      // 匹配格式: 0.0.0.0          0.0.0.0     10.0.168.253     10.0.168.183     15
      final match = RegExp(
        r'0\.0\.0\.0\s+0\.0\.0\.0\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)',
      ).firstMatch(line);
      if (match != null) {
        final gw = match.group(1)!;
        final metric = int.tryParse(match.group(3)!) ?? 99999;
        // 过滤 0.0.0.0、回环网段以及 TUN 虚拟网卡自身网段 (172.19.x.x)
        if (gw != '0.0.0.0' && !gw.startsWith('127.') && !gw.startsWith('172.19.')) {
          if (metric < lowestMetric) {
            lowestMetric = metric;
            bestGw = gw;
          }
        }
      }
    }
    return bestGw;
  }

  /// 从 macOS route -n get default 输出中解析物理默认网关
  static String? parseMacDefaultGateway(String output) {
    final match = RegExp(r'gateway:\s*(\d+\.\d+\.\d+\.\d+)').firstMatch(output);
    if (match != null) {
      final gw = match.group(1)!;
      if (gw != '0.0.0.0' && !gw.startsWith('127.')) {
        return gw;
      }
    }
    return null;
  }

  /// 域名预解析支持：将域名或主机名解析为有效的 IPv4 地址
  static Future<String?> resolveHostToIp(String host) async {
    final trimmed = host.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(trimmed)) {
      return trimmed;
    }
    try {
      final records = await InternetAddress.lookup(trimmed);
      for (final r in records) {
        if (r.type == InternetAddressType.IPv4) {
          return r.address;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 优化 TUN 虚拟网卡的接口跃点数 (Metric)，优先使用 TUN 网卡进行 DNS 解析和流量分流
  static Future<void> optimizeTunInterface([String ifName = 'luxwap-tun']) async {
    if (Platform.isWindows) {
      try {
        await _runProcess('netsh', [
          'interface',
          'ip',
          'set',
          'interface',
          ifName,
          'metric=1',
        ]);
      } catch (_) {}
    }
  }

  /// 注入目标节点公网 IP 的 /32 物理网关直连路由
  static Future<bool> addDirectNodeRoute(String nodeIpOrHost) async {
    final resolvedIp = await resolveHostToIp(nodeIpOrHost);
    final trimmedIp = (resolvedIp ?? nodeIpOrHost).trim();
    if (trimmedIp.isEmpty || trimmedIp == '127.0.0.1' || trimmedIp == 'localhost') {
      return false;
    }

    // 如果之前已有记录且不是当前节点，先清理旧节点的路由
    if (_activeNodeIp != null && _activeNodeIp != trimmedIp) {
      await removeDirectNodeRoute(_activeNodeIp);
    }

    final gateway = await getPhysicalDefaultGateway();
    if (gateway == null || gateway.isEmpty) {
      return false;
    }

    bool success = false;
    if (Platform.isWindows) {
      try {
        // 先做一次防御性清理，避免上次非正常退出残留导致 "The object already exists"
        await _runProcess('route', ['delete', trimmedIp]);
        final res = await _runProcess('route', [
          'add',
          trimmedIp,
          'mask',
          '255.255.255.255',
          gateway,
          'metric',
          '1',
        ]);
        success = (res.exitCode == 0);
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        await _runProcess('route', ['delete', '-host', trimmedIp]);
        final res = await _runProcess('route', [
          'add',
          '-host',
          trimmedIp,
          gateway,
        ]);
        success = (res.exitCode == 0);
      } catch (_) {}
    }

    if (success) {
      _activeNodeIp = trimmedIp;
      // 同步给原生窗口层，以供窗口强制关闭或崩溃退出时兜底清理
      try {
        await const MethodChannel('luxwap/window').invokeMethod('setTunNodeRoute', {
          'nodeIp': trimmedIp,
        });
      } catch (_) {}
    }
    return success;
  }

  /// 清理已注入的直连路由
  static Future<bool> removeDirectNodeRoute([String? targetIp]) async {
    final ip = targetIp ?? _activeNodeIp;
    if (ip == null || ip.isEmpty) {
      return true;
    }

    bool success = false;
    if (Platform.isWindows) {
      try {
        final res = await _runProcess('route', ['delete', ip]);
        success = (res.exitCode == 0);
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        final res = await _runProcess('route', ['delete', '-host', ip]);
        success = (res.exitCode == 0);
      } catch (_) {}
    }

    if (targetIp == null || targetIp == _activeNodeIp) {
      _activeNodeIp = null;
    }

    // 通知原生层清除记录
    try {
      await const MethodChannel('luxwap/window').invokeMethod('cleanTunNodeRoute');
      await const MethodChannel('luxwap/window').invokeMethod('setTunNodeRoute', {
        'nodeIp': '',
      });
    } catch (_) {}

    return success;
  }

  /// 重置内部缓存（用于测试或完全退出）
  static void resetState() {
    _activeNodeIp = null;
    _cachedGateway = null;
    processRunner = null;
  }
}
