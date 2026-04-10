# WindowUtils - Developer Documentation

A universal library for ImGui window management in Cyber Engine Tweaks mods. Provides grid snapping, smooth animations, styled UI controls, tooltips, and collapse-safe window sizing.




## Quick Start

```lua
local wu = GetMod("WindowUtils")
```

`Update()` must be called between `ImGui.Begin()` and `ImGui.End()` so it can query window state. It must run every frame  - including when the window is collapsed  - so that collapsed windows still snap to the grid.

**Critical: `Update()` must be called AFTER your content, just before `ImGui.End()`.** During shift+drag axis locking, `Update()` calls `SetWindowPos` internally. If called before content, this changes the window position without updating ImGui's internal layout cursor (set during `Begin`), causing content to render at the old position while the window frame draws at the new one. Calling `Update()` after content avoids this entirely  - content is already rendered, and the position change takes effect on the next frame's `Begin`.

### Option A: Early Return (recommended)

Minimal changes to the standard `if ImGui.Begin() then` pattern. Add a collapsed guard at the top, keep your content code flat:

```lua
if not ImGui.Begin("My Window") then
    -- Window is collapsed  - still update for grid snapping
    if wu then wu.Update("My Window") end
    ImGui.End()
    return
end

-- Your UI code here (no extra nesting)...

if wu then wu.Update("My Window") end
ImGui.End()
```

Trade-off: `Update()` appears twice, but retrofitting an existing mod is just 4 added lines at the top.

### Option B: Single Call

One `Update()` call, but content gets an extra indent level:

```lua
ImGui.Begin("My Window")

if not ImGui.IsWindowCollapsed() then
    -- Your UI code here...
end

if wu then wu.Update("My Window") end
ImGui.End()
```

### AlwaysAutoResize Windows

If your window uses `ImGuiWindowFlags.AlwaysAutoResize`, you **must** use Option A (early return). With Option B, the collapsed path still executes `Begin`/`End` with no content widgets between them  - `AlwaysAutoResize` sees an empty content area and can shrink its internal size target to minimum. On expand, the window starts at that minimum instead of sizing to content.

Note: `AlwaysAutoResize` overrides `ImGui.SetWindowSize()` calls, so WindowUtils cannot grid-snap window **size**  - only **position** snapping works. If you need grid-aligned sizing, remove `AlwaysAutoResize` and let WindowUtils manage the window size.




## Grid Snapping

### Update Options

Override settings per-call:

```lua
wu.Update("My Window", {
    gridEnabled = true,           -- override grid on/off
    animationEnabled = true,      -- override animation on/off
    animationDuration = 0.3,      -- override animation speed (seconds)
    treatAllDragsAsWindowDrag = false  -- treat all drags as window drags
})
```

### Manual Grid Functions

```lua
-- Snap any value to nearest grid point
local snapped = wu.SnapToGrid(posX, "My Window")

-- Align to grid boundaries
local alignedMin = wu.GridAlignMin(value, "My Window")  -- round down
local alignedMax = wu.GridAlignMax(value, "My Window")  -- round up
```




## Size Constraints

Constrain window size to grid-aligned boundaries:

```lua
-- Pixel-based constraints
wu.SetNextWindowSizeConstraints(200, 100, 800, 600, "My Window")

-- Percentage-based (% of display resolution)
wu.SetNextWindowSizeConstraintsPercent(10, 10, 50, 50, "My Window")
```

Call before `ImGui.Begin()`. Values are automatically grid-aligned.

### Constraint Animations

Smoothly animate between constraint states (e.g., expanding/collapsing a panel):

```lua
-- Start animation to a target value
wu.StartConstraintAnimation("My Window", "maxWidth", 800, {
    duration = 0.3,
    easing = "easeOut",
    initialValue = 400
})

-- Each frame, get the interpolated value
local currentMax = wu.UpdateConstraintAnimation("maxWidth", 400, 800, isExpanded)

-- Check animation state
if wu.IsConstraintAnimating("maxWidth") then ... end
if wu.IsAnyConstraintAnimating() then ... end
```




## Collapsed Window Sizing

WindowUtils automatically tracks each window's expanded size and restores it when the window is un-collapsed. This prevents the common ImGui problem where collapsing and expanding a window resets its size when managing through Window Utils.

