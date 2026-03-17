# Expand — WindowUtils Window Expansion

Automatic window resizing for toggle panels. When a panel opens, the window grows to accommodate it; when it closes, the window shrinks back. Supports three sizing modes, drag-to-resize, constraint animation, and position anchoring.

## Architecture

Expand uses a two-level design:

1. **Content level** — `splitter.toggle()` with `expand = true` calls `expand.init()`, `expand.cacheBase()`, and `expand.afterRender()` internally. These run inside child windows and only store state (never call `SetWindowSize`/`SetWindowPos`).

2. **Window level** — `expand.applyWindowSize(windowName)` must be called at the main window scope (inside `Begin()`/`End()`, outside any children) where `GetWindowSize()` returns the actual window dimensions.

You typically interact with expand through `splitter.toggle()` opts and one call to `expand.applyWindowSize()`. Direct `expand.*` calls are only needed for auto mode measurement or programmatic control.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local split = wu.Splitter
local expand = wu.Expand

-- Before Begin(): apply animated constraint
local constraint = split.getExpandConstraint("sidebar")
if constraint then
    wu.SetNextWindowSizeConstraintsPercent("MyWindow", {
        maxW = constraint
    })
end

ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
if ImGui.Begin("MyWindow") then
    split.toggle("sidebar", {
        { content = drawSidebar },
        { content = drawMain },
    }, {
        side = "right",
        size = 250,
        expand = true,
        windowName = "MyWindow",
        sizeMode = "fixed",
    })

    -- Window-level call: drives SetWindowSize/SetWindowPos
    expand.applyWindowSize("MyWindow")
end
ImGui.End()
```

## Size Modes

### Fixed (default)

The window grows/shrinks when the panel opens/closes or is dragged. The panel stays at its configured size. Dragging the bar adjusts the window width/height.

```lua
split.toggle("panel", panels, {
    expand = true,
    windowName = "MyWindow",
    sizeMode = "fixed",  -- default
    size = 250,
})
```

**Drag behavior:** Window resizes. Panel size stays constant.

### Flex

The window stays the same size. The panel takes space from the flex (main) panel. Dragging the bar redistributes space between the fixed and flex panels.

```lua
split.toggle("panel", panels, {
    expand = true,
    windowName = "MyWindow",
    sizeMode = "flex",
    size = 250,
})
```

**Drag behavior:** Panel resizes. Window stays constant. Manual window resize maintains the panel/window ratio.

### Auto

The panel size is driven by its content (measured each frame via `expand.setMeasuredSize()`). The window grows/shrinks to fit. Dragging the bar adds/removes extra space around the content.

```lua
split.toggle("panel", panels, {
    expand = true,
    windowName = "MyWindow",
    sizeMode = "auto",
    size = 200,  -- initial size before first measurement
})

-- Inside the panel content callback, measure and report:
local contentHeight = ImGui.GetCursorPosY()
expand.setMeasuredSize("panel", contentHeight)
```

**Drag behavior:** Window resizes (same as fixed). Panel stays at measured content size.

## Toggle Options (expand mode)

These opts are passed to `splitter.toggle()` to enable expand mode:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| expand | boolean | false | Enable expand mode |
| windowName | string | — | ImGui window name (must match `Begin()`) |
| sizeMode | string | "fixed" | `"fixed"`, `"flex"`, or `"auto"` |
| size | number\|string | 200 | Panel size in pixels or percentage |
| side | string | "left" | `"left"`, `"right"`, `"top"`, `"bottom"` |
| normalConstraintPct | number\|nil | nil | Normal max-size constraint as display % |
| expandDuration | number | 0.3 | Constraint animation duration (seconds) |
| expandEasing | string | "easeOut" | Constraint animation easing function |

## Constraint Animation

When `normalConstraintPct` is set, the window's max-size constraint animates smoothly between the normal value and the expanded value on toggle. This prevents the window from jumping to a new size.

```lua
-- Before Begin(): query and apply the animated constraint
local constraint = split.getExpandConstraint("sidebar")
if constraint then
    wu.SetNextWindowSizeConstraintsPercent("MyWindow", {
        maxW = constraint
    })
