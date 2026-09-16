import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Reads the trimmed Figma node cache produced by `tool/trim_figma_cache.py`.
///
/// Resolution order:
///   1. `FIGMA_CACHE_DIR` environment variable (point it at a live MCP cache)
///   2. `test/visual/figma_cache` committed in this repo (the default)
///   3. `~/.mcp-figma/cache/pages` written by the Figma MCP server
///
/// When no cache is found [available] is false and callers should skip rather
/// than fail, so a checkout without the cache still runs the rest of the suite.
class FigmaCache {
  FigmaCache._(this._dir, this._index);

  final Directory _dir;
  final List<Map<String, dynamic>> _index;

  static FigmaCache? _instance;
  static bool _resolved = false;

  static FigmaCache? get instance {
    if (!_resolved) {
      _resolved = true;
      _instance = _resolve();
    }
    return _instance;
  }

  static bool get available => instance != null;

  /// Reason to show when the cache is missing, for `skip:` messages.
  static String get unavailableReason =>
      'Figma cache not found. Run `python tool/trim_figma_cache.py` '
      'or set FIGMA_CACHE_DIR to a Figma MCP cache directory.';

  static FigmaCache? _resolve() {
    final candidates = <String>[
      if (Platform.environment['FIGMA_CACHE_DIR'] != null)
        Platform.environment['FIGMA_CACHE_DIR']!,
      'test/visual/figma_cache',
      if (_home != null) '$_home/.mcp-figma/cache/pages',
    ];
    for (final path in candidates) {
      final dir = Directory(path);
      final index = File('${dir.path}/index.json');
      if (dir.existsSync() && index.existsSync()) {
        final decoded = jsonDecode(index.readAsStringSync()) as List<dynamic>;
        return FigmaCache._(dir, decoded.cast<Map<String, dynamic>>());
      }
    }
    return null;
  }

  static String? get _home =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  /// Page names available in this cache, for diagnostics.
  List<String> get pageNames =>
      _index.map((e) => e['name'] as String).toList(growable: false);

  /// Loads a page by Figma node id (`'30:3693'`) or by name substring
  /// (`'主页-线路'`). Throws with the available names when nothing matches.
  FigmaNode page(String nameOrId) {
    final entry = _index.firstWhere(
      (e) => e['id'] == nameOrId || (e['name'] as String).contains(nameOrId),
      orElse: () => throw StateError(
          'No Figma page matching "$nameOrId". Available: ${pageNames.join(', ')}'),
    );
    final file = File('${_dir.path}/${entry['slug']}.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return FigmaNode._(json['root'] as Map<String, dynamic>);
  }
}

/// A single node from the trimmed Figma tree.
class FigmaNode {
  FigmaNode._(this._json);

  final Map<String, dynamic> _json;

  String get id => _json['id'] as String? ?? '';
  String get name => _json['name'] as String? ?? '';
  String get type => _json['type'] as String? ?? '';

  /// Literal text content, with Figma's zero-width joiners already stripped.
  String? get characters => _json['chars'] as String?;

  List<FigmaNode> get children => ((_json['children'] as List<dynamic>?) ?? [])
      .map((e) => FigmaNode._(e as Map<String, dynamic>))
      .toList(growable: false);

  // ---- geometry -------------------------------------------------------

