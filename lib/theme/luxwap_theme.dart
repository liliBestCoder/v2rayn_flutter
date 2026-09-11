import 'package:flutter/material.dart';

/// LuxwapUI Design System Tokens
/// Extracted from official design spec (luxwap.fig / css.json)
/// Primary language: zh (MiSans), secondary: en (Inter)
abstract final class LuxwapColors {
  // Brand Palette
  static const Color brand50 = Color(0xffe9f0ff);
  static const Color brand100 = Color(0xffd4e1ff);
  static const Color brand200 = Color(0xffa9c3ff);
  static const Color brand300 = Color(0xff7ea5ff);
  static const Color brand400 = Color(0xff71affc);
  static const Color brand500 = Color(0xff286afc); // Primary
  static const Color brand600 = Color(0xff1f55c9);
  static const Color brand700 = Color(0xff174097);
  static const Color brand800 = Color(0xff0f2b65);
  static const Color brand900 = Color(0xff081532);

  // Neutral Palette
  static const Color neutral0 = Color(0xffffffff);
  static const Color neutral50 = Color(0xfff7f7f8);
  static const Color neutral100 = Color(0xfff3f6fb);
  static const Color neutral200 = Color(0xffeaeaea);
  static const Color neutral300 = Color(0xffdfdfdf);
  static const Color neutral400 = Color(0xffb2b2b2);
  static const Color neutral500 = Color(0xff999bab);
  static const Color neutral600 = Color(0xff666666);
  static const Color neutral700 = Color(0xff3d3d3d);
  static const Color neutral800 = Color(0xff1b1b1b);
  static const Color neutral900 = Color(0xff000000);

  // State Palette
  static const Color stateSuccess = Color(0xff27a53c);
  static const Color stateSuccessSurface = Color(0xffe8f5eb);
  static const Color stateError = Color(0xffed462b);
  static const Color stateErrorSurface = Color(0xfffdece9);
  static const Color stateWarning = Color(0xffff8800);
  static const Color stateWarningSurface = Color(0xfffff3e0);

  // Accents
  static const Color accentRed = Color(0xffff383c);
  static const Color accentOrange = Color(0xffff8d28);
  static const Color green500 = Color(0xff14ae5c);

  // Semantic Aliases
  static const Color primary = brand500;
  static const Color primaryForeground = neutral0;
  static const Color background = neutral0;
  static const Color scaffoldBackground = neutral100;
  static const Color pageBackground = neutral100;
  static const Color foreground = neutral800;
  static const Color card = neutral0;
  static const Color cardSecondary = neutral100;
  static const Color border = neutral300;
  static const Color borderLight = neutral200;
  static const Color divider = neutral200;
  static const Color muted = neutral50;
  static const Color mutedForeground = neutral600;
  static const Color accent = brand50;
  static const Color accentForeground = brand500;
}

abstract final class LuxwapRadius {
  static const double sm = 5.0;   // inputs, form fields, tags
  static const double md = 15.0;  // cards, primary CTA buttons
  static const double lg = 30.0;  // chips, pill badges, avatars
  static const double full = 9999.0;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rFull = BorderRadius.all(Radius.circular(full));
}

abstract final class LuxwapTypography {
  static const String primaryFont = 'Microsoft YaHei';
  static const List<String> fontFallbacks = [
    'PingFang SC',
    'Segoe UI',
    'MiSans',
    'Inter',
    'Helvetica Neue',
    'sans-serif',
  ];

  static TextStyle get heading1 => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get heading2 => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get heading3 => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get heading4 => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get heading5 => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get heading6 => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get body => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: LuxwapColors.foreground,
        fontFamilyFallback: fontFallbacks,
      );

  static TextStyle get caption => const TextStyle(
        fontFamily: primaryFont,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: LuxwapColors.mutedForeground,
        fontFamilyFallback: fontFallbacks,
      );
}

abstract final class LuxwapShadows {
  static const List<BoxShadow> shadow2xs = [
    BoxShadow(
      color: Color(0x1a000000),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  static const List<BoxShadow> shadowXs = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x1f000000),
      offset: Offset(0, 3),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> card = shadowXs;
}

ThemeData buildLuxwapThemeData() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: LuxwapTypography.primaryFont,
    fontFamilyFallback: LuxwapTypography.fontFallbacks,
    scaffoldBackgroundColor: LuxwapColors.scaffoldBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LuxwapColors.brand500,
      primary: LuxwapColors.brand500,
      onPrimary: LuxwapColors.primaryForeground,
      surface: LuxwapColors.card,
      onSurface: LuxwapColors.foreground,
    ),
    textTheme: TextTheme(
      headlineLarge: LuxwapTypography.heading1,
      headlineMedium: LuxwapTypography.heading2,
      headlineSmall: LuxwapTypography.heading3,
      titleLarge: LuxwapTypography.heading4,
      titleMedium: LuxwapTypography.heading5,
      titleSmall: LuxwapTypography.heading6,
      bodyLarge: LuxwapTypography.bodyLarge,
      bodyMedium: LuxwapTypography.body,
      bodySmall: LuxwapTypography.caption,
    ),
    dividerTheme: const DividerThemeData(
      color: LuxwapColors.divider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LuxwapColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(
        color: LuxwapColors.neutral400,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: LuxwapRadius.rSm,
        borderSide: const BorderSide(color: LuxwapColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: LuxwapRadius.rSm,
        borderSide: const BorderSide(color: LuxwapColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: LuxwapRadius.rSm,
        borderSide: const BorderSide(color: LuxwapColors.brand500, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: LuxwapColors.brand500,
        foregroundColor: LuxwapColors.primaryForeground,
        shape: RoundedRectangleBorder(borderRadius: LuxwapRadius.rMd),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: LuxwapColors.brand500,
        foregroundColor: LuxwapColors.primaryForeground,
        shape: RoundedRectangleBorder(borderRadius: LuxwapRadius.rMd),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
