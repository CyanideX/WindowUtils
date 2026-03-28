------------------------------------------------------
-- WindowUtils - Settings Module
-- Handles persistence and configuration management
------------------------------------------------------

local settings = {}

local settingsPath = "data/settings.json"

settings.NAME = "Window Utils"
settings.ICON = IconGlyphs.WindowMaximize
settings.VERSION = "1.0.0"

--- Print a debug message to the CET console.
---@param message string Message to print
---@param forced? boolean Print even if debugOutput is disabled
function settings.debugPrint(message, forced)
    if settings.master.debugOutput or forced then
        print(settings.ICON .. " " .. settings.NAME .. ": " .. message)
    end
end

settings.GRID_UNIT_SIZE = 20

local function createDefaultSettings()
    return {
        gridUnits = 2,
        gridEnabled = true,
        snapCollapsed = true,
        gridVisualizationEnabled = true,
        gridLineThickness = 3.0,
        gridLineColor = {0.25, 0.95, 0.98, 0.8},
        gridShowOnDragOnly = true,
        animationEnabled = true,
        animationDuration = 0.2,
        easeFunction = "easeOut",
        tooltipsEnabled = true,
        debugOutput = false,
        overrideAllWindows = false,
        gridFeatherEnabled = true,
        gridFeatherRadius = 400,
        gridFeatherPadding = 0,
        gridFeatherCurve = 5.0,
        gridGuidesEnabled = false,
        gridGuidesDimming = 0.2,
        gridDimBackground = true,
        gridDimBackgroundOnDragOnly = true,
        gridDimBackgroundOpacity = 0.2,
        showGuiWindow = true,
        blurOnOverlayOpen = false,
        blurOnDragOnly = true,
        blurIntensity = 0.0028,
        fadeInDuration = 0.25,
        fadeOutDuration = 0.05,
        quickExit = true,
        probeInterval = 0.5,
        autoRemoveEmptyWindows = true,
        autoRemoveInterval = 0.5,
        batchAutoRemove = true,
        autoAdjustOnResize = false,
        windowOverrides = {},
        hiddenWindows = {},
        ignoredWindows = {},
        windowBrowserOpen = false
    }
end

settings.defaults = createDefaultSettings()

settings.master = createDefaultSettings()
settings.master.enabled = false -- master override toggle (persisted with other settings)

settings.windowConfigs = {}

settings.external = nil

settings.KEY_MAP = {
    gridUnits = "windowGridUnits",
    gridEnabled = "windowGridEnabled",
    animationEnabled = "windowAnimationEnabled",
    animationDuration = "windowAnimationDuration",
    easeFunction = "windowInterpolation",
    tooltipsEnabled = "tooltipsEnabled"
}

settings.easingKeys = {"linear", "easeIn", "easeOut", "easeInOut", "bounce"}
settings.easingNames = {"Linear", "Ease In", "Ease Out", "Ease In-Out", "Bounce"}

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

--- Load settings from disk. Merges saved values into master settings.
---@return boolean success
function settings.load()
    local file = io.open(settingsPath, "r")
    if not file then
        settings.debugPrint("No settings file found, using defaults")
        return false
    end

    local content = file:read("*a")
    file:close()

    local success, data = pcall(json.decode, content)
    if not success then
        settings.debugPrint("Failed to parse settings: " .. tostring(data), true)
        return false
    end

    if not data then
        settings.debugPrint("Settings file was empty", true)
        return false
    end

    for key, value in pairs(data) do
        if settings.master[key] ~= nil then
            settings.master[key] = value
        end
    end

    -- Validate windowOverrides: only keep string keys with boolean values
    if type(settings.master.windowOverrides) == "table" then
        local validated = {}
        for k, v in pairs(settings.master.windowOverrides) do
            if type(k) == "string" and type(v) == "boolean" then
                validated[k] = v
            else
                settings.debugPrint("Discarding corrupt windowOverrides entry: " .. tostring(k) .. " = " .. tostring(v))
            end
        end
        settings.master.windowOverrides = validated
    else
        settings.debugPrint("windowOverrides was not a table, resetting to default")
        settings.master.windowOverrides = {}
    end

    -- Validate hiddenWindows: only keep string keys with boolean true
    if type(settings.master.hiddenWindows) == "table" then
        local validated = {}
        for k, v in pairs(settings.master.hiddenWindows) do
            if type(k) == "string" and v == true then
                validated[k] = true
            end
        end
        settings.master.hiddenWindows = validated
    else
        settings.master.hiddenWindows = {}
    end

    -- Validate ignoredWindows: only keep string keys with boolean true
    if type(settings.master.ignoredWindows) == "table" then
        local validated = {}
        for k, v in pairs(settings.master.ignoredWindows) do
            if type(k) == "string" and v == true then
                validated[k] = true
            end
        end
        settings.master.ignoredWindows = validated
    else
        settings.master.ignoredWindows = {}
    end

    -- Migrate old key name to new
    if data.showSettingsWindow ~= nil and data.showGuiWindow == nil then
        settings.master.showGuiWindow = data.showSettingsWindow
    end

    settings.debugPrint("Settings Loaded")
    return true
