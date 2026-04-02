# WindowUtils

A universal ImGui window management library for Cyber Engine Tweaks mods. Provides grid snapping, smooth animations, collapse-safe window sizing, and a master settings GUI.

## Features

- **Grid Snapping** - Windows snap to a configurable grid when released
- **Smooth Animations** - Multiple easing functions for polished transitions
- **Collapse-Safe Sizing** - Windows remember their size when collapsed/expanded
- **Expand Panels** - Toggle panels that grow/shrink the window with auto-sizing, drag-to-resize, and constraint animation
- **Master Settings GUI** - Central control panel for all mods using WindowUtils
- **Window Browser** - Browse, toggle, hide, and ignore all discovered CET windows with bulk actions
- **Per-Window Configuration** - Override settings for individual windows
- **Constraint Animations** - Animate window size constraints for expanding panels
- **Controls Library** - Styled buttons, sliders, checkboxes, combos, color pickers, tooltips, tabs, drag-drop, notifications
- **External API** - Other mods can control WindowUtils programmatically

## Installation

1. Download and extract to `bin/x64/plugins/cyber_engine_tweaks/mods/WindowUtils/`
2. The mod will appear in CET and show a settings window when the overlay opens

## Structure

```
WindowUtils/
├── init.lua              # Entry point and public API
├── data/
│   └── settings.json     # Persisted master settings
├── docs/                 # Per-module API documentation
├── core/
│   ├── core.lua          # Window management logic
│   ├── discovery.lua     # Window enumeration via RedCetWM
│   ├── effects.lua       # Blur, dim, and grid visualization effects
│   ├── registry.lua      # Window registry
│   └── settings.lua      # Configuration and persistence
├── modules/
│   ├── api.lua           # External mod API
│   ├── controls.lua      # ImGui control helpers (sliders, buttons, inputs)
│   ├── dragdrop.lua      # Drag and drop utilities
│   ├── expand.lua        # Automatic window resizing for toggle panels
│   ├── modal.lua         # Modal dialog utilities
│   ├── notifications.lua # Toast notification system
│   ├── search.lua        # Search utilities
│   ├── splitter.lua      # Draggable panel dividers
│   ├── styles.lua        # ImGui style helpers
│   ├── tabs.lua          # Tab bar utilities
│   ├── tooltips.lua      # Tooltip helpers
│   └── utils.lua         # Shared utility functions
└── ui/
    └── ui.lua            # Settings window GUI
```

## Quick Start

### For Mods Using WindowUtils

```lua
-- In your mod's onInit:
local WindowUtils = nil

registerForEvent("onInit", function()
    WindowUtils = GetMod("WindowUtils")
    if WindowUtils then
        -- Optional: Pass your settings object for integration
        WindowUtils.Configure(mySettings)
    end
end)

registerForEvent("onDraw", function()
    if ImGui.Begin("My Window") then
        -- Your window content here

        -- Call at end of window (before ImGui.End)
        if WindowUtils then
            WindowUtils.Update("My Window")
        end
    end
    ImGui.End()
end)
```

### Integrating with Your Mod's Settings

WindowUtils can read settings from your mod's settings object:

```lua
-- Your settings object should have a .Current table with these keys:
-- windowGridSize, windowGridEnabled, windowAnimationEnabled,
-- windowAnimationDuration, windowInterpolation

WindowUtils.Configure(settings)  -- Pass parent object with .Current property
```

## Master Settings GUI

When you open the CET overlay, the "WindowUtils Settings" window appears with:

- **Enable Master Override** - When enabled, these settings override all mods
- **Grid Snapping** - Toggle and grid size (5-50px)
- **Animation** - Toggle, duration (0.05-0.5s), and easing function

Settings are persisted to `data/settings.json`.

## External Mod API

Other mods can control WindowUtils programmatically via `GetMod("WindowUtils").API`.

### Settings Window Control

| Function | Description |
|----------|-------------|
| `API.Toggle()` | Toggle the settings window open/closed |
| `API.Show()` | Show the settings window |
| `API.Hide()` | Hide the settings window |
| `API.IsVisible()` | Returns `true` if the settings window is open |