  List<double>? get _box =>
      (_json['box'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();

  /// Absolute canvas coordinates. Only differences between siblings are
  /// meaningful — use them to derive gaps and row pitch from the design.
  double get left => _box?[0] ?? 0;
  double get top => _box?[1] ?? 0;

  double get width => _box?[2] ?? 0;
  double get height => _box?[3] ?? 0;
  Size get size => Size(width, height);

  /// Uniform corner radius, or null when the node has none / has mixed corners.
  double? get radius {
    final r = _json['radius'];
    if (r is num) return r.toDouble();
    final radii = _json['radii'] as List<dynamic>?;
    if (radii != null && radii.toSet().length == 1) {
      return (radii.first as num).toDouble();
    }
    return null;
  }

  /// Per-corner radii in Figma order: top-left, top-right, bottom-right, bottom-left.
  List<double>? get radii =>
      (_json['radii'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();

  // ---- paint ----------------------------------------------------------

  /// First visible solid fill, or null when the node has no solid fill.
  Color? get fill => _solid(_json['fills']);

  /// Gradient stop colors in order, empty when the first fill is not a gradient.
  List<Color> get gradientStops {
    final fills = _json['fills'] as List<dynamic>?;
    if (fills == null || fills.isEmpty) return const [];
    final first = fills.first as Map<String, dynamic>;
    if (first['type'] != 'gradient') return const [];
    return ((first['stops'] as List<dynamic>?) ?? [])
        .map((s) => _color((s as Map<String, dynamic>)['color'] as String)!)
        .toList(growable: false);
  }

  Color? get strokeColor => _solid(_json['strokes']);

  double? get strokeWeight => (_json['strokeWeight'] as num?)?.toDouble();

  double? get opacity => (_json['opacity'] as num?)?.toDouble();

  Color? _solid(dynamic paints) {
    final list = paints as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    for (final p in list.cast<Map<String, dynamic>>()) {
      if (p['type'] == 'solid') return _color(p['color'] as String?);
    }
    return null;
  }

  static Color? _color(String? argb) =>
      argb == null ? null : Color(int.parse(argb));

  // ---- typography -----------------------------------------------------

  Map<String, dynamic>? get _text => _json['text'] as Map<String, dynamic>?;

  double? get fontSize => (_text?['fontSize'] as num?)?.toDouble();

  double? get lineHeight => (_text?['lineHeightPx'] as num?)?.toDouble();

  double? get letterSpacing => (_text?['letterSpacing'] as num?)?.toDouble();

  /// Figma's numeric weight mapped onto Flutter's [FontWeight].
  FontWeight? get fontWeight {
    final w = (_text?['fontWeight'] as num?)?.round();
    if (w == null) return null;
    const table = {
      100: FontWeight.w100, 200: FontWeight.w200, 300: FontWeight.w300,
      400: FontWeight.w400, 500: FontWeight.w500, 600: FontWeight.w600,
      700: FontWeight.w700, 800: FontWeight.w800, 900: FontWeight.w900,
    };
    return table[w];
  }

  // ---- auto layout ----------------------------------------------------

  Map<String, dynamic>? get _layout => _json['layout'] as Map<String, dynamic>?;

  /// Auto-layout item spacing, or null when the node is not an auto-layout frame.
  double? get gap => (_layout?['gap'] as num?)?.toDouble();

  /// Auto-layout padding as EdgeInsets, or null when not an auto-layout frame.
  EdgeInsets? get padding {
    final pad = _layout?['pad'] as List<dynamic>?;
    if (pad == null) return null;
    return EdgeInsets.only(
      top: (pad[0] as num).toDouble(),
      right: (pad[1] as num).toDouble(),
      bottom: (pad[2] as num).toDouble(),
      left: (pad[3] as num).toDouble(),
    );
  }

  // ---- lookup ---------------------------------------------------------

  /// Depth-first search by exact layer name. Throws when absent.
  FigmaNode byName(String name) =>
      maybeByName(name) ??
      (throw StateError('No node named "$name" under "${this.name}"'));

  FigmaNode? maybeByName(String name) {
    if (this.name == name) return this;
    for (final c in children) {
      final hit = c.maybeByName(name);
      if (hit != null) return hit;
    }
    return null;
  }

  /// Every descendant with this layer name, in document order.
  List<FigmaNode> allByName(String name) {
    final out = <FigmaNode>[];
    void walk(FigmaNode n) {
      if (n.name == name) out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(this);
    return out;
  }

  /// Depth-first search for a TEXT node whose content contains [text].
  FigmaNode byText(String text) =>
      maybeByText(text) ??
      (throw StateError('No text node containing "$text" under "$name"'));

  FigmaNode? maybeByText(String text) {
    if (characters != null && characters!.contains(text)) return this;
    for (final c in children) {
      final hit = c.maybeByText(text);
      if (hit != null) return hit;
    }
    return null;
  }

  @override
  String toString() => '$type "$name" ${width}x$height';
}
