class UserInfo {
  const UserInfo({
    required this.uuid,
    required this.username,
    required this.email,
    required this.nick,
    required this.country,
    required this.expiration,
    required this.usedTraffic,
    required this.cumulativeMonths,
    this.totalTraffic = kDefaultTotalTrafficGb,
  });

  /// Fallback plan size in GB.
  ///
  /// `/api/client/user-info` currently returns `usedTraffic` but no quota, so
  /// there is nothing to read yet. [fromJson] already accepts the field under
  /// the names a backend would plausibly use — once one of them is returned,
  /// the whole app picks it up and this constant stops being consulted.
  static const double kDefaultTotalTrafficGb = 80.0;

  final String uuid;
  final String username;
  final String email;
  final String nick;
  final String country;
  final String expiration;
  final String usedTraffic;
  final int cumulativeMonths;

  /// Plan quota in GB.
  final double totalTraffic;

  /// [usedTraffic] parsed as GB, 0 when the field is missing or unparseable.
  double get usedTrafficGb {
    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(usedTraffic);
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  /// True once the plan quota is spent.
  bool get isTrafficExhausted =>
      totalTraffic > 0 && usedTrafficGb >= totalTraffic;

  /// Share of the quota consumed, clamped to 0..1.
  double get trafficFactor => totalTraffic <= 0
      ? 0
      : (usedTrafficGb / totalTraffic).clamp(0.0, 1.0);

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      uuid: json['uuid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      nick: json['nick']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      expiration: json['expiration']?.toString() ?? '',
      usedTraffic: json['usedTraffic']?.toString() ?? '',
      cumulativeMonths:
          int.tryParse(json['cumulativeMonths']?.toString() ?? '') ?? 0,
      totalTraffic: _parseTotalTraffic(json),
    );
  }

  static double _parseTotalTraffic(Map<String, dynamic> json) {
    for (final key in const [
      'totalTraffic',
      'trafficLimit',
      'totalFlow',
      'quota',
    ]) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) continue;
      final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(raw);
      final value = double.tryParse(match?.group(0) ?? '');
      if (value != null && value > 0) return value;
    }
    return kDefaultTotalTrafficGb;
  }
}
