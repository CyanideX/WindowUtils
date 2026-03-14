# Splitter — WindowUtils Panel Dividers

Draggable dividers for two-panel, multi-panel, and collapsible toggle layouts with visual feedback and animated transitions.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local split = wu.Splitter

-- Simple horizontal split: left | right
split.horizontal("myPanels", function()
    ImGui.Text("Left side")
end, function()
    ImGui.Text("Right side")
end, { defaultPct = 0.3 })

-- Multi-panel layout with weighted sizes
split.multi("layout", {
    { width = 200, content = drawSidebar },
    { content = drawMain },
    { width = "25%", content = drawProps },
}, { direction = "horizontal" })

-- Collapsible toggle panel
split.toggle("toolbar", {
    { content = drawToolbar },
    { content = drawCanvas },
}, { side = "left", size = 200 })
```

## Two-Panel Splits

### `horizontal(id, leftFn, rightFn, opts?)`

Create a horizontal split (left | right) with a draggable grab bar.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Unique splitter ID |
| leftFn | function\|nil | — | Renders left panel content |
| rightFn | function\|nil | — | Renders right panel content |
| opts.defaultPct | number | 0.5 | Default split position (0–1) |
| opts.minPct | number | 0.1 | Minimum left panel fraction |
| opts.maxPct | number | 0.9 | Maximum left panel fraction |
| opts.grabWidth | number | ItemSpacing.x | Grab bar width in pixels |

**Returns:** `number` — current split fraction (0–1)

**Alias:** `split.h(...)`

### `vertical(id, topFn, bottomFn, opts?)`

Create a vertical split (top / bottom) with a draggable grab bar.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Unique splitter ID |
| topFn | function\|nil | — | Renders top panel content |
| bottomFn | function\|nil | — | Renders bottom panel content |
| opts.defaultPct | number | 0.5 | Default split position (0–1) |
| opts.minPct | number | 0.1 | Minimum top panel fraction |
| opts.maxPct | number | 0.9 | Maximum top panel fraction |
| opts.grabWidth | number | ItemSpacing.x | Grab bar height in pixels |

**Returns:** `number` — current split fraction (0–1)

**Alias:** `split.v(...)`

### Two-Panel State Functions

#### `getSplitPct(id)`

Get current split fraction for a two-panel splitter.

**Returns:** `number|nil` — fraction (0–1), or nil if not initialized

#### `setSplitPct(id, pct)`

Set split fraction programmatically. Value is clamped to the splitter's min/max range.

#### `reset(id)`

Reset splitter to its default fraction. Cancels any collapse animation.

## Multi-Panel Splits

### `multi(id, panels, opts?)`

Layout with any number of panels separated by independently draggable dividers. Each divider only affects its two adjacent panels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Unique splitter ID |
| panels | table | — | Array of panel definitions (see below) |
| opts.direction | string | "horizontal" | `"horizontal"` or `"vertical"` |
| opts.grabWidth | number | ItemSpacing.x | Divider width in pixels |
| opts.minPct | number | 0.05 | Minimum panel fraction (fallback) |
| opts.defaultPcts | table\|nil | nil | Array of initial fractions per panel |

**Alias:** `split.m(...)`

### Panel Definition Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| content | function | — | Renders panel content |
| width | number\|string\|nil | nil | Fixed width: pixels or `"25%"` (horizontal) |
| height | number\|string\|nil | nil | Fixed height: pixels or `"25%"` (vertical) |
| minWidth | number\|string\|nil | auto | Minimum width: pixels or percentage |
| minHeight | number\|string\|nil | auto | Minimum height: pixels or percentage |
| maxWidth | number\|string\|nil | nil | Maximum width: pixels or percentage |
| maxHeight | number\|string\|nil | nil | Maximum height: pixels or percentage |
| flex | number | 1 | Proportional weight for remaining space |
| autoMin | boolean | true | Auto-detect minimum from icon button width |

Size specs accept pixels (`200`), percentages (`"25%"`), or nil (flex). Panels with an explicit width/height are "fixed" — they get their requested size first. Remaining space is distributed to flex panels proportionally by `flex` weight.

When `autoMin` is true (default) and no explicit min is set, panels automatically get a minimum width equal to one icon button plus window padding — preventing panels from collapsing to zero.

```lua
-- 3-panel IDE layout: file tree (fixed) + editor (flex 2x) + properties (flex 1x)
split.multi("ide", {
    { width = 200, minWidth = 150, maxWidth = 350, content = drawFileTree },
    { flex = 2, content = drawEditor },
    { flex = 1, minWidth = 180, content = drawProperties },
})
```

### Edge Toggle Panels

The first and/or last panel in a `multi()` call can be a **toggle panel** — a collapsible sidebar that slides in/out with a clickable bar. Set `toggle = true` on the panel definition.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| toggle | boolean | false | Makes this panel a collapsible edge toggle |
| content | function | — | Renders panel content |
| size | number\|string | — | Expanded size (pixels or percentage) |
| defaultOpen | boolean | true | Initial open state |
| speed | number | 6.0 | Animation speed multiplier |
| barWidth | number | ItemSpacing.x | Toggle bar thickness |

Toggle panels can only be placed at the edges (first or last panel). Core panels between them remain draggable as normal.

```lua
-- Sidebar that collapses + main content + inspector that collapses
split.multi("app", {
    { toggle = true, size = 220, content = drawSidebar },         -- left edge toggle
    { content = drawMainContent },                                 -- core (flex)
    { toggle = true, size = 280, defaultOpen = false, content = drawInspector },  -- right edge toggle
})
```

### `resetMulti(id)`

Reset a multi-splitter to its default breakpoints.

## Toggle Panels

### `toggle(id, panels, opts?)`

Standalone collapsible panel with animated slide in/out. `panels[1]` is the fixed/toggleable panel, `panels[2]` is the flex panel that fills remaining space.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Unique toggle ID |
| panels | table | — | Two-element array: `[1]` = fixed, `[2]` = flex |
| opts.side | string | "left" | `"left"`, `"right"`, `"top"`, or `"bottom"` |
| opts.size | number\|string | 200 | Expanded size (pixels or percentage) |
| opts.defaultOpen | boolean | true | Initial open state |
| opts.speed | number | 6.0 | Animation speed multiplier |
| opts.barWidth | number | ItemSpacing.x | Toggle bar thickness |

**Returns:** `boolean` — current open state

**Alias:** `split.t(...)`

```lua
-- Left toolbar that collapses
local isOpen = split.toggle("tools", {
    { content = drawToolbar },
    { content = drawCanvas },
}, { side = "left", size = 180 })

