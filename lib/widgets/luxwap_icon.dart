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
  static const String global = 'icon-global';
  static const String down = 'icon-down';
  static const String check = 'icon-check';
  static const String arrowRight = 'icon-arrow-right';
  static const String close = 'icon-close';
  static const String lock = 'icon-lock';
  static const String email = 'icon-email';
}

class LuxwapIcon extends StatelessWidget {
  const LuxwapIcon(
    this.name, {
    super.key,
    this.size = 20.0,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final assetPath = name.startsWith('assets/')
        ? name
        : 'assets/icons/$name.svg';

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
