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
  });

  final String uuid;
  final String username;
  final String email;
  final String nick;
  final String country;
  final String expiration;
  final String usedTraffic;
  final int cumulativeMonths;

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
    );
  }
}
