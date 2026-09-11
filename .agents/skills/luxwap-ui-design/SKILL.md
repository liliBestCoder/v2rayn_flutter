---
name: "luxwap-ui-design"
description: "Use this skill to generate well-branded interfaces and assets for LuxwapUI — a flat-professional PC client for network/flow services. Contains essential design guidelines, colors, type, fonts, component references, and UI kit patterns."
---

# LuxwapUI Design Skill

Explore the available files in this skill first, then use them to produce on-brand UI, prototypes, and implementation details for LuxwapUI.

If creating visual artifacts, build static HTML the user can review. If working on production code, copy the tokens and patterns here so the result keeps LuxwapUI's clean, spacious, blue-led aesthetic.

If the user invokes this skill without further guidance, ask what they want to build, clarify platform and scope, and then respond as a senior product designer who can output HTML artifacts or production-ready UI code.

## Quick map

- `colors_and_type.css` — drop-in CSS variables for color, type, radius, shadow, spacing
- `css.json` — programmatic token export for tooling and implementation
- `components/index.json` — component index and cross-pattern summary
- `components/button.json` — primary CTA, secondary, filter chips, and long login buttons
- `components/input.json` — rounded form inputs with placeholder and focus states
- `components/card.json` — dashboard/traffic info cards
- `components/navigation.json` — main navigation and tab selectors
- `components/switch.json` — connection state switch (linked/unlinked)
- `preview/index.html` — live token/component preview
- `assets/previews/01-thumbnail.png` — source preview image

## Essentials at a glance

- Solo-design prefix: `luxwap-ui` (semantic aliases such as `--luxwap-ui-background`, `--luxwap-ui-foreground`, `--luxwap-ui-primary` are provided for stable consumption).
- Primary brand color is **Luxwap Blue `#286afc`**: crisp, trustworthy, and tech-forward; pair it with Cloud White `#ffffff`, Soft Gray `#f7f7f8`, and Ink `#1b1b1b`.
- Radius is intentionally modest: `5px` for inputs and tags, `15px` for cards and buttons, `30px` / pill for chips and avatars.
- Spacing base is `2px`; practical scale runs `4, 8, 12, 16, 24, 32, 48, 64, 96px`. The interface uses generous padding (`61–66px` in observed page containers).
- Typography uses **MiSans** for all Chinese and Latin interface text, with **Inter** as a secondary latin fallback. Weights are restrained to `400` and `500`.
- UI copy is predominantly Chinese: 筛选, 刷新, 账号登录, 交易记录, 线路, 已连接, 未连接, 发送, 在线充值, etc.
- Components are flat: no heavy shadows at rest; only subtle drop shadows (`2xs/xs/sm`) for elevation.
- Dark mode is supported via the `.dark` class; it inverts surfaces to near-black and uses a lighter blue `#71affc` for primary actions.