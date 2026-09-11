import 'package:flutter/material.dart';
import '../theme/luxwap_theme.dart';

class LineNode {
  const LineNode({
    this.id = '',
    required this.name,
    this.keyword = '',
    required this.region,
    this.raw = '',
    this.remark,
    this.delayMs,
    this.testingDelay = false,
    this.load,
  });

  final String id;
  final String name;
  final String keyword;
  final String region;
  final String raw;
  final String? remark;
  final int? delayMs;
  final bool testingDelay;
  final int? load;

  int get effectiveLoad {
    if (load != null) return load!;
    if (remark != null) {
      final match = RegExp(r'(?:负载|load)[:\s]*(\d+)', caseSensitive: false).firstMatch(remark!);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null) return parsed;
      }
    }
    if (delayMs != null && !testingDelay) {
      if (delayMs! < 0) return 95;
      if (delayMs! <= 120) return 45;
      if (delayMs! <= 250) return 75;
      return 90;
    }
    return 30;
  }

  Color get crowdColor {
    final l = effectiveLoad;
    if (l < 60) {
      return const Color(0xff18ad3e);
    } else if (l <= 85) {
      return const Color(0xffff9822);
    } else {
      return const Color(0xffff2d2d);
    }
  }

  String get host {
    try {
      final uri = Uri.parse(raw);
      if (uri.hasAuthority && uri.host.isNotEmpty) {
        return uri.host;
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  int get port {
    try {
      final uri = Uri.parse(raw);
      if (uri.hasPort) {
        return uri.port;
      }
    } catch (_) {
      return 0;
    }
    return 0;
  }

  LineNode copyWith({
    String? id,
    String? name,
    String? keyword,
    String? region,
    String? raw,
    String? remark,
    int? delayMs,
    bool? testingDelay,
    int? load,
  }) {
    return LineNode(
      id: id ?? this.id,
      name: name ?? this.name,
      keyword: keyword ?? this.keyword,
      region: region ?? this.region,
      raw: raw ?? this.raw,
      remark: remark ?? this.remark,
      delayMs: delayMs ?? this.delayMs,
      testingDelay: testingDelay ?? this.testingDelay,
      load: load ?? this.load,
    );
  }

  factory LineNode.fromSubscriptionLine(String raw) {
    final remark = _remarkFromUri(raw);
    final parts = remark.split('@split@');
    int? parsedLoad;
    if (parts.length > 3) {
      parsedLoad = int.tryParse(parts[3].trim());
    }
    return LineNode(
      name: parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : _hostFromUri(raw),
      keyword: parts.length > 1 ? parts[1] : '',
      region: _regionName(parts.length > 2 ? parts[2] : ''),
      raw: raw,
      load: parsedLoad,
    );
  }

  static String _remarkFromUri(String raw) {
    final hashIndex = raw.indexOf('#');
    if (hashIndex < 0 || hashIndex == raw.length - 1) {
      return raw;
    }
    return Uri.decodeComponent(raw.substring(hashIndex + 1).trim());
  }

  static String _hostFromUri(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.host.isNotEmpty) {
        return uri.host;
      }
    } catch (_) {
      // Keep the raw fallback below for malformed subscription lines.
    }
    return raw;
  }

  static String _regionName(String code) {
    switch (code) {
      case 'asia':
        return '亚洲';
      case 'europe':
        return '欧洲';
      case 'north_america':
        return '北美洲';
      case 'south_america':
        return '南美洲';
      case 'oceania':
        return '大洋洲';
      case 'africa':
        return '非洲';
      default:
        return '中国';
    }
  }
}
