# WindowUtils

A universal ImGui window management library for Cyber Engine Tweaks mods. Provides grid snapping, smooth animations, collapse-safe window sizing, and a master settings GUI.

## Features

- **Grid Snapping** - Windows snap to a configurable grid when released
- **Smooth Animations** - Multiple easing functions for polished transitions
- **Collapse-Safe Sizing** - Windows remember their size when collapsed/expanded
- **Master Settings GUI** - Central control panel for all mods using WindowUtils
- **Per-Window Configuration** - Override settings for individual windows
- **Constraint Animations** - Animate arbitrary values (useful for expanding panels)
- **External API** - Other mods can control WindowUtils programmatically
- **Backward Compatible** - Legacy `UpdateWindow()` API still works

## Installation

1. Download and extract to `bin/x64/plugins/cyber_engine_tweaks/mods/WindowUtils/`
2. The mod will appear in CET and show a settings window when the overlay opens

## Structure

```
WindowUtils/
├── init.lua              # Entry point and public API
├── data/
│   └── settings.json     # Persisted master settings
└── modules/
    ├── api.lua           # External mod API
    ├── core.lua          # Window management logic
    ├── settings.lua      # Configuration and persistence
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

Other mods can control WindowUtils via the API:

```lua
local WindowUtils = GetMod("WindowUtils")
if WindowUtils then
    -- Settings window control
    WindowUtils.API.Toggle()
    WindowUtils.API.Show()
    WindowUtils.API.Hide()
    WindowUtils.API.IsVisible()

    -- Master override control
    WindowUtils.API.IsEnabled()
    WindowUtils.API.Enable()
    WindowUtils.API.Disable()
    WindowUtils.API.SetEnabled(true)

    -- Grid control
    WindowUtils.API.IsGridEnabled()
    WindowUtils.API.EnableGrid()
    WindowUtils.API.DisableGrid()
    WindowUtils.API.SetGridEnabled(true)
    WindowUtils.API.ToggleGrid()

    -- Animation control
    WindowUtils.API.IsAnimationEnabled()
    WindowUtils.API.EnableAnimation()
    WindowUtils.API.DisableAnimation()
    WindowUtils.API.SetAnimationEnabled(true)
    WindowUtils.API.ToggleAnimation()

    -- Get master settings table
    WindowUtils.API.GetSettings()
end
```

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

### Utility Functions

```lua
WindowUtils.SnapToGrid(position, windowName)  -- Snap to grid
WindowUtils.Lerp(a, b, t)                     -- Linear interpolation
WindowUtils.ApplyEasing(t, windowName)        -- Apply easing function
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
