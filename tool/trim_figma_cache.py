#!/usr/bin/env python3
"""Trim the Figma MCP node cache into a compact, repo-committable spec.

Source : ~/.mcp-figma/cache/pages/*.json  (written by the Figma MCP server)
Target : test/visual/figma_cache/*.json   (read by test/visual/figma_cache.dart)

Only the fields the visual tests assert on are kept, so the result is small
enough to commit and diff. Re-run after refreshing the MCP cache.
"""
import json, os, sys, glob, re

KEEP_PAGES = [
    '主页_线路', '个人中心', '交易管理', '设置', '分享有礼',
    '关于', '登陆', '注册', '验证邮箱', '组件库',
]

def keep(node):
    out = {
        'id': node.get('id'),
        'name': node.get('name'),
        'type': node.get('type'),
    }
    bb = node.get('absoluteBoundingBox')
    if bb:
        out['box'] = [round(bb.get('x', 0), 2), round(bb.get('y', 0), 2),
                      round(bb.get('width', 0), 2), round(bb.get('height', 0), 2)]

    fills = [f for f in (node.get('fills') or []) if f.get('visible') is not False]
    if fills:
        out['fills'] = [encode_paint(f) for f in fills]

    strokes = [s for s in (node.get('strokes') or []) if s.get('visible') is not False]
    if strokes:
        out['strokes'] = [encode_paint(s) for s in strokes]
        out['strokeWeight'] = node.get('strokeWeight')

    if node.get('cornerRadius') is not None:
        out['radius'] = node['cornerRadius']
    if node.get('rectangleCornerRadii'):
        out['radii'] = node['rectangleCornerRadii']

    st = node.get('style') or {}
    if st:
        out['text'] = {
            k: st[k] for k in
            ('fontFamily', 'fontSize', 'fontWeight', 'lineHeightPx',
             'letterSpacing', 'textAlignHorizontal')
            if st.get(k) is not None
        }
    if node.get('characters'):
        out['chars'] = node['characters'].replace('​', '')

    lm = node.get('layoutMode')
    if lm and lm != 'NONE':
        out['layout'] = {
            'mode': lm,
            'gap': node.get('itemSpacing', 0),
            'pad': [node.get('paddingTop', 0), node.get('paddingRight', 0),
                    node.get('paddingBottom', 0), node.get('paddingLeft', 0)],
        }

    if node.get('opacity') is not None and node['opacity'] < 0.999:
        out['opacity'] = node['opacity']

    kids = [keep(c) for c in (node.get('children') or []) if c.get('visible') is not False]
    if kids:
        out['children'] = kids
    return out


def encode_paint(p):
    t = p.get('type', '')
    if t == 'SOLID':
        return {'type': 'solid', 'color': argb(p.get('color'), p.get('opacity'))}
    if t.startswith('GRADIENT'):
        return {
            'type': 'gradient',
            'kind': t.replace('GRADIENT_', '').lower(),
            'stops': [{'color': argb(s['color']), 'pos': round(s['position'], 4)}
                      for s in p.get('gradientStops', [])],
        }
    return {'type': t.lower()}


def argb(c, opacity=None):
    """Return an 0xAARRGGBB int string matching Dart's Color literal format."""
    if not c:
        return None
    a = c.get('a', 1.0)
    if opacity is not None:
        a *= opacity
    v = (round(a * 255) << 24) | (round(c.get('r', 0) * 255) << 16) \
        | (round(c.get('g', 0) * 255) << 8) | round(c.get('b', 0) * 255)
    return '0x%08X' % v


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.expanduser('~/.mcp-figma/cache/pages')
    dst = sys.argv[2] if len(sys.argv) > 2 else 'test/visual/figma_cache'
    if not os.path.isdir(src):
        sys.exit('figma cache not found: %s' % src)
    os.makedirs(dst, exist_ok=True)

    index = []
    for path in sorted(glob.glob(os.path.join(src, 'page_*.json'))):
        base = os.path.basename(path)
        if not any(k in base for k in KEEP_PAGES):
            continue
        raw = json.load(open(path, encoding='utf-8'))
        # Name files by node id only: ASCII-safe across platforms and CI.
        slug = 'node_' + str(raw.get('id', '')).replace(':', '_')
        trimmed = {'id': raw.get('id'), 'name': raw.get('name'),
                   'root': keep(raw['data'])}
        out = os.path.join(dst, slug + '.json')
        with open(out, 'w', encoding='utf-8') as f:
            json.dump(trimmed, f, ensure_ascii=False, separators=(',', ':'))
        index.append({'slug': slug, 'id': raw.get('id'), 'name': raw.get('name')})
        print('%-44s %6.1f KB -> %6.1f KB' % (
            slug, os.path.getsize(path) / 1024, os.path.getsize(out) / 1024))

    with open(os.path.join(dst, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
    print('\n%d pages -> %s' % (len(index), dst))


main()
