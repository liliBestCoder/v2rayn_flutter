class LineNode {
  const LineNode({
    required this.name,
    required this.keyword,
    required this.region,
    required this.raw,
    this.delayMs,
    this.testingDelay = false,
  });

  final String name;
  final String keyword;
  final String region;
  final String raw;
  final int? delayMs;
  final bool testingDelay;

  String get host {
    try {
      return Uri.parse(raw).host;
    } catch (_) {
      return '';
    }
  }

  int get port {
    try {
      final uri = Uri.parse(raw);
      if (uri.hasPort) {
        return uri.port;
      }
    } catch (_) {
      // Use the default below for malformed subscription lines.
    }
    return 443;
  }

  LineNode copyWith({
    String? name,
    String? keyword,
    String? region,
    String? raw,
    int? delayMs,
    bool? testingDelay,
  }) {
    return LineNode(
      name: name ?? this.name,
      keyword: keyword ?? this.keyword,
      region: region ?? this.region,
      raw: raw ?? this.raw,
      delayMs: delayMs ?? this.delayMs,
      testingDelay: testingDelay ?? this.testingDelay,
    );
  }

  factory LineNode.fromSubscriptionLine(String raw) {
    final remark = _remarkFromUri(raw);
    final parts = remark.split('@split@');
    return LineNode(
      name: parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : _hostFromUri(raw),
      keyword: parts.length > 1 ? parts[1] : '',
      region: _regionName(parts.length > 2 ? parts[2] : ''),
      raw: raw,
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