### Settings Access

| Function | Description |
|----------|-------------|
| `API.Get()` | Get the current master settings table (mutable reference) |
| `API.GetDefaults()` | Get the default settings table (read-only reference) |
| `API.Set(settingsTable)` | Apply multiple settings at once with validation, persist, and trigger side effects |
| `API.Save()` | Save current settings to disk |
| `API.Reset()` | Reset all settings to defaults and save |
| `API.Reload()` | Reload settings from disk |

### Window Registration

| Function | Description |
|----------|-------------|
| `API.RegisterWindow(name, options)` | Register a window with metadata (e.g. `{ hasCloseButton = true }`) |
| `API.UnregisterWindow(name)` | Unregister a previously registered window |

### Console Helpers

| Function | Description |
|----------|-------------|
| `API.Info()` | Print all settings keys with current value, default, and type to the CET console |

### Example

```lua
local wu = GetMod("WindowUtils")
if wu then
    wu.API.Toggle()

    local s = wu.API.Get()
    print(s.gridEnabled, s.animationDuration)

    wu.API.Set({ gridEnabled = true, animationDuration = 0.3 })
    wu.API.Save()

    wu.API.RegisterWindow("My Window", { hasCloseButton = true })
end
```

> **Migration note:** Individual getter/setter functions for grid, animation, and enabled state
> (e.g. `IsGridEnabled`, `SetGridEnabled`, `GetAnimationDuration`, `SetAnimationEnabled`)
> were removed. Use `API.Get()` to read settings and `API.Set({...})` to write them instead.

## API Reference

### Main Functions

#### `WindowUtils.Update(windowName, options)`

Update window state. Call once per frame inside each window.

```lua
-- Simple usage (uses global/master defaults)
WindowUtils.Update("My Window")

-- With per-call overrides
WindowUtils.Update("My Window", {
    gridEnabled = true,
    animationEnabled = true,
    animationDuration = 0.3
})
```

#### `WindowUtils.UpdateWindow(windowName, gridEnabled, animationEnabled, animationDuration)`

Legacy API for backward compatibility.

```lua
WindowUtils.UpdateWindow("My Window", true, true, 0.2)
```

### Configuration

#### `WindowUtils.Configure(settingsObj)`

Configure WindowUtils with your mod's settings object. WindowUtils reads from `settingsObj.Current` each frame.

```lua
WindowUtils.Configure(settings)
```

Expected keys in `.Current`:
- `windowGridSize` (number)
- `windowGridEnabled` (boolean)
- `windowAnimationEnabled` (boolean)
- `windowAnimationDuration` (number)
- `windowInterpolation` (string)

#### `WindowUtils.SetGlobalDefaults(config)`

Set default configuration for all windows.

```lua
WindowUtils.SetGlobalDefaults({
    gridSize = 20,              -- Snap grid size in pixels
    gridEnabled = true,         -- Enable grid snapping
    animationEnabled = true,    -- Enable snap animations
    animationDuration = 0.2,    -- Animation duration in seconds
    easeFunction = "easeInOut"  -- Easing function name
})
```

#### `WindowUtils.SetWindowConfig(windowName, config)`

Override configuration for a specific window.

```lua
WindowUtils.SetWindowConfig("Settings", { gridEnabled = false })
WindowUtils.SetWindowConfig("Main Window", {
    easeFunction = "bounce",
    animationDuration = 0.4
})
```

#### `WindowUtils.ClearWindowConfig(windowName)`

Remove per-window overrides.

#### `WindowUtils.GetConfig(windowName, key)`

Get effective configuration value for a window.

```lua
local gridSize = WindowUtils.GetConfig("My Window", "gridSize")
```

### Settings Priority

Configuration is resolved in this order (highest to lowest):
1. **Master settings** (when enabled via GUI)
2. **Per-window overrides** (via `SetWindowConfig`)
3. **External settings** (via `Configure`)
4. **Global defaults** (via `SetGlobalDefaults` or built-in)

### Easing Functions

