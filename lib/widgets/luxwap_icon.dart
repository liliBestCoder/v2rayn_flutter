import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class LuxwapIcons {
  static const String logoBlue = 'icon-logo-blue';
  static const String logoWhite = 'icon-logo-white';
  static const String lines = 'icon-lines';
  static const String user = 'icon-user';
  static const String settings = 'icon-settings';
  static const String help = 'icon-help';
  static const String about = 'icon-about';
  static const String rocket = 'icon-rocket';
  static const String refresh = 'icon-refresh';
  static const String update = 'icon-update';
  static const String global = 'icon-global';
  static const String down = 'icon-down';
  static const String check = 'icon-check';
  static const String arrowRight = 'icon-arrow-right';
  static const String close = 'icon-close';
  static const String lock = 'icon-lock';
  static const String email = 'icon-email';
  static const String userOutline = 'icon-user-outline';
  static const String language = 'icon-globe';
  static const String info = 'icon-info';
  static const String location = 'icon-location';
  static const String play = 'icon-start';
  static const String stop = 'icon-stop';
  static const String cloudDownload = 'icon-cloud';
  static const String dropdown = 'icon-down';
  static const String copy = 'icon-clipboard';
  static const String book = 'icon-book';
  static const String privacy = 'icon-privacy';
  static const String search = 'icon-search';
  static const String verified = 'icon-verified';
  static const String searchOff = 'icon-search-off';
  static const String route = 'icon-route';
  static const String stream = 'icon-stream';
  static const String security = 'icon-security';
  static const String window = 'icon-window';
  static const String question = 'icon-question';
  static const String aspect = 'icon-aspect';
  static const String support = 'icon-support';
}

class LuxwapIcon extends StatelessWidget {
  const LuxwapIcon(
    this.name, {
    super.key,
    this.size = 20.0,
    this.width,
    this.height,
    this.color,
  });

  final String name;
  final double size;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final assetPath =
        name.startsWith('assets/') ? name : 'assets/icons/$name.svg';

    return SvgPicture.asset(
      assetPath,
      width: width ?? size,
      height: height ?? size,
      colorFilter:
          color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
