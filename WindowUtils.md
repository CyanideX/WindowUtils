# WindowUtils - Developer Documentation

A universal library for ImGui window management in Cyber Engine Tweaks mods. Provides grid snapping, smooth animations, styled UI controls, tooltips, and collapse-safe window sizing.




## Quick Start

```lua
local wu = GetMod("WindowUtils")
```

`Update()` must be called between `ImGui.Begin()` and `ImGui.End()` so it can query window state. It must run every frame — including when the window is collapsed — so that collapsed windows still snap to the grid. There are two ways to structure this:

### Option A: Early Return (recommended for existing mods)

Minimal changes to the standard `if ImGui.Begin() then` pattern. Add a collapsed guard at the top, keep your content code flat:

```lua
if not ImGui.Begin("My Window") then
    -- Window is collapsed — still update for grid snapping
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

One `Update()` call, but requires restructuring `Begin` out of the `if`:

```lua
ImGui.Begin("My Window")
if wu then wu.Update("My Window") end

if not ImGui.IsWindowCollapsed() then
    -- Your UI code here...
end
ImGui.End()
```

Trade-off: no duplication, but content gets an extra indent level.




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

The `snapCollapsed` setting (default: `true`) controls whether collapsed windows snap when dragged. When enabled, grid snapping uses the remembered expanded size for alignment — so the window lands on a correct grid position for when it's expanded again, not based on the narrow collapsed title bar width.

`Update()` handles all of this automatically — no extra code needed beyond the standard call.




## Animations

### Easing Functions

Available easing functions: `linear`, `easeIn`, `easeOut`, `easeInOut`, `bounce`

```lua
-- Apply easing to a 0-1 value
local eased = wu.ApplyEasing(t, "My Window")       -- uses window's configured easing
local eased = wu.ApplyEasingByName(t, "easeOut")    -- use specific easing

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
```




## UI Controls

Pre-styled ImGui controls with built-in tooltip support, right-click reset, and a 12-column grid layout system.

```lua
local controls = wu.Controls
```

### Layout

```lua
-- 12-column grid width calculation
local width = controls.ColWidth(6)              -- half width (6/12)
local width = controls.ColWidth(4, 8, true)     -- 4 cols, 8px gap, after icon
local width = controls.RemainingWidth()         -- fill remaining space
```

### Checkboxes

```lua
local value, changed = controls.Checkbox(
    "Grid Enabled",     -- label
    currentValue,       -- boolean
    defaultValue,       -- right-click resets to this (optional)
    "Enable grid snap"  -- tooltip text (optional)
)

-- With icon prefix
local value, changed = controls.CheckboxWithIcon(
    IconGlyphs.Grid3x3, "Grid", currentValue, defaultValue, "tooltip"
)
```

### Sliders

```lua
-- Float slider with icon
local value, changed = controls.SliderFloat(
    IconGlyphs.Speedometer,  -- icon
    "speed",                 -- unique ID
    currentValue,            -- number
    0.0, 1.0,               -- min, max
    "%.2f",                  -- format (optional)
    nil,                     -- cols (optional, nil = fill width)
    0.5,                     -- default for right-click reset (optional)
    "Movement Speed"         -- tooltip (optional)
)

-- Integer slider
local value, changed = controls.SliderInt(icon, id, value, min, max, "%d", cols, default, tooltip)

-- Disabled slider appearance
controls.SliderDisabled(IconGlyphs.Lock, "Locked")
```

### Buttons

```lua
-- Styled button: "active", "inactive", "danger", "warning", "update", "disabled", "transparent"
local clicked = controls.Button("Save", "active", width, height)

-- Toggle button (auto-switches between active/inactive)
local clicked = controls.ToggleButton("Feature", isEnabled)

-- Full-width button
local clicked = controls.FullWidthButton("Reset All", "danger")

-- Non-clickable disabled button
controls.DisabledButton("Unavailable")
```

### Combo/Dropdown

```lua
local newIndex, changed = controls.Combo(
    IconGlyphs.ChevronDown,  -- icon (optional, nil for no icon)
    "easing",                -- unique ID
    currentIndex,            -- 0-based index
    {"Linear", "Ease Out"},  -- items array
    nil,                     -- cols (optional)
    1,                       -- default index for right-click reset (optional)
    "Easing Function"        -- tooltip (optional)
)
```

### Color Picker

```lua
local color, changed = controls.ColorEdit4(
    IconGlyphs.Palette,          -- icon (optional)
    "gridColor",                 -- unique ID
    {0.25, 0.95, 0.98, 0.8},    -- current RGBA (0-1)
    nil,                         -- label (optional)
    {0.25, 0.95, 0.98, 0.8},    -- default for right-click reset (optional)
    "Grid Line Color"            -- tooltip (optional)
)
```

### Input Fields

```lua
local text, changed = controls.InputText(icon, "id", currentText, 256, cols, "tooltip")
local value, changed = controls.InputFloat(icon, "id", currentValue, 0.1, 1.0, "%.2f", cols, "tooltip")
local value, changed = controls.InputInt(icon, "id", currentValue, 1, 10, cols, "tooltip")
```

### Text Display

```lua
controls.TextMuted("Greyed out info")
controls.TextSuccess("Connected!")
controls.TextDanger("Error occurred")
controls.TextWarning("Experimental feature")
```

### Layout Helpers

```lua
controls.Separator(4, 4)                -- spacing before/after
controls.SectionHeader("Section", 8, 4) -- labeled separator
```




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

-- Available names: "active", "inactive", "danger", "warning", "update", "disabled", "transparent"

-- Padded variants (include frame and item spacing)
styles.PushButtonActivePadded()
-- ...buttons...
styles.PopButtonActivePadded()
```

