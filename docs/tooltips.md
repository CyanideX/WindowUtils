# Tooltips — WindowUtils Tooltip Helpers

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

All tooltip functions check `ImGui.IsItemHovered()` internally — call them immediately after the ImGui element they describe.

## API Reference

### Basic Tooltips

### `Show(text)`

Shows a tooltip on hover. Respects the global `tooltipsEnabled` setting.

| Parameter | Type | Description |
|-----------|------|-------------|
| text | string\|nil | Tooltip text (nil = no-op) |

### `ShowAlways(text)`

Shows a tooltip on hover regardless of the `tooltipsEnabled` setting. Used for icon labels that always need explanation.

### `ShowWrapped(text, maxWidth?)`

Tooltip with text wrapping at a maximum width.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| text | string | — | Tooltip text |
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
