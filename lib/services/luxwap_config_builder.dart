import 'dart:convert';
import 'dart:io';

import '../models/client_config.dart';
import '../models/line_node.dart';

class LuxwapConfigBuilder {
  static String normalizeCountryCode(String? country) {
    final code = (country ?? '').trim().toLowerCase();
    if (RegExp(r'^[a-z]{2}$').hasMatch(code)) {
      return code;
    }
    return 'cn';
  }

  static Map<String, dynamic>? buildVlessOutbound(LineNode node, String tag) {
    final uri = Uri.tryParse(node.raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'vless' ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        uri.userInfo.isEmpty) {
      return null;
    }

    final query = uri.queryParameters;
    final user = <String, dynamic>{
      'id': uri.userInfo,
      'encryption': query['encryption'] ?? 'none',
    };
    if ((query['flow'] ?? '').isNotEmpty) {
      user['flow'] = query['flow'];
    }

    final streamSettings = <String, dynamic>{
      'network': query['type'] ?? 'tcp',
      'security': query['security'] ?? 'none',
    };
    if (streamSettings['security'] == 'reality') {
      streamSettings['realitySettings'] = {
        'serverName': query['sni'] ?? '',
        'fingerprint': query['fp'] ?? 'chrome',
        'publicKey': query['pbk'] ?? '',
        'shortId': query['sid'] ?? '',
        'spiderX': query['spx'] ?? '',
      };
    } else if (streamSettings['security'] == 'tls') {
      streamSettings['tlsSettings'] = {
        'serverName': query['sni'] ?? '',
        'allowInsecure': false,
      };
    }

    return {
      'tag': tag,
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': uri.host,
            'port': uri.port,
            'users': [user],
          }
        ],
      },
      'streamSettings': streamSettings,
    };
  }

  static Map<String, dynamic> buildDnsConfig(ClientConfig config, bool isChina) {
    final servers = <dynamic>[];
    if (config.dotDns.trim().isNotEmpty) {
      servers.add(config.dotDns.trim());
    }
    if (config.vpnRoute) {
      if (isChina) {
        servers.add({
          'address': config.innerDns,
          'domains': ['geosite:cn'],
          'expectIPs': ['geoip:cn'],
        });
        servers.add({
          'address': config.outerDns,
          'domains': ['geosite:geolocation-!cn'],
        });
      } else {
        servers.add(config.outerDns);
      }
    }
    servers.add(config.globalDns);
    return {'servers': servers};
  }

  static List<Map<String, dynamic>> buildInbounds({
    required bool tunEnabled,
    int? statsPort,
    bool? isWindows,
    ClientConfig? clientConfig,
  }) {
    final effectiveIsWindows = isWindows ?? Platform.isWindows;
    final effectiveStatsPort = statsPort ?? 10890;
    final inbounds = <Map<String, dynamic>>[
      {
        'tag': 'http-in',
        'listen': '127.0.0.1',
        'port': 10809,
        'protocol': 'http',
        'settings': {'timeout': 0},
      },
      {
        'tag': 'socks-in',
        'listen': '127.0.0.1',
        'port': 10808,
        'protocol': 'socks',
        'settings': {'auth': 'noauth', 'udp': true},
      },
      {
        'tag': 'api',
        'listen': '127.0.0.1',
        'port': effectiveStatsPort,
        'protocol': 'dokodemo-door',
        'settings': {'address': '127.0.0.1'},
      },
    ];

    if (tunEnabled) {
      final outerDns = (clientConfig?.outerDns.isNotEmpty == true)
          ? clientConfig!.outerDns
          : '8.8.8.8';
      final innerDns = (clientConfig?.innerDns.isNotEmpty == true)
          ? clientConfig!.innerDns
          : '223.5.5.5';
      final dnsList = {outerDns, innerDns, '1.1.1.1'}.toList();

      inbounds.add({
        'tag': 'tun-in',
        'port': 0,
        'protocol': 'tun',
        'settings': {
          'name': effectiveIsWindows ? 'luxwap-tun' : 'utun10',
          'desc': 'Luxwap TUN Adapter',
          'mtu': 1500,
          'gateway': ['172.19.0.1/24'],
          'autoSystemRoutingTable': ['0.0.0.0/1', '128.0.0.0/1'],
          'autoOutboundsInterface': '',
          'DNS': dnsList,
        },
      });
    }

    return inbounds;
  }

  static List<Map<String, dynamic>> buildRoutingRules(
    ClientConfig config,
    String countryCode,
    bool isChina,
  ) {
    final rules = <Map<String, dynamic>>[];
    // Prevent packet storm loop on TUN interface:
    // 1. Drop NetBIOS UDP broadcast traffic (ports 137, 138, 139) which Windows floods on all NICs
    rules.add({
      'type': 'field',
      'outboundTag': 'block',
      'port': '137,138,139',
      'network': 'udp',
    });
    // 2. Drop multicast, subnet broadcast, and TUN adapter's own IP subnet
    rules.add({
      'type': 'field',
      'outboundTag': 'block',
      'ip': [
        '224.0.0.0/4',
        '255.255.255.255/32',
        '172.19.0.0/24',
      ],
    });
    if (config.blockAds) {
      rules.add({
        'type': 'field',
        'domain': ['geosite:category-ads-all'],
        'outboundTag': 'block',
      });
    }
    if (config.passByDomain && isChina) {
      rules.add({
        'type': 'field',
        'domain': ['geosite:cn'],
        'outboundTag': 'direct',
      });
    }
    if (config.passByLanDomain) {
      rules.add({
        'type': 'field',
        'domain': ['domain:localhost'],
        'outboundTag': 'direct',
      });
    }
    if (config.passByIp) {
      rules.add({
        'type': 'field',
        'ip': ['geoip:$countryCode'],
        'outboundTag': 'direct',
      });
    }
    if (config.passByLanIp) {
      rules.add({
        'type': 'field',
        'ip': ['geoip:private'],
        'outboundTag': 'direct',
      });
    }
    return rules;
  }

  static Map<String, dynamic>? buildConfigMap({
    required LineNode node,
    required ClientConfig clientConfig,
    String? userCountry,
    int? statsPort,
    bool? isWindows,
  }) {
    final proxyOutbound = buildVlessOutbound(node, 'proxy');
    if (proxyOutbound == null) {
      return null;
    }
    final countryCode = normalizeCountryCode(userCountry);
    final isChina = countryCode == 'cn';

    final inbounds = buildInbounds(
      tunEnabled: clientConfig.tunEnabled,
      statsPort: statsPort,
      isWindows: isWindows,
      clientConfig: clientConfig,
    );

    return {
      'log': {'loglevel': 'warning'},
      'dns': buildDnsConfig(clientConfig, isChina),
      'stats': {},
      'metrics': {'tag': 'api'},
      'policy': {
        'system': {
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        }
      },
      'inbounds': inbounds,
      'outbounds': [
        proxyOutbound,
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
      'routing': {
        'domainStrategy': isChina ? 'AsIs' : 'IPIfNonMatch',
        'rules': [
          {
            'type': 'field',
            'inboundTag': ['api'],
            'outboundTag': 'api',
          },
          ...buildRoutingRules(clientConfig, countryCode, isChina),
        ],
      },
    };
  }

  static String? buildConfigJson({
    required LineNode node,
    required ClientConfig clientConfig,
    String? userCountry,
    int? statsPort,
    bool? isWindows,
  }) {
    final map = buildConfigMap(
      node: node,
      clientConfig: clientConfig,
      userCountry: userCountry,
      statsPort: statsPort,
      isWindows: isWindows,
    );
    if (map == null) return null;
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}