### Element Styles

```lua
-- Outlined frame (sliders, inputs, progress bars)
styles.PushOutlined()         -- blue border
styles.PushOutlinedDanger()   -- red border
styles.PushOutlinedSuccess()  -- green border

-- Text colors
styles.PushTextMuted()        -- grey
styles.PushTextSuccess()      -- green
styles.PushTextDanger()       -- red
styles.PushTextWarning()      -- yellow

-- Slider/Checkbox
styles.PushSliderDisabled()
styles.PushCheckboxActive()   -- green checkmark
```

All Push functions have a matching Pop function.

### Spacing Defaults

```lua
styles.spacing.framePaddingX  -- 6
styles.spacing.framePaddingY  -- 6
styles.spacing.itemSpacingX   -- 6
styles.spacing.itemSpacingY   -- 8
```




## Settings API

Control WindowUtils settings programmatically from another mod:

```lua
local api = wu.API

-- Master override
api.Enable()                  -- enable master override
api.Disable()
api.IsEnabled()
api.SetEnabled(true)

-- Grid
api.EnableGrid()
api.DisableGrid()
api.ToggleGrid()              -- returns new state
api.IsGridEnabled()
api.SetGridUnits(2)           -- grid multiplier
api.GetGridUnits()

-- Animation
api.EnableAnimation()
api.DisableAnimation()
api.ToggleAnimation()         -- returns new state
api.IsAnimationEnabled()
api.SetAnimationDuration(0.3)
api.GetAnimationDuration()

-- Tooltips
api.EnableTooltips()
api.DisableTooltips()
api.ToggleTooltips()          -- returns new state
api.IsTooltipsEnabled()
api.SetTooltipsEnabled(true)
```

### Direct Settings Access

For settings not exposed as dedicated functions:

```lua
local s = api.GetSettings()   -- mutable reference to master settings
s.blurOnOverlayOpen = true
s.gridDimBackground = true
s.gridDimBackgroundOpacity = 0.3
api.SaveSettings()             -- persist to disk

-- Apply multiple settings at once
api.ApplySettings({
    gridEnabled = true,
    animationDuration = 0.15,
    tooltipsEnabled = false
})

-- Reset / Reload
api.ResetSettings()            -- restore all defaults
api.ReloadSettings()           -- reload from file
```

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
| `debugOutput` | boolean | false | Print debug messages to console |
| `overrideAllWindows` | boolean | false | Apply to all CET windows |
| `gridFeatherEnabled` | boolean | true | Enable grid feathering |
| `gridFeatherRadius` | number | 400 | Feather radius in pixels |
| `gridFeatherPadding` | number | 0 | Feather padding in pixels |
| `gridFeatherCurve` | number | 5.0 | Feather curve exponent |
| `gridGuidesEnabled` | boolean | false | Show alignment guides at window edges |
| `gridGuidesDimming` | number | 0.2 | Grid opacity when guides active (0-1) |
| `gridDimBackground` | boolean | true | Dim background behind grid |
| `gridDimBackgroundOnDragOnly` | boolean | true | Only dim while dragging |
| `gridDimBackgroundOpacity` | number | 0.2 | Background dim opacity (0-1) |
| `showSettingsWindow` | boolean | false | Show settings window on load |
| `blurOnOverlayOpen` | boolean | false | Blur background on CET overlay |
| `blurOnDragOnly` | boolean | true | Only blur while dragging |
| `blurIntensity` | number | 0.0028 | Blur intensity (0.0-0.02) |
| `blurFadeInDuration` | number | 0.25 | Blur fade-in seconds |
| `blurFadeOutDuration` | number | 0.05 | Blur fade-out seconds |
| `probeInterval` | number | 0.5 | Seconds between window re-probes |
| `autoRemoveEmptyWindows` | boolean | true | Auto-remove empty window shells |
| `autoRemoveInterval` | number | 0.5 | Seconds between auto-remove checks |
| `batchAutoRemove` | boolean | true | Check all windows at once vs round-robin |
| `excludedWindows` | table | {} | Window names excluded from external management |
| `windowPOpen` | table | {} | Per-window close button overrides |




## Right-Click Reset

All Controls module widgets (`Checkbox`, `SliderFloat`, `SliderInt`, `Combo`, `ColorEdit4`) support right-click to reset to a default value. Pass the default as a parameter:

```lua
local value, changed = controls.SliderFloat(
    icon, "id", currentValue, 0, 100, "%.0f",
    nil,     -- cols
    50,      -- right-click resets to 50
    "tooltip"
)
```

If the user right-clicks the control, `changed` returns `true` and `value` returns the default.
