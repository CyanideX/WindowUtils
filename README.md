# WindowUtils
 A GUI resource with QoL features and tools.

---

## How to Use WindowUtils Module in Your GUI

### Step 1: Download and Save the Module
1. Download the `WindowUtils.lua` file from the provided source.
2. Save this file in your project's `Modules` directory or any other directory of your choice.

### Step 2: Require the Module in Your Code
1. At the beginning of your Lua script, require the `WindowUtils` module.
    ```lua
    local WindowUtils = require("Modules/WindowUtils")
    ```

### Step 3: Set Up Window Settings
1. Define your window settings, specifying the window names.
    ```lua
    local windowSettings = {
        mainWindow = {
            windowName = "Main Window"
        },
        settingsWindow = {
            windowName = "Settings Window"
        }
    }
    ```

### Step 4: Declare Global Settings
1. Declare global settings for grid snapping and animation.
    ```lua
    local gridEnabled = true
    local animationEnabled = true
    local animationTime = 0.2  -- Optional, default animation time
    ```

### Step 5: Integrate WindowUtils Functions
1. Call the `WindowUtils.UpdateWindow` function within your drawing loop to handle window snapping and animation.
    ```lua
    registerForEvent("onDraw", function()
        DrawMainWindow()
        DrawSettingsWindow()
    end)

    function DrawMainWindow()
        -- Your custom drawing logic for Main Window
        WindowUtils.UpdateWindow(windowSettings.mainWindow.windowName, gridEnabled, animationEnabled, animationTime)
    end

    function DrawSettingsWindow()
        -- Your custom drawing logic for Settings Window
        WindowUtils.UpdateWindow(windowSettings.settingsWindow.windowName, gridEnabled, animationEnabled, animationTime)
    end
    ```

### Step 6: Add GUI Toggles (Optional)
1. Add checkboxes and sliders in your GUI to allow users to toggle grid snapping and animation, and to adjust the animation speed.
    ```lua
    gridEnabled, changed = ImGui.Checkbox("Grid Snap", gridEnabled)
    if changed then
        SaveSettings()
    end

    animationEnabled, changed = ImGui.Checkbox("Animate Snap", animationEnabled)
    if changed then
        SaveSettings()
    end

    if animationEnabled then
        animationTime, changed = ImGui.SliderFloat("Animation Speed", animationTime, 0.1, 1.0, "%.2f")
        if changed then
            SaveSettings()
        end
    end
    ```

### Example Code
Here's a consolidated example to show how everything comes together:

```lua
local WindowUtils = require("Modules/WindowUtils")

local windowSettings = {
    mainWindow = {
        windowName = "Main Window"
    },
    settingsWindow = {
        windowName = "Settings Window"
    }
}

local gridEnabled = true
local animationEnabled = true
local animationTime = 0.2

registerForEvent("onDraw", function()
    DrawMainWindow()
    DrawSettingsWindow()
end)

function DrawMainWindow()
    -- Your custom drawing logic for Main Window
    WindowUtils.UpdateWindow(windowSettings.mainWindow.windowName, gridEnabled, animationEnabled, animationTime)
end

function DrawSettingsWindow()
    -- Your custom drawing logic for Settings Window
    gridEnabled, changed = ImGui.Checkbox("Grid Snap", gridEnabled)
    if changed then
        SaveSettings()
    end

    animationEnabled, changed = ImGui.Checkbox("Animate Snap", animationEnabled)
    if changed then
        SaveSettings()
    end

    if animationEnabled then
        animationTime, changed = ImGui.SliderFloat("Animation Speed", animationTime, 0.1, 1.0, "%.2f")
        if changed then
            SaveSettings()
        end
    end

    WindowUtils.UpdateWindow(windowSettings.settingsWindow.windowName, gridEnabled, animationEnabled, animationTime)
end
```
