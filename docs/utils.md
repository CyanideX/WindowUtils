# Utils

Low-level helper functions used across WindowUtils modules.

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

### `isAltHeld()`

Check if either Alt key is currently held.

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

### `getDragSpeed(baseSpeed, multiplier?)`

Compute drag speed with shift-precision applied. ImGui natively multiplies drag speed by 10x when Shift is held, so this counters that and applies a configurable multiplier.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| baseSpeed | number | - | Normal drag speed |
| multiplier | number | 0.1 | Speed multiplier when Shift is held |

**Returns:** `number` - effective drag speed for this frame

### `cachedCalcTextSize(text, charWidth)`

Cache `ImGui.CalcTextSize` results, invalidated when charWidth changes (font/DPI change).

| Parameter | Type | Description |
|-----------|------|-------------|
| text | string | Text to measure |
| charWidth | number | Current character width for cache invalidation |

**Returns:** `number` - pixel width of text

### `cachedTruncateText(label, innerWidth, charWidth)`

Cache truncated text results, invalidated when charWidth changes.

| Parameter | Type | Description |
|-----------|------|-------------|
| label | string | Text to truncate |
| innerWidth | number | Available pixel width |
| charWidth | number | Current character width for cache invalidation |

**Returns:** `string, boolean` - truncated text, whether truncation occurred


## Color Conversion

Pure functions for converting between hex, RGB, and HSL color representations. All RGB and HSL values use 0.0-1.0 float ranges.

### `HexToRGB(hex)`

Convert a 6-character hex string to RGB floats. Accepts hex with or without a `#` prefix. Returns the fallback `0.5, 0.5, 0.5` for invalid input (nil, empty, non-string, wrong length, or non-hex characters).

| Parameter | Type | Description |
|-----------|------|-------------|
| hex | string\|nil | Hex color string, e.g. `"FF8800"` or `"#FF8800"` |

**Returns:** `number, number, number` - r, g, b each 0.0-1.0

```lua
local r, g, b = utils.HexToRGB("FF0000")    -- 1.0, 0.0, 0.0
local r, g, b = utils.HexToRGB("#00FF00")   -- 0.0, 1.0, 0.0
local r, g, b = utils.HexToRGB(nil)         -- 0.5, 0.5, 0.5 (fallback)
```

### `RGBToHex(r, g, b)`

Convert RGB floats to a 6-character uppercase hex string. Inputs outside [0.0, 1.0] are clamped before conversion.

| Parameter | Type | Description |
|-----------|------|-------------|
| r | number | Red channel (0.0-1.0) |
| g | number | Green channel (0.0-1.0) |
| b | number | Blue channel (0.0-1.0) |

**Returns:** `string` - 6-character uppercase hex (e.g. `"FF8800"`)

```lua
local hex = utils.RGBToHex(1, 0, 0)         -- "FF0000"
local hex = utils.RGBToHex(0.5, 0.5, 0.5)   -- "808080"
```

### `RGBToHSL(r, g, b)`

Convert RGB floats to HSL floats. Achromatic colors (where r, g, and b are equal) return h=0, s=0.

| Parameter | Type | Description |
|-----------|------|-------------|
| r | number | Red channel (0.0-1.0) |
| g | number | Green channel (0.0-1.0) |
| b | number | Blue channel (0.0-1.0) |

**Returns:** `number, number, number` - h, s, l each 0.0-1.0

```lua
local h, s, l = utils.RGBToHSL(1, 0, 0)       -- 0.0, 1.0, 0.5 (pure red)
local h, s, l = utils.RGBToHSL(1, 1, 1)       -- 0.0, 0.0, 1.0 (white, achromatic)
local h, s, l = utils.RGBToHSL(0.5, 0.5, 0.5) -- 0.0, 0.0, 0.5 (grey, achromatic)
```

## Reusable Table Convention

WindowUtils modules frequently reuse pre-allocated tables to avoid per-frame garbage collection pressure. The convention distinguishes two cases:

### When to Reuse

Tables used only within a single frame's scope (internal scratch buffers, intermediate results consumed immediately by the caller before the next frame) should be allocated once at module level and reset each use. This avoids per-frame garbage.

**Examples:**
- `dragdrop.lua` `reusableCtx` - scratch context rebuilt every frame
- `controls.lua` `actionButtonResult` - result table read immediately by caller

### When to Allocate Fresh

Tables returned to callers who may store references (public API return values, callback arguments, tables passed to other modules that might cache them) must be freshly allocated. Reusing would silently corrupt stored references.

**Examples:**
- `registry.getAll()` returns a copy
- `dragdrop.createState()` returns a new state object

### Pattern

```lua
local reusable = { field1 = false, field2 = 0 }

function myModule.compute(input)
    reusable.field1 = input > 0
    reusable.field2 = input * 2
    return reusable  -- caller must read fields before next call
end
```
