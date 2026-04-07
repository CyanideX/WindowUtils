# Tooltips

Hover tooltips for ImGui elements with styling variants, keybind hints, and multi-line support.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local tips = wu.Tooltips

ImGui.Button("Save")
tips.Show("Save current settings")

ImGui.Button("Delete")
tips.ShowDanger("This cannot be undone!")
```

All tooltip functions check `ImGui.IsItemHovered()` internally  - call them immediately after the ImGui element they describe.

> **`tooltipsEnabled` setting:** Only `Show()` and `ShowIf()` respect the global `tooltipsEnabled` setting. All other functions (`ShowAlways`, `ShowWrapped`, `ShowTitled`, `ShowColored`, `ShowMuted`, `ShowSuccess`, `ShowDanger`, `ShowWarning`, `ShowHelp`, `ShowKeybind`, `ShowWithHint`, `ShowLines`, `ShowBullets`, `ShowColor`) always display when hovered.

## Configuration

### `setDefaultWidthPct(pct)`

Set the default tooltip max width as a percentage of screen width. All `Show` and `ShowAlways` calls use this unless overridden per-call. Default is 15%.

```lua
tips.setDefaultWidthPct(20)  -- 20% of screen width
```

## API Reference

### Basic Tooltips

### `Show(text, widthPct?)`

Shows a tooltip on hover. Respects the global `tooltipsEnabled` setting. Text auto-wraps at the configured max width (default from `tooltipMaxWidthPct` setting, typically 15% of screen width).

| Parameter | Type | Description |
|-----------|------|-------------|
| text | string\|nil | Tooltip text (nil = no-op) |
| widthPct | number | Optional override for max width as screen-width percentage. Pass `0` to disable wrapping. |

### `ShowAlways(text, widthPct?)`

Shows a tooltip on hover regardless of the `tooltipsEnabled` setting. Text auto-wraps at the configured max width. Used for icon labels that always need explanation.

| Parameter | Type | Description |
|-----------|------|-------------|
| text | string | Tooltip text |
| widthPct | number | Optional override for max width as screen-width percentage. Pass `0` to disable wrapping. |

### `ShowWrapped(text, maxWidth?)`

Tooltip with text wrapping at a maximum width.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| text | string |  - | Tooltip text |
| maxWidth | number | 300 | Wrap width in pixels |

### Styled Tooltips

### `ShowTitled(title, description?)`

Tooltip with a title line, separator, and grey description text.

```lua
ImGui.Button("Export")
tips.ShowTitled("Export Settings", "Saves all presets to a JSON file in the mod folder.")
```

### `ShowColored(text, r, g, b, a?)`

Tooltip with custom text color (RGBA 0–1, alpha defaults to 1).

### `ShowMuted(text)` / `ShowSuccess(text)` / `ShowDanger(text)` / `ShowWarning(text)`

Pre-colored tooltip shortcuts:

| Function | Color |
|----------|-------|
| `ShowMuted` | Grey (0.6, 0.6, 0.6) |
| `ShowSuccess` | Green (0, 1, 0.7) |
| `ShowDanger` | Red (1, 0.3, 0.3) |
| `ShowWarning` | Yellow (1, 0.8, 0) |

### Conditional Tooltips

### `ShowIf(text, condition)`

Shows tooltip only when `condition` is true. Respects `tooltipsEnabled`.

### Info & Help Tooltips

### `ShowHelp(text)`

Tooltip with a blue `[?]` prefix and wrapped text. Good for explaining settings.

```lua
ImGui.Checkbox("Auto-save", autoSave)
tips.ShowHelp("Automatically saves settings when changes are made.")
```

### `ShowKeybind(action, keybind)`

Tooltip showing an action with its keybind in grey brackets.

```lua
ImGui.Button("Reset")
tips.ShowKeybind("Reset to defaults", "Right-click")
```

### `ShowWithHint(text, hint?)`

Tooltip with main text, separator, and grey hint text.

```lua
ImGui.SliderFloat("##vol", volume, 0, 1)
tips.ShowWithHint("Volume", "Right-click to reset")
```

### Multi-line Tooltips

### `ShowLines(lines)`

Tooltip with multiple text lines.

```lua
ImGui.Button("Info")
tips.ShowLines({"Line 1", "Line 2", "Line 3"})
```

### `ShowBullets(title?, bullets)`

Tooltip with optional title and bullet points.

```lua
ImGui.Button("Features")
tips.ShowBullets("Supported modes:", {"Standard", "Night Vision", "Thermal"})
```

## Color Tooltips

### `ShowColor(r, g, b, displayName, hex?)`

Shows a color tooltip with a small swatch preview, display name, and optional hex code. Uses the `ifHovered()` guard pattern (only renders when the previous item is hovered).

| Parameter | Type | Description |
|-----------|------|-------------|
| r | number | Red channel (0.0-1.0) |
| g | number | Green channel (0.0-1.0) |
| b | number | Blue channel (0.0-1.0) |
| displayName | string | Color display name shown next to the swatch |
| hex | string\|nil | Optional hex string shown as `#RRGGBB` below the name. Omitted if nil. |

```lua
ImGui.Button("##color_preview")
tips.ShowColor(1.0, 0.5, 0.0, "Sunset Orange", "FF8000")

-- Without hex code
ImGui.Button("##swatch")
tips.ShowColor(0.2, 0.6, 1.0, "Sky Blue")
```