end

--- Save current master settings to disk.
---@return boolean success
function settings.save()
    if not settings.master then
        settings.debugPrint("Cannot save: master settings not initialized", true)
        return false
    end

    local success, content = pcall(json.encode, settings.master)
    if not success then
        settings.debugPrint("Failed to encode settings: " .. tostring(content), true)
        return false
    end

    local file, err = io.open(settingsPath, "w")
    if not file then
        settings.debugPrint("Failed to open settings file for writing: " .. tostring(err), true)
        return false
    end

    file:write(content)
    file:close()
    return true
end

--- Reset all settings to defaults and save.
function settings.reset()
    settings.master = createDefaultSettings()
    settings.master.enabled = false
    settings.save()
    settings.debugPrint("Settings reset to defaults", true)
end

--- Reload settings from disk.
function settings.reload()
    settings.load()
    settings.debugPrint("Settings reloaded")
end

--------------------------------------------------------------------------------
-- Configuration API
--------------------------------------------------------------------------------

--- Override global default values.
---@param config table Key-value pairs to merge into defaults
function settings.setDefaults(config)
    for key, value in pairs(config) do
        if settings.defaults[key] ~= nil then
            settings.defaults[key] = value
        end
    end
end

--- Configure with an external settings object reference.
function settings.configure(settingsObj)
    settings.external = settingsObj
    settings.debugPrint("Configured")
end

--- Set per-window configuration overrides.
---@param windowName string Window title
---@param config table Key-value pairs to merge into window config
function settings.setWindowConfig(windowName, config)
    if not settings.windowConfigs[windowName] then
        settings.windowConfigs[windowName] = {}
    end
    for key, value in pairs(config) do
        settings.windowConfigs[windowName][key] = value
    end
end

--- Remove all per-window configuration overrides.
---@param windowName string Window title
function settings.clearWindowConfig(windowName)
    settings.windowConfigs[windowName] = nil
end

--- Get valid grid unit values for current display resolution.
-- Returns units where (units * GRID_UNIT_SIZE) evenly divides both width and height.
function settings.getValidGridUnits(maxUnits)
    maxUnits = maxUnits or 10
    local validUnits = {}
    local width, height = GetDisplayResolution()

    for units = 1, maxUnits do
        local gridSize = units * settings.GRID_UNIT_SIZE
        if width % gridSize == 0 and height % gridSize == 0 then
            table.insert(validUnits, units)
        end
    end

    return validUnits
end

--- Get effective configuration value for a window.
-- Priority: master settings (if enabled) > per-window override > external settings > global defaults
function settings.getConfig(windowName, key)
    if settings.master.enabled and settings.master[key] ~= nil then
        return settings.master[key]
    end
    if settings.windowConfigs[windowName] and settings.windowConfigs[windowName][key] ~= nil then
        return settings.windowConfigs[windowName][key]
    end
    if settings.external and settings.external.Current then
        local externalKey = settings.KEY_MAP[key]
        if externalKey and settings.external.Current[externalKey] ~= nil then
            return settings.external.Current[externalKey]
        end
    end
    return settings.defaults[key]
end

--- Get the user override for a window's hasCloseButton, or nil if not set.
---@param windowName string
---@return boolean|nil
function settings.getWindowOverride(windowName)
    return settings.master.windowOverrides[windowName]
end

--- Set or clear a user override for a window's hasCloseButton.
---@param windowName string
---@param value boolean|nil  nil removes the override
function settings.setWindowOverride(windowName, value)
    settings.master.windowOverrides[windowName] = value
    settings.save()
end

--- Check if a window is hidden in the browser.
---@param windowName string
---@return boolean
function settings.isWindowHidden(windowName)
    return settings.master.hiddenWindows[windowName] == true
end

--- Set or clear a window's hidden state.
---@param windowName string
---@param hidden boolean
function settings.setWindowHidden(windowName, hidden)
    settings.master.hiddenWindows[windowName] = hidden or nil
    settings.save()
end

--- Check if a window is ignored (completely excluded from overrides).
---@param windowName string
---@return boolean
function settings.isWindowIgnored(windowName)
    return settings.master.ignoredWindows[windowName] == true
end

--- Set or clear a window's ignored state.
---@param windowName string
---@param ignored boolean
function settings.setWindowIgnored(windowName, ignored)
    settings.master.ignoredWindows[windowName] = ignored or nil
    -- Ignoring clears other overrides for this window
    if ignored then
        settings.master.windowOverrides[windowName] = nil
        settings.master.hiddenWindows[windowName] = nil
    end
    settings.save()
end

return settings