Available easing functions:
- `linear` - Constant speed
- `easeIn` - Start slow, accelerate
- `easeOut` - Start fast, decelerate
- `easeInOut` - Smooth start and end (default)
- `bounce` - Bouncy effect at end

```lua
local easings = WindowUtils.GetEasingFunctions()
```

### State Query

```lua
WindowUtils.IsAnimating(windowName)           -- Check if animating
WindowUtils.GetExpandedSize(windowName)       -- Get remembered size
WindowUtils.CompleteAnimation(windowName)     -- Force-complete animation
WindowUtils.ResetWindow(windowName)           -- Reset window state
WindowUtils.CleanupUnusedWindows({"Window1"}) -- Clean up unused
```

### Grid and Math Utilities

```lua
WindowUtils.SnapToGrid(position, windowName)   -- Snap position to grid
WindowUtils.GridAlignMin(value, windowName)     -- Align value down to grid boundary
WindowUtils.GridAlignMax(value, windowName)     -- Align value up to grid boundary
WindowUtils.Lerp(a, b, t)                      -- Linear interpolation
WindowUtils.ApplyEasing(t, windowName)          -- Apply easing using window config
WindowUtils.ApplyEasingByName(t, name)          -- Apply easing by function name
WindowUtils.InvalidateGridCache(windowName)     -- Invalidate cached grid size (call when settings change)
```

### Window Size Constraints

```lua
-- Set next window size constraints with grid-aligned values
WindowUtils.SetNextWindowSizeConstraints(minW, minH, maxW, maxH, windowName)

-- Set next window size constraints as display percentages (0-100)
WindowUtils.SetNextWindowSizeConstraintsPercent(minWPct, minHPct, maxWPct, maxHPct, windowName)
```

### Constraint Animation System

Animate arbitrary values, useful for expanding/collapsing panels.

```lua
-- Start animation
WindowUtils.StartConstraintAnimation("settingsMaxHeight", 600, 200)

-- Update and get current value
local maxHeight = WindowUtils.UpdateConstraintAnimation(
    "settingsMaxHeight",  -- property name
    200,                  -- normal value
    600,                  -- expanded value
    isExpanded,           -- current state
    8.0                   -- speed (optional)
)

ImGui.SetNextWindowSizeConstraints(300, 100, 500, maxHeight)

-- Query state
WindowUtils.IsConstraintAnimating("settingsMaxHeight")
WindowUtils.IsAnyConstraintAnimating()
WindowUtils.IsConstraintAnimatingForWindow("My Window")
```

### Settings Window Control

```lua
WindowUtils.ShowSettingsWindow()        -- Show the settings window
WindowUtils.HideSettingsWindow()        -- Hide the settings window
WindowUtils.ToggleSettingsWindow()      -- Toggle settings window visibility
WindowUtils.IsSettingsWindowVisible()   -- Check if settings window is visible
```

### Expand Panels

Expand panels grow the parent window when opened and shrink it when closed. They support three sizing modes and integrate with the constraint animation system.

```lua
-- Basic expand panel (bottom, auto-sized to content)
local splitter = WindowUtils.Splitter
local expand = WindowUtils.Expand

splitter.toggle("my_panel", {
    { content = function()
        controls.Panel("panel_content", function()
            ImGui.Text("Expandable content here")
            -- Measure content for auto mode
            local padY = ImGui.GetStyle().WindowPadding.y
            expand.setMeasuredSize("my_panel", ImGui.GetCursorPosY() + padY)
        end)
    end },
    { content = function()
        -- Main content (flex panel)
    end },
}, {
    side = "bottom",           -- "left", "right", "top", "bottom"
    size = 200,                -- default/fallback size in pixels
    defaultOpen = false,       -- initial open state
    expand = true,             -- enable window expansion
    sizeMode = "auto",         -- "fixed", "flex", or "auto"
    windowName = "My Window",  -- required for expand
    toggleOnClick = true,      -- single-click toggle (default: double-click)
    normalConstraintPct = 50,  -- base max height as display % (for constraint animation)
})

-- Drive window sizing (call at main window scope, outside children)
expand.applyWindowSize("My Window")
```

