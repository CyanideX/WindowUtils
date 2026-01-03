------------------------------------------------------
-- WindowUtils - Settings Module
-- Handles persistence and configuration management
------------------------------------------------------

---@class WindowUtilsSettingsValues
---@field gridUnits number Grid size multiplier (gridUnits * GRID_UNIT_SIZE = pixels)
---@field gridEnabled boolean Enable grid snapping
---@field snapCollapsed boolean Snap collapsed windows when dragged
---@field gridVisualizationEnabled boolean Show grid overlay
---@field gridLineThickness number Grid line thickness in pixels
---@field gridLineColor number[] RGBA color {r, g, b, a} values 0-1
---@field gridShowOnDragOnly boolean Only show grid while dragging
---@field animationEnabled boolean Enable snap animations
---@field animationDuration number Animation duration in seconds
---@field easeFunction string Easing function name
---@field tooltipsEnabled boolean Show tooltips
---@field debugOutput boolean Print debug messages to console
---@field overrideAllWindows boolean Apply to all CET windows
---@field gridFeatherEnabled boolean Enable grid feathering
---@field gridFeatherRadius number Feather radius in pixels
---@field gridFeatherPadding number Feather padding in pixels
---@field gridFeatherCurve number Feather curve exponent
---@field gridGuidesEnabled boolean Show alignment guide lines at window edges
---@field gridGuidesDimming number Grid opacity multiplier when guides active (0-1)
---@field gridDimBackground boolean Dim background behind grid and windows
---@field gridDimBackgroundOnDragOnly boolean Only dim background while dragging windows
---@field gridDimBackgroundOpacity number Background dimming opacity (0-1)
---@field showSettingsWindow boolean Show the settings window
---@field blurOnOverlayOpen boolean Blur background when CET overlay opens
---@field blurOnDragOnly boolean Only blur while dragging windows
---@field blurIntensity number Blur intensity (0.0-0.02)
---@field blurFadeInDuration number Blur fade-in duration in seconds
---@field blurFadeOutDuration number Blur fade-out duration in seconds

---@class WindowUtilsMasterSettings : WindowUtilsSettingsValues
---@field enabled boolean Master override enabled

---@class WindowUtilsSettings
---@field GRID_UNIT_SIZE number Base grid unit in pixels
---@field defaults WindowUtilsSettingsValues Global default settings
---@field master WindowUtilsMasterSettings Master override settings
---@field windowConfigs table<string, table> Per-window configuration overrides
---@field external table|nil External settings reference
---@field KEY_MAP table<string, string> Internal to external key mapping
---@field easingNames string[] Available easing function names
---@field load fun() Load settings from file
---@field save fun() Save settings to file
---@field setDefaults fun(config: table) Set global defaults
---@field configure fun(settingsObj: table) Configure with external settings
---@field setWindowConfig fun(windowName: string, config: table) Set per-window config
---@field clearWindowConfig fun(windowName: string) Clear per-window config
---@field getValidGridUnits fun(maxUnits?: number): number[] Get valid grid units
---@field getConfig fun(windowName: string|nil, key: string): any Get effective config value
local settings = {} ---@type WindowUtilsSettings

-- Settings file path
local settingsPath = "data/settings.json"

--------------------------------------------------------------------------------
-- Mod Identity
--------------------------------------------------------------------------------

settings.NAME = "Window Utils"
settings.ICON = IconGlyphs.WindowMaximize
settings.VERSION = "1.0.0"

--- Print a debug message with the mod icon and name prefix.
-- @param message string: The message to print
-- @param force boolean: If true, always print; if false/nil, only print when debug mode is enabled
function settings.debugPrint(message, forced)
    if settings.master.debugOutput or forced then
        print(settings.ICON .. " " .. settings.NAME .. ": " .. message)
    end
end

--------------------------------------------------------------------------------
-- Grid Constants
--------------------------------------------------------------------------------

-- Grid unit size in pixels (hardcoded base unit)
settings.GRID_UNIT_SIZE = 20

--------------------------------------------------------------------------------
-- Default Settings Factory
--------------------------------------------------------------------------------

--- Create a fresh settings table with all default values.
-- Used to initialize both defaults and master settings.
-- @return table: New settings table with default values
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
        easeFunction = "easeInOut",
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
        showSettingsWindow = false,
        blurOnOverlayOpen = false,
        blurOnDragOnly = true,
        blurIntensity = 0.0028,
        blurFadeInDuration = 0.25,
        blurFadeOutDuration = 0.05
    }
end

-- Global defaults (can be changed via SetGlobalDefaults)
settings.defaults = createDefaultSettings()

-- Master settings (highest priority when enabled, persisted to JSON)
-- Note: 'enabled' is a master-only control flag, not a setting value
settings.master = createDefaultSettings()
settings.master.enabled = false

-- Per-window configuration overrides
settings.windowConfigs = {}

-- External settings reference (set via configure())
settings.external = nil

-- Map from internal keys to external setting keys
settings.KEY_MAP = {
    gridUnits = "windowGridUnits",
    gridEnabled = "windowGridEnabled",
    animationEnabled = "windowAnimationEnabled",
    animationDuration = "windowAnimationDuration",
    easeFunction = "windowInterpolation",
    tooltipsEnabled = "tooltipsEnabled"
}

-- Easing function names (ordered for dropdown)
settings.easingNames = {"linear", "easeIn", "easeOut", "easeInOut", "bounce"}

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

function settings.load()
    local file = io.open(settingsPath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, data = pcall(json.decode, content)
        if success and data then
            for key, value in pairs(data) do
                if settings.master[key] ~= nil then
                    settings.master[key] = value
                end
            end
            settings.debugPrint("Settings Loaded", true)
        end
    end
end

function settings.save()
    local success, content = pcall(json.encode, settings.master)
    if success then
        local file = io.open(settingsPath, "w")
        if file then
            file:write(content)
            file:close()
        end
    end
end

--------------------------------------------------------------------------------
-- Configuration API
--------------------------------------------------------------------------------

--- Set global default configuration.
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
    settings.debugPrint("Configured", true)
end

--- Set configuration for a specific window.
function settings.setWindowConfig(windowName, config)
    if not settings.windowConfigs[windowName] then
        settings.windowConfigs[windowName] = {}
    end
    for key, value in pairs(config) do
        settings.windowConfigs[windowName][key] = value
    end
end

--- Clear configuration for a specific window.
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
    -- Master settings take highest priority when enabled
    if settings.master.enabled and settings.master[key] ~= nil then
        return settings.master[key]
    end
    -- Per-window override takes next priority
    if settings.windowConfigs[windowName] and settings.windowConfigs[windowName][key] ~= nil then
        return settings.windowConfigs[windowName][key]
    end
    -- External settings (via configure()) take next priority
    if settings.external and settings.external.Current then
        local externalKey = settings.KEY_MAP[key]
        if externalKey and settings.external.Current[externalKey] ~= nil then
            return settings.external.Current[externalKey]
        end
    end
    -- Fall back to defaults
    return settings.defaults[key]
end

return settings