-- Bottom status bar
split.toggle("status", {
    { content = drawStatusBar },
    { content = drawMainArea },
}, { side = "bottom", size = 30, defaultOpen = true })
```

### Toggle State Functions

#### `setToggle(id, open)`

Programmatically set toggle open/closed state.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Toggle identifier |
| open | boolean | Desired open state |

#### `getToggle(id)`

Query current toggle state.

**Returns:** `boolean|nil` — open state, or nil if not initialized

## Interaction

### Grab Bar

The divider bar shows state through color and cursor:
- **Idle** — transparent background, muted grey icon
- **Hover** — subtle blue background, bright icon, resize cursor
- **Dragging** — green background, white icon, resize cursor

Icon glyphs (requires IconGlyphs): vertical bars `||` for horizontal splits, horizontal bars `==` for vertical splits.

### Double-Click Collapse

Double-clicking a two-panel grab bar collapses the panel:
- If the split is <= 50%, collapses to `minPct`
- If the split is > 50%, collapses to `maxPct`
- Double-clicking again restores the previous position

Collapse uses a smoothstep animation.

### Modifier Keys

| Key | Effect |
|-----|--------|
| Ctrl + drag | Snap divider to 5% increments |
| Shift + drag | Proportionally scale all neighboring panels (multi-splitter only) |

### Context Menu (Multi-Splitter)

Right-clicking a multi-splitter divider opens a context menu:
- **Reset Column/Row** — reset this splitter's breakpoints to defaults
- **Reset All** — reset all multi-splitters to defaults

## Examples

### Sidebar + Content

```lua
split.horizontal("sidebar", function()
    for i, item in ipairs(menuItems) do
        if ImGui.Selectable(item.label, selected == i) then
            selected = i
        end
    end
end, function()
    menuItems[selected].draw()
end, { defaultPct = 0.25, minPct = 0.15, maxPct = 0.4 })
```

### 3-Panel IDE Layout

```lua
split.multi("ide", {
    { width = 200, minWidth = 120, content = function()
        ImGui.Text("File Tree")
    end },
    { flex = 2, content = function()
        ImGui.Text("Editor")
    end },
    { flex = 1, minWidth = 150, content = function()
        ImGui.Text("Properties")
    end },
})
```

### Toggle Toolbar + Status Bar

```lua
split.toggle("toolbar", {
    { content = drawToolbar },
    { content = function()
        -- Main content with bottom status bar
        split.toggle("status", {
            { content = drawStatusBar },
            { content = drawMainContent },
        }, { side = "bottom", size = 28 })
    end },
}, { side = "left", size = 200 })
```

### Nested Splitters

```lua
-- Vertical outer split with horizontal inner split
split.vertical("outer", function()
    split.horizontal("inner", function()
        ImGui.Text("Top-Left")
    end, function()
        ImGui.Text("Top-Right")
    end)
end, function()
    ImGui.Text("Bottom")
end, { defaultPct = 0.6 })
```

### Edge Toggles with Multi-Panel Core

```lua
split.multi("fullApp", {
    { toggle = true, size = 240, content = drawNavigation },
    { flex = 2, content = drawWorkspace },
    { flex = 1, minWidth = 200, content = drawDetails },
    { toggle = true, size = 300, defaultOpen = false, content = drawHelp },
})
```

## Aliases

| Full Name | Alias |
|-----------|-------|
| `splitter.horizontal(...)` | `splitter.h(...)` |
| `splitter.vertical(...)` | `splitter.v(...)` |
| `splitter.multi(...)` | `splitter.m(...)` |
| `splitter.toggle(...)` | `splitter.t(...)` |