#### Size Modes

| Mode | Behavior |
|------|----------|
| `fixed` | Panel has a fixed pixel size. Drag to resize changes the window. |
| `flex` | Panel size is a ratio of the window. Drag changes the ratio, window stays the same. |
| `auto` | Panel auto-sizes to its content. Window grows to fit. |

#### Constraint Animation

When using `normalConstraintPct`, the max window size constraint animates when the panel opens/closes. Wire it into your `SetNextWindowSizeConstraints` call:

```lua
local maxHPct = splitter.getExpandConstraint("my_panel")
local maxH = maxHPct and (displayH * maxHPct / 100) or (displayH * 0.5)
core.setNextWindowSizeConstraints(minW, minH, maxW, maxH, windowName)
```

#### toggleOnClick

When `toggleOnClick = true`, the expand bar responds to single-click for toggle and drag for resize. The bar icon shows a toggle arrow normally and switches to a drag handle while dragging. Without `toggleOnClick`, double-click toggles (the default expand behavior).

#### Persisting Open State

The expand system preserves window size across sessions via CET's ImGui .ini and the WindowUtils window cache. To persist the open/closed state, save a boolean in your mod's settings and pass it as `defaultOpen`:

```lua
splitter.toggle("my_panel", panels, {
    defaultOpen = mySettings.panelOpen,
    expand = true,
    -- ...
})

-- Sync toggle state to your settings
local isOpen = splitter.getToggle("my_panel") or false
if isOpen ~= mySettings.panelOpen then
    mySettings.panelOpen = isOpen
    saveSettings()
end
```

### Master Settings

```lua
WindowUtils.IsMasterEnabled()     -- Check if master override is enabled
WindowUtils.GetMasterSettings()   -- Get the master settings table
```

### Constants

```lua
WindowUtils.NAME      -- Library name string
WindowUtils.ICON      -- Library icon string
WindowUtils.VERSION   -- Library version string
```

### Sub-Modules

WindowUtils exposes several sub-modules for advanced usage. Each has its own documentation in the `docs/` directory.

```lua
WindowUtils.API        -- External mod API (see "External Mod API" above)
WindowUtils.Styles     -- ImGui style helpers (see docs/styles.md)
WindowUtils.Controls   -- ImGui control helpers (see docs/controls.md)
WindowUtils.Tooltips   -- Tooltip helpers (see docs/tooltips.md)
WindowUtils.Utils      -- Shared utility functions (see docs/utils.md)
WindowUtils.Splitter   -- Draggable panel dividers (see docs/splitter.md)
WindowUtils.Expand     -- Automatic window resizing (see docs/expand.md)
WindowUtils.Tabs       -- Tab bar utilities (see docs/tabs.md)
WindowUtils.DragDrop   -- Drag and drop utilities (see docs/dragdrop.md)
WindowUtils.Notify     -- Toast notification system (see docs/notifications.md)
```

## Complete Example

```lua
local WindowUtils = nil

registerForEvent("onInit", function()
    WindowUtils = GetMod("WindowUtils")
    if WindowUtils then
        WindowUtils.Configure(settings)
    end
end)

local showSettings = false

registerForEvent("onDraw", function()
    if not WindowUtils then return end

    -- Main window
    if ImGui.Begin("My Mod") then
        if ImGui.Button("Toggle Settings") then
            showSettings = not showSettings
            WindowUtils.StartConstraintAnimation("settingsHeight",
                showSettings and 400 or 100, nil)
        end

        WindowUtils.Update("My Mod")
    end
    ImGui.End()

    -- Settings window with animated height
    if showSettings then
        local maxH = WindowUtils.UpdateConstraintAnimation(
            "settingsHeight", 100, 400, showSettings)

        ImGui.SetNextWindowSizeConstraints(200, 50, 400, maxH)

        if ImGui.Begin("Settings") then
            WindowUtils.Update("Settings")
        end
        ImGui.End()
    end
end)
```

## License

Copyright (c) 2024 CyanideX
https://next.nexusmods.com/profile/theCyanideX/mods
