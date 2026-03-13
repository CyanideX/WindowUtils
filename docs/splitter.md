# Splitter — WindowUtils Panel Dividers

Draggable dividers for two-panel layouts with visual feedback and percentage-based sizing.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local split = wu.Splitter

-- Horizontal split: left panel | right panel
split.horizontal("myPanels", function()
    ImGui.Text("Left side")
end, function()
    ImGui.Text("Right side")
end, { defaultPct = 0.3 })
```

## API Reference

### `horizontal(id, leftFn, rightFn, opts?)`

Create a horizontal split (left | right) with a draggable grab bar.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Unique splitter ID |
| leftFn | function | — | Renders left panel content |
| rightFn | function | — | Renders right panel content |
| opts.defaultPct | number | 0.5 | Default split position (0–1) |
| opts.minPct | number | 0.1 | Minimum left panel percentage |
| opts.maxPct | number | 0.9 | Maximum left panel percentage |
| opts.grabWidth | number | ItemSpacing.x | Grab bar width in pixels |

**Returns:** `number` — current split percentage

Alias: `splitter.h(...)` — shorthand for `splitter.horizontal(...)`.

### `vertical(id, topFn, bottomFn, opts?)`

Create a vertical split (top / bottom) with a draggable grab bar.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Unique splitter ID |
| topFn | function | — | Renders top panel content |
| bottomFn | function | — | Renders bottom panel content |
| opts.defaultPct | number | 0.5 | Default split position (0–1) |
| opts.minPct | number | 0.1 | Minimum top panel percentage |
| opts.maxPct | number | 0.9 | Maximum top panel percentage |
| opts.grabWidth | number | ItemSpacing.x | Grab bar height in pixels |

**Returns:** `number` — current split percentage

Alias: `splitter.v(...)` — shorthand for `splitter.vertical(...)`.

### `getSplitPct(id)`

Get current split percentage for a splitter.

**Returns:** `number|nil` — percentage, or nil if not initialized

### `setSplitPct(id, pct)`

Set split percentage programmatically. Value is clamped to the splitter's min/max range.

### `reset(id)`

Reset splitter to its default percentage.

## Examples

### Sidebar + Content Layout

```lua
split.horizontal("sidebar", function()
    -- Sidebar navigation
    for i, item in ipairs(menuItems) do
        if ImGui.Selectable(item.label, selected == i) then
            selected = i
        end
    end
end, function()
    -- Main content area
    menuItems[selected].draw()
end, { defaultPct = 0.25, minPct = 0.15, maxPct = 0.4 })
```

### Top/Bottom Split

```lua
split.vertical("editor", function()
    -- Code/content area
    ImGui.InputTextMultiline("##code", code, 4096, 0, 0)
end, function()
    -- Output/log area
    for _, line in ipairs(output) do
        ImGui.Text(line)
    end
end, { defaultPct = 0.7 })
```

## Visual Feedback

The grab bar shows state through color and cursor changes:
- **Idle** — transparent, icon in muted grey
- **Hover** — subtle blue background, bright icon, resize cursor
- **Dragging** — green background, white icon, resize cursor

Icon glyphs (requires IconGlyphs): vertical bars for horizontal splits, horizontal bars for vertical splits. Falls back to `||` / `==` text.
