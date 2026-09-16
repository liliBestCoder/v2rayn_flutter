class ClientConfig {
  const ClientConfig({
    this.selectedLineName,
    this.routeStrategy = 'AsIs',
    this.language = '简体中文',
    this.passByIp = true,
    this.passByDomain = true,
    this.passByLanIp = true,
    this.passByLanDomain = false,
    this.blockAds = false,
    bool? dnsSplit,
    bool? vpnRoute,
    this.tunEnabled = true,
    this.closeToTray = true,
    this.dotDns = '',
    this.outerDns = '8.8.8.8',
    this.innerDns = '223.5.5.5',
    this.globalDns = '8.8.8.8',
    this.chainEnabled = false,
    this.chainUri = '',
  }) : dnsSplit = dnsSplit ?? vpnRoute ?? true;

  final String? selectedLineName;
  final String routeStrategy;
  final String language;
  final bool passByIp;
  final bool passByDomain;
  final bool passByLanIp;
  final bool passByLanDomain;
  final bool blockAds;
  final bool dnsSplit;

  /// Legacy alias kept so existing config files and callers remain compatible.
  bool get vpnRoute => dnsSplit;
  final bool tunEnabled;
  final bool closeToTray;
  final String dotDns;
  final String outerDns;
  final String innerDns;
  final String globalDns;

  /// Route node traffic through a front proxy before it reaches the node.
  final bool chainEnabled;

  /// Front proxy URI, e.g. `socks5://user:pass@127.0.0.1:1080` or
  /// `http://10.0.0.8:3128`. Ignored while [chainEnabled] is false.
  final String chainUri;

  ClientConfig copyWith({
    String? selectedLineName,
    bool clearSelectedLineName = false,
    String? routeStrategy,
    String? language,
    bool? passByIp,
    bool? passByDomain,
    bool? passByLanIp,
    bool? passByLanDomain,
    bool? blockAds,
    bool? dnsSplit,
    bool? vpnRoute,
    bool? tunEnabled,
    bool? closeToTray,
    String? dotDns,
    String? outerDns,
    String? innerDns,
    String? globalDns,
    bool? chainEnabled,
    String? chainUri,
  }) {
    return ClientConfig(
      selectedLineName: clearSelectedLineName
          ? null
          : selectedLineName ?? this.selectedLineName,
      routeStrategy: routeStrategy ?? this.routeStrategy,
      language: language ?? this.language,
      passByIp: passByIp ?? this.passByIp,
      passByDomain: passByDomain ?? this.passByDomain,
      passByLanIp: passByLanIp ?? this.passByLanIp,
      passByLanDomain: passByLanDomain ?? this.passByLanDomain,
      blockAds: blockAds ?? this.blockAds,
      dnsSplit: dnsSplit ?? vpnRoute ?? this.dnsSplit,
      tunEnabled: tunEnabled ?? this.tunEnabled,
      closeToTray: closeToTray ?? this.closeToTray,
      dotDns: dotDns ?? this.dotDns,
      outerDns: outerDns ?? this.outerDns,
      innerDns: innerDns ?? this.innerDns,
      globalDns: globalDns ?? this.globalDns,
      chainEnabled: chainEnabled ?? this.chainEnabled,
      chainUri: chainUri ?? this.chainUri,
    );
  }

  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    return ClientConfig(
      selectedLineName: json['selectedLineName']?.toString(),
      routeStrategy: json['routeStrategy']?.toString() ?? 'AsIs',
      language: json['language']?.toString() ?? '简体中文',
      passByIp: json['passByIp'] as bool? ?? true,
      passByDomain: json['passByDomain'] as bool? ?? true,
      passByLanIp: json['passByLanIp'] as bool? ?? true,
      passByLanDomain: json['passByLanDomain'] as bool? ?? false,
      blockAds: json['blockAds'] as bool? ?? false,
      dnsSplit: json['dnsSplit'] as bool? ?? json['vpnRoute'] as bool? ?? true,
      tunEnabled: json['tunEnabled'] as bool? ?? true,
      closeToTray: json['closeToTray'] as bool? ?? true,
      dotDns: json['dotDns']?.toString() ?? '',
      outerDns: json['outerDns']?.toString() ?? '8.8.8.8',
      innerDns: json['innerDns']?.toString() ?? '223.5.5.5',
      globalDns: json['globalDns']?.toString() ?? '8.8.8.8',
      chainEnabled: json['chainEnabled'] as bool? ?? false,
      chainUri: json['chainUri']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedLineName': selectedLineName,
      'routeStrategy': routeStrategy,
      'language': language,
      'passByIp': passByIp,
      'passByDomain': passByDomain,
      'passByLanIp': passByLanIp,
      'passByLanDomain': passByLanDomain,
      'blockAds': blockAds,
      'dnsSplit': dnsSplit,
      'tunEnabled': tunEnabled,
      'closeToTray': closeToTray,
      'dotDns': dotDns,
      'outerDns': outerDns,
      'innerDns': innerDns,
      'globalDns': globalDns,
      'chainEnabled': chainEnabled,
      'chainUri': chainUri,
    };
  }
}