```lua
-- Query the remembered expanded size (even while collapsed)
local w, h = wu.GetExpandedSize("My Window")

-- Collapsed windows can still snap to grid (enabled by default)
-- Disable per-window if needed:
wu.SetWindowConfig("My Window", { snapCollapsed = false })
```

The `snapCollapsed` setting (default: `true`) controls whether collapsed windows snap when dragged. When enabled, grid snapping uses the remembered expanded size for alignment  - so the window lands on a correct grid position for when it's expanded again, not based on the narrow collapsed title bar width.

`Update()` handles all of this automatically  - no extra code needed beyond the standard call.




## Animations

### Easing Functions

Available easing functions: `linear`, `easeIn`, `easeOut`, `easeInOut`, `bounce`

```lua
-- Apply easing to a 0-1 value (uses window's configured easing function)
local eased = wu.ApplyEasing(t, "My Window")

-- Linear interpolation
local value = wu.Lerp(startVal, endVal, t)
```

### Animation State

```lua
if wu.IsAnimating("My Window") then
    -- Window is mid-snap animation
end

wu.CompleteAnimation("My Window")  -- skip to end
wu.ResetWindow("My Window")       -- clear all tracking data
wu.InvalidateGridCache()           -- clear cached grid sizes (e.g. after changing gridUnits)
wu.InvalidateGridCache("My Window") -- clear for a specific window only
```




## UI Controls

Pre-styled ImGui controls with built-in tooltip support, right-click reset, and a 12-column grid layout system. Most controls accept an `opts` table for optional parameters.

```lua
local c = wu.Controls
```

### Layout

```lua
local width = c.ColWidth(6)              -- half width (6 of 12 columns)
local width = c.ColWidth(4, 8, true)     -- 4 cols, 8px gap, after icon
local width = c.RemainingWidth()         -- fill remaining space
```

### Sliders

```lua
local val, changed = c.SliderFloat(IconGlyphs.Reload, "brightness", value, 0.1, 10.0, {
    format = "%.1f", cols = 8, default = 1.0, tooltip = "Brightness"
})

local val, changed = c.SliderInt(IconGlyphs.Grid3x3, "gridSize", value, 1, 10, {
    default = 2, tooltip = "Grid size"
})
```

### Checkboxes

```lua
local val, changed = c.Checkbox("Show Grid", settings.gridEnabled, {
    icon = IconGlyphs.Grid, default = true, tooltip = "Toggle grid overlay"
})
```

### Combo/Dropdown

```lua
local idx, changed = c.Combo(IconGlyphs.ChevronDown, "easing", currentIndex,
    {"Linear", "Ease Out", "Ease In"}, { default = 1, tooltip = "Easing function" })
```

### Buttons

```lua
local clicked = c.Button("Save", "active", width, height)
local clicked = c.ToggleButton("Feature", isEnabled)
local clicked = c.FullWidthButton("Reset All", "danger")
c.DisabledButton("Unavailable")
-- Styles: "active", "inactive", "danger", "warning", "update", "disabled", "transparent"
```

### Color Picker

```lua
local color, changed = c.ColorEdit4(IconGlyphs.Palette, "gridColor",
    {0.25, 0.95, 0.98, 0.8}, { default = {0.25, 0.95, 0.98, 0.8}, tooltip = "Grid color" })
```

### Input Fields

```lua
local text, changed = c.InputText(icon, "id", currentText, { cols = 8, tooltip = "Name" })
local val, changed  = c.InputFloat(icon, "id", currentValue, { step = 0.1, format = "%.2f" })
local val, changed  = c.InputInt(icon, "id", currentValue, { step = 1, cols = 6 })
```

### Text and Layout

```lua
c.TextMuted("Greyed out info")
c.TextSuccess("Connected!")
c.TextDanger("Error occurred")
c.TextWarning("Experimental feature")

c.Separator(4, 4)                -- spacing before/after
c.SectionHeader("Section", 8, 4) -- labeled separator
```

The Controls module also provides drag controls, hold-to-confirm buttons, swatch grids, bound controls, and more. See [`docs/controls.md`](docs/controls.md) for the full reference.




## Tooltips

Tooltip helpers that handle `IsItemHovered()` checks internally. Call after any ImGui widget.

```lua
local tips = wu.Tooltips
```

### Basic

```lua
ImGui.Button("Click Me")
tips.Show("Description")         -- respects global tooltipsEnabled setting
tips.ShowAlways("Always visible") -- ignores tooltipsEnabled
tips.ShowWrapped("Long text...", 300)  -- word-wrapped, max 300px
```

