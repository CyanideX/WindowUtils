------------------------------------------------------
-- WindowUtils - Settings Module
-- Handles persistence and configuration management
------------------------------------------------------

---@class WindowUtilsSettingsValues
---@field gridUnits number Grid size multiplier (gridUnits * GRID_UNIT_SIZE = pixels)
---@field gridEnabled boolean Enable grid snapping
---@field gridVisualizationEnabled boolean Show grid overlay
---@field gridLineThickness number Grid line thickness in pixels
---@field gridLineColor number[] RGBA color {r, g, b, a} values 0-1
---@field gridShowOnDragOnly boolean Only show grid while dragging
---@field animationEnabled boolean Enable snap animations
---@field animationDuration number Animation duration in seconds
---@field easeFunction string Easing function name
---@field tooltipsEnabled boolean Show tooltips
---@field overrideAllWindows boolean Apply to all CET windows
---@field gridFeatherEnabled boolean Enable grid feathering
---@field gridFeatherRadius number Feather radius in pixels
---@field gridFeatherPadding number Feather padding in pixels
---@field gridFeatherCurve number Feather curve exponent
---@field gridGuidesEnabled boolean Show alignment guide lines at window edges
---@field gridGuidesDimming number Grid opacity multiplier when guides active (0-1)

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
        gridUnits = 1,
        gridEnabled = true,
        gridVisualizationEnabled = false,
        gridLineThickness = 3.0,
        gridLineColor = {1.0, 1.0, 1.0, 0.196},
        gridShowOnDragOnly = false,
        animationEnabled = true,
        animationDuration = 0.2,
        easeFunction = "easeInOut",
        tooltipsEnabled = true,
        overrideAllWindows = false,
        gridFeatherEnabled = false,
        gridFeatherRadius = 400,
        gridFeatherPadding = 0,
        gridFeatherCurve = 5.0,
        gridGuidesEnabled = false,
        gridGuidesDimming = 0.2
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
            print("[WindowUtils] Settings loaded")
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
    print("[WindowUtils] Configured with settings object")
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
