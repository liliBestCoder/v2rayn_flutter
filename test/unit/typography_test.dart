import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/theme/luxwap_theme.dart';

/// Guards the type system against the design file.
///
/// LuxwapPC_v2 sets one flat line-height ratio (1.21) on every one of its 439
/// text nodes, and draws from a fixed size/weight scale. The pages mostly write
/// bare `TextStyle(fontSize: ...)` without a `height`, so the ratio has to
/// arrive through DefaultTextStyle — which is what the first group verifies
/// rather than assumes.
void main() {
  group('行高继承', () {
    testWidgets('未设 height 的 TextStyle 解析后为设计稿的 1.21', (tester) async {
      late TextStyle resolved;

      await tester.pumpWidget(MaterialApp(
        theme: buildLuxwapThemeData(),
        // Scaffold matters: DefaultTextStyle is installed by Material from
        // textTheme.bodyMedium, not by MaterialApp itself. Testing against a
        // bare home would read DefaultTextStyle.fallback() and prove nothing
        // about how the pages actually render.
        home: Scaffold(
          body: Builder(builder: (context) {
            // What a page actually writes: size and weight, no height.
            const written = TextStyle(fontSize: 18, fontWeight: FontWeight.w500);
            resolved = DefaultTextStyle.of(context).style.merge(written);
            return const Text('线路列表', style: written);
          }),
        ),
      ));

      expect(resolved.height, LuxwapTypography.lineHeight,
          reason: '页面不写 height 时应从 DefaultTextStyle 继承 1.21，'
              '否则由字体自身度量决定，垂直节奏与设计稿不一致');
      expect(resolved.fontSize, 18, reason: '显式字号不应被主题覆盖');
      expect(resolved.fontWeight, FontWeight.w500);
    });

    test('主题中每一档都用同一个行高比', () {
      final styles = <String, TextStyle>{
        'heading1': LuxwapTypography.heading1,
        'heading2': LuxwapTypography.heading2,
        'heading3': LuxwapTypography.heading3,
        'heading4': LuxwapTypography.heading4,
        'heading5': LuxwapTypography.heading5,
        'heading6': LuxwapTypography.heading6,
        'bodyLarge': LuxwapTypography.bodyLarge,
        'body': LuxwapTypography.body,
        'caption': LuxwapTypography.caption,
      };
      styles.forEach((name, style) {
        expect(style.height, LuxwapTypography.lineHeight,
            reason: '$name 的行高应为设计稿统一的 1.21，不应再用分级行高');
      });
    });
  });

  group('字号与字重落在设计稿比例内', () {
    /// Every size/weight pair present in LuxwapPC_v2.
    const scale = <(double, FontWeight)>[
      (30, FontWeight.w500), (30, FontWeight.w600),
      (28, FontWeight.w400), (28, FontWeight.w500), (28, FontWeight.w600),
      (26, FontWeight.w500),
      (24, FontWeight.w500),
      (22, FontWeight.w700),
      (20, FontWeight.w400), (20, FontWeight.w500), (20, FontWeight.w700),
      (19, FontWeight.w400),
      (18, FontWeight.w400), (18, FontWeight.w500),
      (18, FontWeight.w600), (18, FontWeight.w700),
      (16, FontWeight.w400), (16, FontWeight.w500),
      (15, FontWeight.w500),
      (14, FontWeight.w400), (14, FontWeight.w500),
      (13, FontWeight.w400),
      (12, FontWeight.w400), (12, FontWeight.w500),
      (11, FontWeight.w400),
      (10, FontWeight.w500),
    ];

    test('主题各档均在比例内', () {
      final styles = [
        LuxwapTypography.heading1, LuxwapTypography.heading2,
        LuxwapTypography.heading3, LuxwapTypography.heading4,
        LuxwapTypography.heading5, LuxwapTypography.heading6,
        LuxwapTypography.bodyLarge, LuxwapTypography.body,
        LuxwapTypography.caption,
      ];
      for (final style in styles) {
        final pair = (style.fontSize!, style.fontWeight!);
        expect(scale, contains(pair),
            reason: '${style.fontSize}px/${style.fontWeight} 不在设计稿的字号字重组合中');
      }
    });
  });

  group('字体族', () {
    test('主字体为设计稿使用的 Inter', () {
      expect(LuxwapTypography.primaryFont, 'Inter');
      expect(LuxwapTypography.body.fontFamily, 'Inter');
    });

    test('回退链覆盖中英文，且以通用族收尾', () {
      final fallbacks = LuxwapTypography.fontFallbacks;
      expect(fallbacks.last, 'sans-serif',
          reason: '回退链最后应是通用族，避免落到平台随机字体');
      expect(fallbacks, contains('Microsoft YaHei'), reason: 'Windows 中文');
      expect(fallbacks, contains('PingFang SC'), reason: 'macOS 中文');
    });
  });
}