### Styled

```lua
tips.ShowTitled("Feature Name", "Detailed explanation below")
tips.ShowWithHint("Volume: 50%", "Right-click to reset")
tips.ShowKeybind("Toggle Grid", "Ctrl+G")
tips.ShowHelp("This feature does...")  -- blue [?] prefix
```

### Colored

```lua
tips.ShowSuccess("Connected!")
tips.ShowDanger("Will delete data")
tips.ShowWarning("Experimental")
tips.ShowMuted("Less important info")
tips.ShowColored("Custom", 0.5, 0.7, 1.0, 1.0)  -- RGBA
```

### Multi-line

```lua
tips.ShowLines({"Line 1", "Line 2", "Line 3"})
tips.ShowBullets("Options:", {"First", "Second", "Third"})
```

### Conditional

```lua
tips.ShowIf("Only when true", someCondition)
```




## Styles

Low-level style Push/Pop functions for custom ImGui styling.

```lua
local styles = wu.Styles
```

### Color Presets

Access the color palette directly:

```lua
styles.colors.green       -- {0.0, 1.0, 0.7, 1.0}
styles.colors.blue        -- {0.14, 0.27, 0.43, 1.0}
styles.colors.red         -- {1.0, 0.3, 0.3, 1.0}
styles.colors.yellow      -- {1.0, 0.8, 0.0, 0.8}
styles.colors.orange      -- {1.0, 0.6, 0.0, 1.0}
styles.colors.grey        -- {0.3, 0.3, 0.3, 1.0}
styles.colors.transparent -- {0.0, 0.0, 0.0, 0.0}
```

Each color family includes `hover` and `active` variants (e.g., `greenHover`, `greenActive`).

### Button Styles

```lua
-- By name (preferred)
styles.PushButton("active")   -- green with black text
ImGui.Button("Go")
styles.PopButton("active")

-- Available names: "active", "inactive", "danger", "warning", "update",
--   "disabled", "statusbar", "label", "labelOutlined", "transparent", "frameless"
```

Each named style also has a direct Push/Pop pair (e.g., `PushButtonDanger()` / `PopButtonDanger()`). See [`docs/styles.md`](docs/styles.md) for the full API reference including outlined styles, text styles, drag theming, and scrollbar styling.




## Settings API

Control WindowUtils settings programmatically from another mod:

```lua
local api = wu.API
```

### Reading Settings

```lua
local s = api.Get()            -- mutable reference to the master settings table
print(s.gridEnabled)           -- read any setting directly

local defaults = api.GetDefaults()  -- read-only defaults table
print(defaults.gridUnits)           -- inspect default values
```

`api.Get()` returns the live settings table. Changes to it take effect immediately, but call `api.Save()` to persist them to disk.

`api.GetDefaults()` returns a frozen table (writes will error). Use it to compare current values against defaults or to supply reset values.

### Changing Settings

```lua
-- Apply one or more settings at once (validates, persists, triggers side effects)
api.Set({
    gridEnabled = true,
    animationDuration = 0.15,
    tooltipsEnabled = false
})
```

`api.Set(table)` validates each key, writes valid ones to the master table, saves to disk, and handles side effects (e.g., invalidating the grid cache when `gridUnits` changes). Returns `true` if any setting was applied. Invalid keys or values are skipped with a debug message.

For direct writes to the master table, persist manually:

```lua
local s = api.Get()
s.blurOnOverlayOpen = true
api.Save()                     -- persist to disk
```

### Reset and Reload

```lua
api.Reset()                    -- restore all settings to defaults and save
api.Reload()                   -- reload settings from disk (discards in-memory changes)
```

Both functions also invalidate the grid cache so the overlay updates immediately.

### Settings Window

```lua
api.Toggle()                   -- toggle the settings window open/closed
api.Show()                     -- open the settings window
api.Hide()                     -- close the settings window

if api.IsVisible() then
    -- settings window is currently open
end
```

### Window Registration

Register windows with metadata so WindowUtils can manage them correctly during external window management. Windows with a close button (pOpen) bypass the empty-shell probe state machine.

```lua
api.RegisterWindow("My Window###mywin", { hasCloseButton = true })
api.UnregisterWindow("My Window###mywin")
```

The window name supports ImGui's `###` stable ID syntax.

### Console Helper

```lua
api.Info()
```

