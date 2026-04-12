# Popout

Detachable panels that can dock inline or float in a separate window. Two visual styles: "panel" (default panel background) and "inline" (no background, blends with parent).

The module never auto-renders toggle buttons. Use `toggleButton()` inside your content callback or anywhere else in your UI to let users dock/undock.

Floating windows for detached popouts are rendered centrally by WindowUtils each frame, not at the call site. This means detached popouts persist even when their `popout()` call is inactive (e.g., the tab was switched away). No special handling is needed by the consumer.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local pop = wu.Popout

-- Panel-style: styled background, placeholder with dock button when detached
pop.popout("my_panel", {
    title = "My Panel",
    style = "panel",
    content = function()
        ImGui.Text("Panel content")
        wu.Controls.ButtonRow({ pop.toggleButton("my_panel") })
    end,
})

-- Inline-style: no background, no auto buttons
pop.popout("my_inline", {
    title = "Transport",
    style = "inline",
    content = function()
        wu.Controls.ButtonRow({ pop.toggleButton("my_inline") })
        ImGui.Text("Inline content")
    end,
})
```

## Functions

### `popout(id, opts)`

Main rendering function. Call once per frame where the docked content should appear. When detached, the floating window is rendered automatically by WindowUtils at the top level (via `drawAll()`), so it persists even if this call site becomes inactive.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | - | Unique popout identifier |
| opts.content | function | nil | Callback that renders the panel content |
| opts.title | string | id | Title text shown centered in the floating window |
| opts.style | string | "panel" | `"panel"` or `"inline"` |
| opts.defaultDocked | boolean | true | Initial dock state on first use |
| opts.size | table | {width=300, height=200} | Floating window size `{width, height}` in pixels |
| opts.widthPercent | number | nil | Width as display percentage (overrides size.width, also sets min width) |
| opts.fitHeight | boolean | false | Auto-size height to content, snapped to next grid cell |
| opts.minSize | table\|nil | nil | Minimum floating window size `{width, height}` |
| opts.maxSize | table\|nil | nil | Maximum floating window size `{width, height}` |
| opts.flags | number\|nil | nil | Extra ImGui window flags for the floating window |
| opts.icon | string\|nil | nil | Glyph for the placeholder dock button (panel style only) |
| opts.bg | table\|false\|nil | nil | Background: nil = style default, false = none, table = custom RGBA |
| opts.placeholder | function\|nil | nil | Content rendered in the placeholder when detached |
| opts.hideWhenDetached | boolean | false | Skip placeholder entirely when detached |
| opts.showTitle | boolean | true | Show centered title in the floating window |
| opts.sideHandle | boolean | false | Show vertical grab handle on the left side of the floating window |

**Returns:** `boolean` - current docked state (`true` = docked, `false` = detached)

**Background behavior:**
- `"panel"` style: default panel background in docked, placeholder, and floating states
- `"inline"` style: no background in any state
- `bg = false` disables background on any style; `bg = {r, g, b, a}` enables a custom one

**Placeholder behavior when detached:**
- `"panel"` style: styled panel with a dock button and optional `placeholder` callback (SameLine)
- `"inline"` style: only `placeholder` callback if provided, no auto button
- `hideWhenDetached = true`: skips placeholder entirely

**fitHeight behavior:**
- Auto-sizes the floating window height to content, ceiled to the next grid cell boundary
- Width is user-resizable (drag to resize); `widthPercent` sets the initial and minimum width
- Uses a two-phase approach: measures content for 1-2 frames, then locks the Panel to fill the grid-ceiled window height
- Re-measures automatically if the user resizes width (content may reflow)

### `toggle(id)`

Flip the dock state. No-op if ID hasn't been rendered yet.

### `drawAll()`

Renders floating windows for all detached popouts. Called automatically by WindowUtils once per frame at the top level. Consumers do not need to call this.

### `setDocked(id, docked)`

Set the dock state programmatically.

### `isDocked(id)`

Query the current dock state. Returns `true` if ID not found (safe default).

### `getIcon(id)`

Returns `IconGlyphs.OpenInNew` when docked, `IconGlyphs.DockWindow` when detached.

### `toggleButton(id, opts?)`

Returns a `controls.ButtonRow`-compatible button definition wired to `toggle(id)`. Icon and tooltip update automatically based on current state.

**Returns:** `table` - `{ type = "button", icon, tooltip, onClick }`

### `destroy(id)`

Remove internal state for a popout ID. Call when dynamically created popouts are no longer needed.

## Examples

### Panel with Placeholder

```lua
pop.popout("settings", {
    title = "Settings",
    style = "panel",
    content = function()
        ImGui.Text("Settings content")
        controls.ButtonRow({ pop.toggleButton("settings") })
    end,
    placeholder = function()
        controls.TextMuted("Settings panel is floating.")
    end,
})
```

### Hidden When Detached

```lua
pop.popout("tools", {
    title = "Tools",
    style = "panel",
    hideWhenDetached = true,
    content = function()
        ImGui.Text("Tool content")
        controls.ButtonRow({ pop.toggleButton("tools") })
    end,
})
```

### Fit Height with Display Width Percent

Auto-sizes height to content (grid-snapped). Width starts at 25% of display and is user-resizable (25% is also the minimum).

```lua
pop.popout("compact", {
    title = "Compact Panel",
    style = "panel",
    widthPercent = 25,
    fitHeight = true,
    content = function()
        ImGui.Text("Height fits content, snapped to grid.")
        controls.ButtonRow({ pop.toggleButton("compact") })
    end,
})
```

### Size Constraints

```lua
pop.popout("constrained", {
    title = "Constrained",
    style = "panel",
    size = { width = 300, height = 200 },
    minSize = { width = 200, height = 150 },
    maxSize = { width = 500, height = 400 },
    content = function()
        ImGui.Text("Resizable within constraints")
        controls.ButtonRow({ pop.toggleButton("constrained") })
    end,
})
```

### Inline Style

```lua
pop.popout("transport", {
    title = "Transport",
    style = "inline",
    content = function()
        controls.ButtonRow({ pop.toggleButton("transport") })
        ImGui.Text("Transport controls")
    end,
})
```

### Inline with Custom Background

```lua
pop.popout("transport", {
    title = "Transport",
    style = "inline",
    bg = { 0.65, 0.7, 1.0, 0.045 },
    content = function()
        controls.ButtonRow({ pop.toggleButton("transport") })
        ImGui.Text("Transport controls with background")
    end,
})
```

### Panel Without Background

```lua
pop.popout("raw", {
    title = "Raw Panel",
    style = "panel",
    bg = false,
    content = function()
        ImGui.Text("No background")
        controls.ButtonRow({ pop.toggleButton("raw") })
    end,
})
```

### Toggle from Anywhere

```lua
-- Button in a toolbar that controls a popout defined elsewhere
controls.ButtonRow({
    pop.toggleButton("detail_panel"),
    { label = "  Save  ", style = "active", onClick = save },
})