end
```

### `splitter.getExpandConstraint(id)`

Returns the current animated constraint percentage, or nil if:
- The panel hasn't rendered yet
- `normalConstraintPct` wasn't configured
- The user is currently dragging (constraint is suspended during drag)

## Expand API

These functions are exposed on `wu.Expand`. Most are called internally by `splitter.toggle()` — you only need them for auto mode or programmatic control.

### `applyWindowSize(windowName)`

Drive window resizing for all expand panels on a window. **Must be called at window scope** (inside `Begin()`/`End()`, outside any child windows).

Internally runs a 7-phase pipeline each frame:
1. Collect panels and sum contributions per axis
2. Capture base window size (on first open)
3. Apply fixed-mode drag offsets
4. Determine if any panel needs a resize
5. Single `SetWindowSize()` call
6. Manual resize detection and ratio maintenance
7. Position anchoring for left/top panels

### `setMeasuredSize(id, size)`

Report measured content size for auto mode. Call this inside the panel's content callback after rendering.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| size | number | Measured content extent in pixels |

### `getTargetSize(id)`

Get the effective panel target size. Returns `measuredSize` for auto mode, `dragSize` for flex mode (after drag), or `panelSizePx` as fallback.

**Returns:** `number|nil`

### `getBaseAvail(id)`

Get the cached base content-region available space. This is the "naked" content width/height before any expand panels are added.

**Returns:** `number|nil`

### `setOpen(id, isOpen)`

Programmatically open or close an expand panel. Triggers the same constraint animation as a user toggle.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| isOpen | boolean | Desired state |

## Interaction

### Double-Click Toggle

Double-clicking the toggle bar opens/closes the panel. Works in all three size modes.

### Drag to Resize

Dragging the toggle bar resizes the panel:
- **Fixed/Auto:** Window grows or shrinks. Bar shows resize cursor.
- **Flex:** Panel redistributes space within the window. Bar shows resize cursor.

Drag offsets persist across toggle cycles — closing and reopening the panel keeps any size adjustment.

### Position Anchoring

For `left` and `top` side panels, the window's right/bottom edge stays anchored during animation and drag. This prevents the content area from visually jumping.

## Examples

### Fixed Mode — Settings Sidebar

```lua
local wu = GetMod("WindowUtils")
local split = wu.Splitter
local expand = wu.Expand

-- Pre-Begin constraint
local c = split.getExpandConstraint("settings")
if c then
    wu.SetNextWindowSizeConstraintsPercent("MyMod", { maxW = c })
end

if ImGui.Begin("MyMod") then
    split.toggle("settings", {
        { content = function()
            ImGui.Text("Settings go here")
        end },
        { content = function()
            ImGui.Text("Main content")
        end },
    }, {
        side = "right",
        size = 280,
        expand = true,
        windowName = "MyMod",
        sizeMode = "fixed",
        normalConstraintPct = 25,
        expandDuration = 0.3,
    })

    expand.applyWindowSize("MyMod")
end
ImGui.End()
```

### Flex Mode — Resizable Inspector

```lua
split.toggle("inspector", {
    { content = drawInspector },
    { content = drawViewport },
}, {
    side = "right",
    size = 300,
    expand = true,
    windowName = "Editor",
    sizeMode = "flex",
})

expand.applyWindowSize("Editor")
```

### Auto Mode — Dynamic Content Panel

```lua
split.toggle("details", {
    { content = function()
        -- Render variable-height content
        for _, item in ipairs(items) do
            ImGui.Text(item.name)
        end
        -- Report measured size
        expand.setMeasuredSize("details", ImGui.GetCursorPosY())
    end },
    { content = drawMain },
}, {
    side = "bottom",
    size = 100,  -- initial estimate
    expand = true,
    windowName = "MyApp",
    sizeMode = "auto",
})

expand.applyWindowSize("MyApp")
```

### Multiple Expand Panels on One Window

```lua
-- Left sidebar + bottom details — both expand the same window
split.toggle("sidebar", {
    { content = drawSidebar },
    { content = function()
        split.toggle("details", {
            { content = drawDetails },
            { content = drawMain },
        }, {
            side = "bottom",
            size = 150,
            expand = true,
            windowName = "App",
            sizeMode = "fixed",
        })
    end },
}, {
    side = "left",
    size = 220,
    expand = true,
    windowName = "App",
    sizeMode = "fixed",
})

-- Single call handles both panels
expand.applyWindowSize("App")
```

### Vertical Expand

```lua
split.toggle("bottomPanel", {
    { content = drawConsole },
    { content = drawEditor },
}, {
    side = "bottom",
    size = 200,
    expand = true,
    windowName = "IDE",
    sizeMode = "fixed",
})

expand.applyWindowSize("IDE")
```