Prints all settings keys with current values, defaults, and types to the CET console. Also shows quick-reference examples for `api.Get()` and `api.Set()`.

### External Settings Integration

Let WindowUtils read settings from your mod's own settings object:

```lua
wu.Configure(mySettingsObject)
-- WindowUtils will read from mySettingsObject.Current[key] using KEY_MAP:
--   gridUnits        -> "windowGridUnits"
--   gridEnabled      -> "windowGridEnabled"
--   animationEnabled -> "windowAnimationEnabled"
--   animationDuration-> "windowAnimationDuration"
--   easeFunction     -> "windowInterpolation"
--   tooltipsEnabled  -> "tooltipsEnabled"
```




## Per-Window Configuration

Override settings for specific windows:

```lua
wu.SetWindowConfig("Debug Window", {
    gridEnabled = false,
    animationDuration = 0.1
})

-- Clear overrides
wu.ClearWindowConfig("Debug Window")

-- Query effective value (respects priority chain)
local gridOn = wu.GetConfig("Debug Window", "gridEnabled")
```

**Priority chain:** Master override (if enabled) > Per-window config > External settings > Global defaults

### Global Defaults

Change defaults for all windows that don't have overrides:

```lua
wu.SetGlobalDefaults({
    gridUnits = 3,
    animationDuration = 0.15
})
```




## Settings Reference

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `gridUnits` | number | 2 | Grid size multiplier (units * 20px) |
| `gridEnabled` | boolean | true | Enable grid snapping |
| `snapCollapsed` | boolean | true | Snap collapsed windows when dragged |
| `gridVisualizationEnabled` | boolean | true | Show grid overlay |
| `gridLineThickness` | number | 3.0 | Grid line thickness in pixels |
| `gridLineColor` | table | {0.25, 0.95, 0.98, 0.8} | Grid line RGBA color |
| `gridShowOnDragOnly` | boolean | true | Only show grid while dragging |
| `animationEnabled` | boolean | true | Enable snap animations |
| `animationDuration` | number | 0.2 | Animation duration in seconds |
| `easeFunction` | string | "easeOut" | Easing function name |
| `tooltipsEnabled` | boolean | true | Show tooltips |
| `tooltipMaxWidthPct` | number | 15 | Maximum tooltip width as percentage of display width |
| `debugOutput` | boolean | false | Print debug messages to console |
| `overrideAllWindows` | boolean | false | Apply to all CET windows |
| `overrideStyling` | boolean | false | Apply WindowUtils styling to overridden windows |
| `showGuiWindow` | boolean | true | Show the WindowUtils GUI window |
| `windowBrowserOpen` | boolean | false | Window Browser panel is open |
| `gridFeatherEnabled` | boolean | true | Enable grid feathering |
| `gridFeatherRadius` | number | 400 | Feather radius in pixels |
| `gridFeatherPadding` | number | 0 | Feather padding in pixels |
| `gridFeatherCurve` | number | 5.0 | Feather curve exponent |
| `gridGuidesEnabled` | boolean | false | Show alignment guides at window edges |
| `gridGuidesDimming` | number | 0.2 | Grid opacity when guides active (0-1) |
| `gridDimBackground` | boolean | true | Dim background behind grid |
| `gridDimBackgroundOnDragOnly` | boolean | true | Only dim while dragging |
| `gridDimBackgroundOpacity` | number | 0.2 | Background dim opacity (0-1) |
| `blurOnOverlayOpen` | boolean | false | Blur background on CET overlay |
| `blurOnDragOnly` | boolean | true | Only blur while dragging |
| `blurIntensity` | number | 0.0028 | Blur intensity (0.0-0.02) |
| `fadeInDuration` | number | 0.25 | Overlay fade-in duration in seconds |
| `fadeOutDuration` | number | 0.05 | Overlay fade-out duration in seconds |
| `quickExit` | boolean | true | Skip fade-out when closing the overlay |
| `probeInterval` | number | 0.5 | Seconds between window re-probes |
| `autoRemoveEmptyWindows` | boolean | true | Auto-remove empty window shells |
| `autoRemoveInterval` | number | 0.5 | Seconds between auto-remove checks |
| `batchAutoRemove` | boolean | true | Check all windows at once vs round-robin |
| `autoAdjustOnResize` | boolean | false | Re-snap windows when display resolution changes |
| `disableScrollbar` | boolean | false | Hide scrollbars in the settings window |
| `showExperimental` | boolean | false | Show experimental features in settings |
| `experimentalDisclaimerShown` | boolean | false | Experimental disclaimer has been acknowledged |




