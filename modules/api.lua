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

api.ToggleSettings = ui.toggle
api.ShowSettings = ui.show
api.HideSettings = ui.hide
api.IsSettingsVisible = ui.isVisible

--------------------------------------------------------------------------------
-- Master Override
--------------------------------------------------------------------------------

---@return boolean
function api.IsEnabled()
    return settings.master.enabled
end

function api.Enable()
    settings.master.enabled = true
    settings.save()
end

function api.Disable()
    settings.master.enabled = false
    settings.save()
end

---@param enabled boolean
function api.SetEnabled(enabled)
    settings.master.enabled = enabled
    settings.save()
end

--------------------------------------------------------------------------------
-- Grid
--------------------------------------------------------------------------------

---@return boolean
function api.IsGridEnabled()
    return settings.master.gridEnabled
end

---@param enabled boolean
function api.SetGridEnabled(enabled)
    settings.master.gridEnabled = enabled
    settings.save()
end

---@return number
function api.GetGridUnits()
    return settings.master.gridUnits
end

---@param units number Grid unit count (must be > 0)
---@return boolean success
function api.SetGridUnits(units)
    if type(units) ~= "number" or units <= 0 then return false end
    settings.master.gridUnits = units
    settings.save()
    core.invalidateGridCache()
    return true
end

--------------------------------------------------------------------------------
-- Animation
--------------------------------------------------------------------------------

---@return boolean
function api.IsAnimationEnabled()
    return settings.master.animationEnabled
end

---@param enabled boolean
function api.SetAnimationEnabled(enabled)
    settings.master.animationEnabled = enabled
    settings.save()
end

---@return number
function api.GetAnimationDuration()
    return settings.master.animationDuration
end

---@param duration number Seconds (must be > 0)
---@return boolean success
function api.SetAnimationDuration(duration)
    if type(duration) ~= "number" or duration <= 0 then return false end
    settings.master.animationDuration = duration
    settings.save()
    return true
end

--------------------------------------------------------------------------------
-- Settings Access
--------------------------------------------------------------------------------

--- Get the current master settings table (mutable reference).
--- Call api.SaveSettings() to persist after direct changes.
---@return table
function api.GetSettings()
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
function api.ApplySettings(settingsTable)
    if type(settingsTable) ~= "table" then return false end

    local applied = false
    local gridChanged = false
    for key, value in pairs(settingsTable) do
        if settings.master[key] ~= nil then
            settings.master[key] = value
            applied = true
            if key == "gridUnits" then gridChanged = true end
        end
    end

    if applied then
        settings.save()
        if gridChanged then core.invalidateGridCache() end
    end
    return applied
end

--- Reset all settings to defaults and save.
function api.ResetSettings()
    settings.reset()
    core.invalidateGridCache()
end

--- Reload settings from disk.
function api.ReloadSettings()
    settings.reload()
    core.invalidateGridCache()
end

--- Save current settings to disk.
---@return boolean success
function api.SaveSettings()
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

return api
