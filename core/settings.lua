------------------------------------------------------
-- WindowUtils - Settings
-- Persistence and configuration management
------------------------------------------------------

local settings = {}

local settingsPath = "data/settings.json"
local windowsPath = "data/windows.json"

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
        tooltipMaxWidthPct = 15,
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
        windowBrowserOpen = false,
        overrideStyling = false,
        disableScrollbar = false,
        showExperimental = false,
        experimentalDisclaimerShown = false
    }
end

local function freezeTable(t, name)
    return setmetatable({}, {
        __index = t,
        __newindex = function(_, k)
            error(name .. " is read-only (attempted to set '" .. tostring(k) .. "')", 2)
        end,
        __len = function() return #t end,
        __pairs = function() return pairs(t) end,
    })
end

local rawDefaults = createDefaultSettings()
settings.defaults = freezeTable(rawDefaults, "settings.defaults")

settings.master = createDefaultSettings()
settings.master.enabled = false

--- Per-window state: overrides, hidden, ignored (persisted to windows.json)
settings.windows = {
    overrides = {},
    hidden = {},
    ignored = {},
}

settings.windowConfigs = {}

-- Incremented on any window override/hidden/ignored change so the browser sort cache can detect staleness
settings.windowsGeneration = 0

settings.easingKeys = {"linear", "easeIn", "easeOut", "easeInOut", "bounce"}
settings.easingNames = {"Linear", "Ease In", "Ease Out", "Ease In-Out", "Bounce"}


--------------------------------------------------------------------------------
-- Persistence: settings.json
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

    settings.debugPrint("Settings Loaded")
    return true
end

--- Save current master settings to disk (excludes window data).
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
    settings.loadWindows()
    settings.debugPrint("Settings reloaded")
end

--------------------------------------------------------------------------------
-- Persistence: windows.json
--------------------------------------------------------------------------------

--- Validate a table of string keys with boolean values.
---@param tbl table|any Raw data to validate
---@param requireTrue? boolean If true, only keep entries where value == true
---@return table validated
local function validateBoolMap(tbl, requireTrue)
    local validated = {}
    if type(tbl) ~= "table" then return validated end
    for k, v in pairs(tbl) do
        if type(k) == "string" then
            if requireTrue then
                if v == true then validated[k] = true end
            elseif type(v) == "boolean" then
                validated[k] = v
            end
        end
    end
    return validated
end

--- Load per-window data from windows.json.
---@return boolean success
function settings.loadWindows()
    local file = io.open(windowsPath, "r")
    if not file then return false end

    local content = file:read("*a")
    file:close()

    local success, data = pcall(json.decode, content)
    if not success or not data then return false end

    settings.windows.overrides = validateBoolMap(data.overrides)
    settings.windows.hidden = validateBoolMap(data.hidden, true)
    settings.windows.ignored = validateBoolMap(data.ignored, true)

    settings.debugPrint("Window data loaded")
    return true
end

--- Save per-window data to windows.json.
---@return boolean success
function settings.saveWindows()
    local success, content = pcall(json.encode, settings.windows)
    if not success then
        settings.debugPrint("Failed to encode window data: " .. tostring(content), true)
        return false
    end

    local file, err = io.open(windowsPath, "w")
    if not file then
        settings.debugPrint("Failed to open windows file for writing: " .. tostring(err), true)
        return false
    end

    file:write(content)
    file:close()
    return true
end

--------------------------------------------------------------------------------
-- Configuration API
--------------------------------------------------------------------------------

--- Override global default values.
--- Writes through to the underlying table behind the frozen proxy.
---@param config table Key-value pairs to merge into defaults
function settings.setDefaults(config)
    for key, value in pairs(config) do
        if rawDefaults[key] ~= nil then
            rawDefaults[key] = value
        end
    end
end

--- Optional callback invoked when per-window config changes.
--- Registered by core to auto-invalidate the grid cache.
---@type fun(windowName: string)|nil
settings.onWindowConfigChanged = nil

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
    if settings.onWindowConfigChanged then
        settings.onWindowConfigChanged(windowName)
    end
end

--- Remove all per-window configuration overrides.
---@param windowName string Window title
function settings.clearWindowConfig(windowName)
    settings.windowConfigs[windowName] = nil
    if settings.onWindowConfigChanged then
        settings.onWindowConfigChanged(windowName)
    end
end