## Right-Click Reset

All Controls module widgets (`Checkbox`, `SliderFloat`, `SliderInt`, `Combo`, `ColorEdit4`) support right-click to reset to a default value. Pass the default in the opts table:

```lua
local value, changed = c.SliderFloat(icon, "id", currentValue, 0, 100, {
    default = 50,  -- right-click resets to 50
    tooltip = "Volume"
})
```

If the user right-clicks the control, `changed` returns `true` and `value` returns the default.




## Module Reference

Detailed per-module documentation lives in the `docs/` directory. Each file covers the full API, usage patterns, and examples for that module.

| Module | Description |
|--------|-------------|
| [controls](docs/controls.md) | Grid-based layout, styled buttons, sliders, inputs, hold-to-confirm buttons, bound controls, and layout helpers |
| [dragdrop](docs/dragdrop.md) | Drag-and-drop reordering for ImGui lists with visual feedback and drop indicators |
| [expand](docs/expand.md) | Automatic window resizing for toggle panels with sizing modes, drag-to-resize, and position anchoring |
| [lists](docs/lists.md) | Scrollable list rendering with per-item callbacks, active-index tracking, clipper optimization, and drag-drop reorder |
| [modal](docs/modal.md) | Centered modal popups with percent-based sizing, button configuration, and hold-to-confirm |
| [notifications](docs/notifications.md) | Screen-edge toast notifications with level-based styling, auto-dismiss, and fade-out |
| [popout](docs/popout.md) | Detachable panels that can dock inline or float in a separate window |
| [search](docs/search.md) | Search and filter system that dims non-matching controls when a query is active |
| [splitter](docs/splitter.md) | Draggable dividers for two-panel, multi-panel, and collapsible toggle layouts |
| [styles](docs/styles.md) | Push/pop style helpers for consistent ImGui theming |
| [tabs](docs/tabs.md) | Styled tab bars with badge indicators, disabled tabs, and programmatic selection |
| [tooltips](docs/tooltips.md) | Hover tooltips with styling variants, keybind hints, and multi-line support |
| [utils](docs/utils.md) | Low-level helper functions used across WindowUtils modules |




## FAQ

### Why does my GUI content float separately from the window frame during Shift+drag?

`Update()` is being called **before** your content widgets. During Shift+drag axis locking, `Update()` internally calls `ImGui.SetWindowPos()` to constrain movement to one axis. If this runs before your widgets are rendered, ImGui's internal layout cursor (`DC.CursorStartPos`  - set once during `Begin()`) still points to the old window position. Your content renders at that stale position while the window frame draws at the new one, creating a visual split.

**Fix:** Move `Update()` to after all content, just before `ImGui.End()`. Content is already rendered at the correct position, and the `SetWindowPos` takes effect on the next frame's `Begin()`. See the [Quick Start](#quick-start) examples.

### Why does my AlwaysAutoResize window start at minimum size after collapsing and expanding?

You're likely using Option B (`IsWindowCollapsed()` guard) with `AlwaysAutoResize`. When collapsed, `Begin()`/`End()` executes with no content widgets between them  - `AlwaysAutoResize` sees an empty content area and shrinks its internal size target to the minimum. On expand, the window starts at that minimum size instead of fitting your content.

**Fix:** Use Option A (early return). The `return` after the collapsed path prevents `AlwaysAutoResize` from ever processing a frame with no content. See the [AlwaysAutoResize Windows](#alwaysautoresize-windows) section.

### Why doesn't WindowUtils grid-snap my window's size?

Your window likely uses `ImGuiWindowFlags.AlwaysAutoResize`. This flag causes ImGui to override all `SetWindowSize()` calls every frame  - including the ones WindowUtils uses for size snapping. Only **position** snapping works with `AlwaysAutoResize`.

**Fix:** If you need grid-aligned sizing, remove `AlwaysAutoResize` and set an initial size with `ImGui.SetNextWindowSize()`. WindowUtils will then manage both position and size snapping.

### Why does Update() need to run every frame, even when collapsed?

When a window is collapsed, WindowUtils still needs to track its position for grid snapping on drag. If `Update()` is skipped while collapsed, dragging a collapsed window won't snap to the grid, and the expanded size cache won't be available for correct size restoration on expand.
