# Utils  - WindowUtils Shared Utilities

Low-level helper functions used across WindowUtils modules. Available for direct use in mods that need icon resolution, text truncation, or size parsing.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local utils = wu.Utils

-- Resolve icon name to glyph
local icon = utils.resolveIcon("ContentSave")  -- returns the glyph character

-- Truncate text to fit a width
local display, wasCut = utils.truncateText("Very long window title here", 120)

-- Parse size specifications (pixels, percentages, or nil)
local px = utils.parseSizeSpec("25%", 800)  -- returns 200
```

## API Reference

### `resolveIcon(icon)`

Resolve an icon name to its glyph character. If `IconGlyphs` is available and the name matches, returns the glyph. Otherwise returns the input string as-is.

| Parameter | Type | Description |
|-----------|------|-------------|
| icon | string\|nil | Icon name (e.g. `"ContentSave"`) or raw glyph string |

**Returns:** `string|nil`  - the resolved glyph, or nil if input was nil/empty

```lua
local glyph = utils.resolveIcon("ContentSave")  -- IconGlyphs.ContentSave
local raw = utils.resolveIcon("X")               -- "X" (no match, returned as-is)
local none = utils.resolveIcon(nil)              -- nil
```

### `truncateText(text, maxWidth)`

Binary-search truncation that fits text within a pixel width, appending `"..."` when truncated. Must be called during `onDraw` (requires ImGui context for text measurement).

| Parameter | Type | Description |
|-----------|------|-------------|
| text | string | The full text |
| maxWidth | number | Maximum pixel width |

**Returns:** `string, boolean`  - display text, whether truncation occurred

```lua
local label, wasTruncated = utils.truncateText(windowTitle, 150)
ImGui.Text(label)
if wasTruncated then
    tooltips.ShowAlways(windowTitle)  -- show full text on hover
end
```

### `parseSizeSpec(spec, available)`

Parse a size specification into pixels. Supports absolute pixels, percentage strings, or nil (flex).

| Parameter | Type | Description |
|-----------|------|-------------|
| spec | number\|string\|nil | Pixel value, percentage string (e.g. `"30%"`), or nil |
| available | number | Total available space in pixels |

**Returns:** `number|nil`  - computed pixel value, or nil if spec was nil/invalid

```lua
utils.parseSizeSpec(200, 800)    -- 200 (absolute pixels)
utils.parseSizeSpec("25%", 800)  -- 200 (percentage of available)
utils.parseSizeSpec(nil, 800)    -- nil (flex / no fixed size)
```

Used internally by `Splitter.multi()` for panel width/height/min/max specifications.

### `isCtrlHeld()`

Check if either Ctrl key is currently held.

**Returns:** `boolean`

### `isShiftHeld()`

Check if either Shift key is currently held.

**Returns:** `boolean`

### `snapToIncrement(val, increment?)`

Snap a value to the nearest increment.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| val | number |  - | The value to snap |
| increment | number | 0.05 | The snap increment |

**Returns:** `number`  - snapped value

```lua
utils.snapToIncrement(0.37)        -- 0.35 (nearest 0.05)
utils.snapToIncrement(0.37, 0.1)   -- 0.4 (nearest 0.1)
```

### `minIconButtonWidth(framePaddingX?)`

Compute the minimum usable width for a single icon button based on live ImGui measurements. Must be called during `onDraw`.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| framePaddingX | number\|nil | `ImGui.GetStyle().FramePadding.x` | Override frame padding for the calculation |

**Returns:** `number`  - minimum pixel width (icon glyph + frame padding)

Used internally by `Splitter.multi()` to auto-detect minimum panel widths.
