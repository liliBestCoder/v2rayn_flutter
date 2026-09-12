---
name: figma-design-sync
description: Inspect Figma design files, parse design tokens (colors, typography, spacing, shadows), export SVG/images, and translate Figma frames directly into clean, on-brand Flutter UI components aligned with LuxwapUI design system.
---

# Figma Design Sync & Flutter UI Implementation Guide

Use this skill when implementing UI designs from Figma links, node IDs, or design tokens into Flutter code for Luxwap.

## Workflow Overview

1. **Extract Design Info**:
   - Given a Figma file URL (e.g. `https://www.figma.com/design/:fileKey/:fileName?node-id=:nodeId`), extract the fileKey and nodeId.
   - Query node structure, layout mode (AutoLayout), padding, gap, typography, fills, and corner radii.
   - If images or icons are needed, export them via Figma API / MCP image tools to `assets/` or convert SVG icons to Flutter `CustomPainter` / IconData.

2. **Map Figma Layouts to Flutter Widgets**:
   - **Horizontal AutoLayout** -> `Row`
     - `primaryAxisAlignItems: CENTER` -> `mainAxisAlignment: MainAxisAlignment.center`
     - `counterAxisAlignItems: CENTER` -> `crossAxisAlignment: CrossAxisAlignment.center`
     - `itemSpacing` -> `SizedBox(width: itemSpacing)`
   - **Vertical AutoLayout** -> `Column`
     - `itemSpacing` -> `SizedBox(height: itemSpacing)`
   - **Padding** -> `Padding(padding: EdgeInsets.fromLTRB(paddingLeft, paddingTop, paddingRight, paddingBottom))`
   - **Fixed / Fill Container**:
     - Figma `Fill` (horizontal) -> `Expanded` or `width: double.infinity`
     - Figma `Hug` -> Default size / wrap content
     - Figma `Fixed` -> Explicit `width` / `height`
   - **Corner Radius**:
     - Figma `cornerRadius: 15` -> `BorderRadius.circular(15)`
   - **Fills & Borders**:
     - Solid color fill -> `BoxDecoration(color: Color(0xFF...))`
     - Stroke / Border -> `border: Border.all(color: Color(0xFF...), width: ...)`

3. **Align with LuxwapUI Design Tokens**:
   - **Primary Color**: `#286afc` (Dark mode action: `#71affc`)
   - **Background**: Light `#ffffff`, Soft Gray `#f7f7f8`, Dark `#1b1b1b`
   - **Font**: `MiSans` with `Inter` fallback.
   - **Font Weights**: Strict restraint to 400 (regular) and 500 (medium). No harsh bold weights (600/700+).
   - **Cards / Buttons**: Standard radius 15px.
   - **Inputs**: Standard radius 5px.
   - **Chips / Pills / Avatars**: Standard radius 30px.

4. **Code Quality**:
   - Produce clean, modular, responsive Flutter widgets.
   - Ensure clean state management with `AppState` and `AppScope`.
   - Verify widget layout in both Windows and macOS desktop frame sizes.