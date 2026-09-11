---
name: "LuxwapUI Design System"
---

# LuxwapUI Design System

Design system for **LuxwapUI** PC client, extracted from `luxwap.fig`.

## Brand Summary

- **Name**: LuxwapUI
- **Style**: flat-professional, spacious, cool
- **Primary language**: Chinese (MiSans)
- **Secondary latin font**: Inter
- **Primary brand color**: `#286afc`
- **Theme modes**: light (default), dark (`.dark`)

## File Map

- `colors_and_type.css` — drop-in CSS variables for color, type, radius, shadow, and spacing
- `css/colors_and_type.css` — mirrored copy for stable consumption
- `css.json` — programmatic token export
- `components/index.json` — component index
- `components/button.json` — buttons, chips, long CTAs
- `components/input.json` — form inputs
- `components/card.json` — data cards / traffic info card
- `components/navigation.json` — main nav and tab selectors
- `components/switch.json` — connection state switch
- `assets/previews/01-thumbnail.png` — source preview image
- `preview/index.html` — live token/component preview

## Color Tokens

### Brand

| Token | Value |
| --- | --- |
| `--brand-500` | `#286afc` |
| `--brand-400` | `#71affc` |
| `--brand-50` | `#e9f0ff` |

### Neutral

| Token | Value |
| --- | --- |
| `--neutral-0` | `#ffffff` |
| `--neutral-50` | `#f7f7f8` |
| `--neutral-100` | `#f3f6fb` |
| `--neutral-200` | `#eaeaea` |
| `--neutral-300` | `#dfdfdf` |
| `--neutral-400` | `#b2b2b2` |
| `--neutral-500` | `#999bab` |
| `--neutral-600` | `#666666` |
| `--neutral-700` | `#3d3d3d` |
| `--neutral-800` | `#1b1b1b` |
| `--neutral-900` | `#000000` |

### State

| Token | Value |
| --- | --- |
| `--state-success` | `#27a53c` |
| `--state-error` | `#ed462b` |
| `--state-warning` | `#ff8800` |

### Accent

| Token | Value |
| --- | --- |
| `--accent-red` | `#ff383c` |
| `--accent-orange` | `#ff8d28` |

## Typography

| Token | Size | Weight | Line Height |
| --- | --- | --- | --- |
| `--heading-1` | 20px | 500 | 20px |
| `--heading-2` | 20px | 400 | 20px |
| `--heading-3` | 18px | 400 | 18px |
| `--heading-4` | 18px | 500 | 18px |
| `--heading-5` | 16px | 500 | 16px |
| `--heading-6` | 16px | 400 | 16px |
| `--body-large` | 14px | 500 | 14px |
| `--body` | 12px | 400 | 12px |

## Radius

| Token | Value |
| --- | --- |
| `--radius-sm` | 5px |
| `--radius-md` | 15px |
| `--radius-lg` | 30px |

## Shadows

| Token | Value |
| --- | --- |
| `--shadow-2xs` | `0px 2px 4px 0px rgba(0,0,0,0.25)` |
| `--shadow-xs` | `0px 2px 6px 0px rgba(0,0,0,0.18)` |
| `--shadow-sm` | `0px 3px 6px 0px rgba(0,0,0,0.161)` |

## Usage

Link `colors_and_type.css` in the HTML head:

```html
<link rel="stylesheet" href=".design_library/LuxwapUI/colors_and_type.css" />
```

Consume semantic tokens in CSS:

```css
.my-button {
  background: var(--primary);
  color: var(--primary-foreground);
  border-radius: var(--radius-md);
  font-family: var(--font-sans);
}
```
