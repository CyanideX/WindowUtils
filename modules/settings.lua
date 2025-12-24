------------------------------------------------------
-- WindowUtils - Settings Module
-- Handles persistence and configuration management
------------------------------------------------------

local settings = {}

-- Settings file path
local settingsPath = "data/settings.json"

-- Global defaults (can be changed via SetGlobalDefaults)
settings.defaults = {
    gridSize = 20,
    gridEnabled = true,
    animationEnabled = true,
    animationDuration = 0.2,
    easeFunction = "easeInOut"
}

-- Master settings (highest priority when enabled, persisted to JSON)
settings.master = {
    enabled = false,
    gridSize = 20,
    gridEnabled = true,
    animationEnabled = true,
    animationDuration = 0.2,
    easeFunction = "easeInOut"
}

-- Per-window configuration overrides
settings.windowConfigs = {}

-- External settings reference (set via configure())
settings.external = nil

-- Map from internal keys to external setting keys
settings.KEY_MAP = {
    gridSize = "windowGridSize",
    gridEnabled = "windowGridEnabled",
    animationEnabled = "windowAnimationEnabled",
    animationDuration = "windowAnimationDuration",
    easeFunction = "windowInterpolation"
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