-- The popout itself, rendered in a different part of the layout
pop.popout("detail_panel", {
    title = "Details",
    style = "panel",
    content = function()
        ImGui.Text("Detail content")
    end,
})
```

### Integration with Splitter

```lua
split.toggle("sidebar", {
    { content = function()
        pop.popout("props", {
            title = "Properties",
            style = "panel",
            content = function()
                ImGui.Text("Property editor")
                controls.ButtonRow({ pop.toggleButton("props") })
            end,
        })
    end },
    { content = drawMain },
}, { side = "right", size = 280 })
```

### Programmatic Control

```lua
pop.setDocked("my_panel", false)

if pop.isDocked("my_panel") then
    ImGui.Text("Panel is docked")
end

if wu.Controls.Button("  Toggle  ") then
    pop.toggle("my_panel")
end
```

### Titleless Floating Window

```lua
pop.popout("compact", {
    title = "Compact",
    style = "panel",
    showTitle = false,
    content = function()
        ImGui.Text("No title, content starts immediately.")
        controls.ButtonRow({ pop.toggleButton("compact") })
    end,
})
```

### Side Handle

Vertical grip bar on the left, content in a child window to the right.

```lua
pop.popout("tools", {
    title = "Tools",
    style = "panel",
    sideHandle = true,
    content = function()
        ImGui.Text("Drag the handle to move.")
        controls.ButtonRow({ pop.toggleButton("tools") })
    end,
})
```

### Side Handle + No Title

Compact floating panel with just a grip and content.

```lua
pop.popout("transport", {
    title = "Transport",
    style = "panel",
    sideHandle = true,
    showTitle = false,
    content = function()
        controls.ButtonRow({ pop.toggleButton("transport") })
        ImGui.Text("Minimal floating panel.")
    end,
})
```
