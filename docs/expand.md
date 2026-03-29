# Expand  - WindowUtils Window Expansion

Automatic window resizing for toggle panels. When a panel opens, the window grows to accommodate it; when it closes, the window shrinks back. Supports three sizing modes, drag-to-resize, constraint animation, and position anchoring.

## Architecture

Expand uses a two-level design:

1. **Content level**  - `splitter.toggle()` with `expand = true` calls `expand.init()`, `expand.cacheBase()`, and `expand.afterRender()` internally. These run inside child windows and only store state (never call `SetWindowSize`/`SetWindowPos`).

2. **Window level**  - `expand.applyWindowSize(windowName)` must be called at the main window scope (inside `Begin()`/`End()`, outside any children) where `GetWindowSize()` returns the actual window dimensions.

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
| windowName | string |  - | ImGui window name (must match `Begin()`) |
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

These functions are exposed on `wu.Expand`. Most are called internally by `splitter.toggle()`  - you only need them for auto mode or programmatic control.

### Content-Level Functions

These run inside child windows and only store state. Called internally by `splitter.toggle()`.

#### `init(id, opts)`

Register or update an expand panel configuration. Idempotent  - safe to call every frame. On first call, creates the panel state; on subsequent calls, updates mutable fields.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier (same id used with `splitter.toggle`) |
| opts | table | Configuration table (see below) |

**opts fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| windowName | string |  - | ImGui window name (must match `Begin()`) |
| side | string | "right" | `"left"`, `"right"`, `"top"`, `"bottom"` |
| size | number | 200 | Panel size in pixels |
| sizeMode | string | "fixed" | `"fixed"`, `"flex"`, or `"auto"` |
| normalConstraintPct | number\|nil | nil | Normal max-size constraint as display % |
| expandDuration | number | 0.3 | Constraint animation duration (seconds) |
| expandEasing | string | "easeOut" | Constraint animation easing function |

#### `onToggle(id, isOpen)`

Signal a toggle event. Marks the panel as unsettled and triggers constraint animation via `core.startConstraintAnimation()` when `normalConstraintPct` is configured.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| isOpen | boolean | New open state (after the toggle) |

#### `cacheBase(id, totalAvail, panelSize)`

Cache the content-region available space. Only updates `baseAvail` when the panel has been closed for 2+ frames, ensuring `SetWindowSize` lag has resolved.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| totalAvail | number | Current content region available (from `GetContentRegionAvail`) |
| panelSize | number | Current animated panel size (0 when closed) |

#### `getBaseAvail(id)`

Get the cached base content-region available space. This is the "naked" content width/height before any expand panels are added.

**Returns:** `number|nil`

#### `getTargetSize(id)`

Get the effective panel target size. Returns `measuredSize` for auto mode, `dragSize` for flex mode (after drag), or `panelSizePx` as fallback.

**Returns:** `number|nil`

#### `setMeasuredSize(id, size)`

Report measured content size for auto mode. Call this inside the panel's content callback after rendering.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| size | number | Measured content extent in pixels |

#### `applyDrag(id, delta, dirMul)`

Apply drag delta to an expand panel. In fixed mode, adjusts the window via `dragOffset`. In flex mode, adjusts the panel size via `dragSize`.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| delta | number | Cumulative drag delta in pixels (from `GetMouseDragDelta`) |
| dirMul | number | Direction multiplier: `+1` for right/bottom, `-1` for left/top |

#### `commitDrag(id)`

Finalize drag state. In fixed mode, commits the drag offset to the window base dimensions. In flex mode, clears the drag start reference and lets the ratio reconciliation phase handle it.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |

#### `afterRender(id, panelSize, isAnimating, isDragging)`

Store per-frame panel state for `applyWindowSize()` to consume. Called after the panel content has been rendered.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| panelSize | number | Current animated panel size |
| isAnimating | boolean | Whether the splitter animation is in progress |
| isDragging | boolean | Whether the user is currently dragging the expand bar |

### Window-Level Functions

Must be called at main window scope (inside `Begin()`/`End()`, outside any children).

#### `applyWindowSize(windowName)`

Drive window resizing for all expand panels on a window. **Must be called at window scope** (inside `Begin()`/`End()`, outside any child windows).

Internally runs a 7-phase pipeline each frame:
1. Collect panels and sum contributions per axis
2. Capture base window size (on first open)
3. Apply fixed-mode drag offsets
4. Determine if any panel needs a resize
5. Single `SetWindowSize()` call
6. Manual resize detection and ratio maintenance
7. Position anchoring for left/top panels

### Constraint and Control Functions

#### `getConstraint(id, isOpen)`

Get the animated constraint value for pre-`Begin()` setup. Returns the current animated constraint percentage, or nil if the panel hasn't been initialized, `normalConstraintPct` wasn't configured, or the user is currently dragging.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Panel identifier |
| isOpen | boolean | Current open state |

**Returns:** `number|nil`  - animated constraint % for `SetNextWindowSizeConstraintsPercent`

#### `setOpen(id, isOpen)`

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

Drag offsets persist across toggle cycles  - closing and reopening the panel keeps any size adjustment.

### Position Anchoring

For `left` and `top` side panels, the window's right/bottom edge stays anchored during animation and drag. This prevents the content area from visually jumping.

## Examples

### Fixed Mode  - Settings Sidebar

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

### Flex Mode  - Resizable Inspector

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

### Auto Mode  - Dynamic Content Panel

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
-- Left sidebar + bottom details  - both expand the same window
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
