--------------------------------------------------------
-- WindowUtils - External API Module
-- Interface for other mods to control WindowUtils
--------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")
local ui = require("modules/ui")
local registry = require("modules/registry")

local api = {}

--------------------------------------------------------------------------------
-- Settings Window Control
--------------------------------------------------------------------------------

api.Toggle = ui.toggle
api.Show = ui.show
api.Hide = ui.hide
api.IsVisible = ui.isVisible

--------------------------------------------------------------------------------
-- Settings Access
--------------------------------------------------------------------------------

--- Get the current master settings table (mutable reference).
--- Call api.Save() to persist after direct changes.
---@return table
function api.Get()
    return settings.master
end

--- Get the default settings table (read-only reference).
---@return table
function api.GetDefaults()
    return settings.defaults
end

--- Apply multiple settings at once, persist, and trigger side effects.
---@param settingsTable table Key-value pairs of settings to apply
---@return boolean applied True if any settings were applied
function api.Set(settingsTable)
    if type(settingsTable) ~= "table" then return false end

    local applied = false
    local gridChanged = false
    for key, value in pairs(settingsTable) do
        if settings.master[key] ~= nil then
            local valid, reason = settings.validateValue(key, value)
            if valid then
                settings.master[key] = value
                applied = true
                if key == "gridUnits" then gridChanged = true end
            else
                settings.debugPrint("Set: skipping '" .. key .. "': " .. (reason or "invalid"))
            end
        end
    end

    if applied then
        settings.save()
        if gridChanged then core.invalidateGridCache() end
        -- Sync UI state for settings that drive live behavior
        if settingsTable.showGuiWindow ~= nil then
            ui.state.showWindow = settings.master.showGuiWindow
        end
    end
    return applied
end

--- Reset all settings to defaults and save.
function api.Reset()
    settings.reset()
    core.invalidateGridCache()
end

--- Reload settings from disk.
function api.Reload()
    settings.reload()
    core.invalidateGridCache()
end

--- Save current settings to disk.
---@return boolean success
function api.Save()
    return settings.save()
end

--------------------------------------------------------------------------------
-- Window Registration
--------------------------------------------------------------------------------

--- Register a window with metadata for external window management.
--- Used to declare that a window has a close button (pOpen) so WindowUtils
--- can manage it correctly without empty-shell detection.
---@param windowName string Window name string (supports ### stable ID syntax)
---@param options table { hasCloseButton = boolean }
---@return boolean success
function api.RegisterWindow(windowName, options)
    if type(windowName) ~= "string" or windowName == "" then
        settings.debugPrint("RegisterWindow: invalid windowName", true)
        return false
    end
    options = options or {}
    if type(options) ~= "table" then
        settings.debugPrint("RegisterWindow: invalid options", true)
        return false
    end
    local result = registry.register(windowName, options)
    settings.debugPrint("RegisterWindow: '" .. windowName .. "' hasCloseButton=" .. tostring(options.hasCloseButton or false))
    return result
end

--- Unregister a previously registered window.
---@param windowName string
---@return boolean success
function api.UnregisterWindow(windowName)
    if type(windowName) ~= "string" or windowName == "" then
        settings.debugPrint("UnregisterWindow: invalid windowName", true)
        return false
    end
    local result = registry.unregister(windowName)
    settings.debugPrint("UnregisterWindow: '" .. windowName .. "'")
    return result
end

--------------------------------------------------------------------------------
-- Console Helpers
--------------------------------------------------------------------------------

--- Print all settings keys with current value, default value, and type.
--- Intended for use in the CET console: GetMod("WindowUtils").API.Info()
function api.Info()
    local keys = {}
    for key in pairs(settings.defaults) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local lines = {}
    for _, key in ipairs(keys) do
        local default = settings.defaults[key]
        local current = settings.master[key]
        local curStr = tostring(current)
        local defStr = tostring(default)
        if type(default) == "table" then
            curStr = "{" .. table.concat(current, ", ") .. "}"
            defStr = "{" .. table.concat(default, ", ") .. "}"
        end
        local changed = curStr ~= defStr
        local entry = key .. " = " .. curStr
        if changed then
            entry = entry .. "  (default: " .. defStr .. ")"
        end
        lines[#lines + 1] = entry
    end

    print(string.rep("-", 40))
    print("WindowUtils Settings (" .. #lines .. " keys)")
    print(string.rep("-", 40))
    print("Get: local s = wu.API.Get(); print(s.gridEnabled)")
    print("Set: wu.API.Set({ gridEnabled = false })")
    print(string.rep("-", 40))
    for _, line in ipairs(lines) do
        print(line)
    end
end

return api