--- Get valid grid unit values for current display resolution.
---@param maxUnits? number Maximum units to check (default 10)
---@return number[] validUnits
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
--- Priority: master (if enabled) > per-window > defaults
function settings.getConfig(windowName, key)
    if settings.master.enabled and settings.master[key] ~= nil then
        return settings.master[key]
    end
    if settings.windowConfigs[windowName] and settings.windowConfigs[windowName][key] ~= nil then
        return settings.windowConfigs[windowName][key]
    end
    return settings.defaults[key]
end

--------------------------------------------------------------------------------
-- Window Override / Hidden / Ignored API
--------------------------------------------------------------------------------

--- Get the user override for a window's hasCloseButton, or nil if not set.
---@param windowName string
---@return boolean|nil
function settings.getWindowOverride(windowName)
    return settings.windows.overrides[windowName]
end

--- Set or clear a user override for a window's hasCloseButton.
---@param windowName string
---@param value boolean|nil  nil removes the override
function settings.setWindowOverride(windowName, value)
    settings.windows.overrides[windowName] = value
    settings.windowsGeneration = settings.windowsGeneration + 1
    settings.saveWindows()
end

--- Check if a window is hidden in the browser.
---@param windowName string
---@return boolean
function settings.isWindowHidden(windowName)
    return settings.windows.hidden[windowName] == true
end

--- Set or clear a window's hidden state.
---@param windowName string
---@param hidden boolean
function settings.setWindowHidden(windowName, hidden)
    settings.windows.hidden[windowName] = hidden or nil
    settings.windowsGeneration = settings.windowsGeneration + 1
    settings.saveWindows()
end

--- Check if a window is ignored (completely excluded from overrides).
---@param windowName string
---@return boolean
function settings.isWindowIgnored(windowName)
    return settings.windows.ignored[windowName] == true
end

--- Set or clear a window's ignored state.
---@param windowName string
---@param ignored boolean
function settings.setWindowIgnored(windowName, ignored)
    settings.windows.ignored[windowName] = ignored or nil
    if ignored then
        settings.windows.overrides[windowName] = nil
        settings.windows.hidden[windowName] = nil
    end
    settings.windowsGeneration = settings.windowsGeneration + 1
    settings.saveWindows()
end

--------------------------------------------------------------------------------
-- Debounced Save
--------------------------------------------------------------------------------

local dirtyState = {
    isDirty = false,
    lastDirtyTime = 0,
}

local FLUSH_IDLE_THRESHOLD = 0.5  -- seconds

--- Mark settings as dirty, resetting the idle timer.
function settings.markDirty()
    dirtyState.isDirty = true
    dirtyState.lastDirtyTime = os.clock()
end

--- Flush to disk if dirty and idle for at least FLUSH_IDLE_THRESHOLD seconds.
function settings.flushIfIdle()
    if not dirtyState.isDirty then return end
    local elapsed = os.clock() - dirtyState.lastDirtyTime
    if elapsed >= FLUSH_IDLE_THRESHOLD then
        settings.save()
        dirtyState.isDirty = false
    end
end

--- Immediately flush to disk if dirty.
function settings.flushNow()
    if dirtyState.isDirty then
        settings.save()
        dirtyState.isDirty = false
    end
end

--------------------------------------------------------------------------------
-- Value Validation
--------------------------------------------------------------------------------

local validationRules = {
    gridUnits = function(v)
        if type(v) ~= "number" then return false, "expected number" end
        if v <= 0 then return false, "must be > 0" end
        return true
    end,
    animationDuration = function(v)
        if type(v) ~= "number" then return false, "expected number" end
        if v <= 0 then return false, "must be > 0" end
        return true
    end,
    easeFunction = function(v)
        if type(v) ~= "string" then return false, "expected string" end
        for _, k in ipairs(settings.easingKeys) do
            if k == v then return true end
        end
        return false, "unknown easing function"
    end,
    gridLineColor = function(v)
        if type(v) ~= "table" then return false, "expected table" end
        if #v ~= 4 then return false, "expected 4 elements" end
        for i = 1, 4 do
            if type(v[i]) ~= "number" then return false, "element " .. i .. " not a number" end
        end
        return true
    end,
}

--- Validate a setting value against type and field-specific rules.
--- Unknown keys (not in settings.master) return true (silently ignored).
---@param key string Setting key name
---@param value any Value to validate
---@return boolean valid
---@return string|nil reason
function settings.validateValue(key, value)
    local existing = settings.master[key]
    if existing == nil then return true end
    if type(value) ~= type(existing) then
        return false, "type mismatch: expected " .. type(existing) .. ", got " .. type(value)
    end
    local rule = validationRules[key]
    if rule then
        return rule(value)
    end
    return true
end

return settings
