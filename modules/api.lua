--------------------------------------------------------
-- WindowUtils - External API Module
-- Clean interface for other mods to control WindowUtils
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
-- Master Override Control
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
-- Grid Control
--------------------------------------------------------------------------------

---@return boolean
function api.IsGridEnabled()
    return settings.master.gridEnabled
end

function api.EnableGrid()
    settings.master.gridEnabled = true
    settings.save()
end

function api.DisableGrid()
    settings.master.gridEnabled = false
    settings.save()
end

---@param enabled boolean
function api.SetGridEnabled(enabled)
    settings.master.gridEnabled = enabled
    settings.save()
end

---@return boolean newState
function api.ToggleGrid()
    settings.master.gridEnabled = not settings.master.gridEnabled
    settings.save()
    return settings.master.gridEnabled
end

--------------------------------------------------------------------------------
-- Animation Control
--------------------------------------------------------------------------------

---@return boolean
function api.IsAnimationEnabled()
    return settings.master.animationEnabled
end

function api.EnableAnimation()
    settings.master.animationEnabled = true
    settings.save()
end

function api.DisableAnimation()
    settings.master.animationEnabled = false
    settings.save()
end

---@param enabled boolean
function api.SetAnimationEnabled(enabled)
    settings.master.animationEnabled = enabled
    settings.save()
end

---@return boolean newState
function api.ToggleAnimation()
    settings.master.animationEnabled = not settings.master.animationEnabled
    settings.save()
    return settings.master.animationEnabled
end

--------------------------------------------------------------------------------
-- Tooltips Control
--------------------------------------------------------------------------------

---@return boolean
function api.IsTooltipsEnabled()
    return settings.master.tooltipsEnabled
end

function api.EnableTooltips()
    settings.master.tooltipsEnabled = true
    settings.save()
end

function api.DisableTooltips()
    settings.master.tooltipsEnabled = false
    settings.save()
end

---@param enabled boolean
function api.SetTooltipsEnabled(enabled)
    settings.master.tooltipsEnabled = enabled
    settings.save()
end

---@return boolean newState
function api.ToggleTooltips()
    settings.master.tooltipsEnabled = not settings.master.tooltipsEnabled
    settings.save()
    return settings.master.tooltipsEnabled
end

--------------------------------------------------------------------------------
-- Grid Size Control
--------------------------------------------------------------------------------

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
-- Animation Duration Control
--------------------------------------------------------------------------------

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
--- Changes made to this table affect WindowUtils behavior.
--- Call settings.save() to persist changes.
---@return table
function api.GetSettings()
    return settings.master
end

--- Get the default settings table (read-only reference).
---@return table
function api.GetDefaults()
    return settings.defaults
end

--- Apply multiple settings at once.
---@param settingsTable table Key-value pairs of settings to apply
---@return boolean applied True if any settings were applied
function api.ApplySettings(settingsTable)
    if type(settingsTable) ~= "table" then return false end

    local applied = false
    for key, value in pairs(settingsTable) do
        if settings.master[key] ~= nil then
            settings.master[key] = value
            applied = true
        end
    end

    if applied then
        settings.save()
    end
    return applied
end

--- Reset all settings to defaults.
function api.ResetSettings()
    settings.reset()
end

--- Reload settings from file.
function api.ReloadSettings()
    settings.reload()
end

--- Save current settings to file.
---@return boolean success
function api.SaveSettings()
    return settings.save()
end

--------------------------------------------------------------------------------
-- Window Registration
--------------------------------------------------------------------------------

--- Register an external window with metadata.
---@param windowName string Window name string
---@param options table { hasCloseButton = boolean }
---@return boolean success
function api.RegisterWindow(windowName, options)
    if type(windowName) ~= "string" or windowName == "" then
        settings.debugPrint("RegisterWindow: invalid windowName (expected non-empty string)", true)
        return false
    end
    options = options or {}
    if type(options) ~= "table" then
        settings.debugPrint("RegisterWindow: invalid options (expected table)", true)
        return false
    end
    local result = registry.register(windowName, options)
    settings.debugPrint("RegisterWindow: '" .. windowName .. "' hasCloseButton=" .. tostring(options.hasCloseButton or false))
    return result
end

--- Unregister an external window.
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

--- Get all registered windows (debugging).
---@return table
function api.GetRegisteredWindows()
    return registry.getAll()
end

--------------------------------------------------------------------------------
-- Window Ignore Control
--------------------------------------------------------------------------------

--- Check if a window is ignored (excluded from all overrides).
---@param windowName string
---@return boolean
function api.IsWindowIgnored(windowName)
    return settings.isWindowIgnored(windowName)
end

--- Set or clear a window's ignored state.
---@param windowName string
---@param ignored boolean
function api.SetWindowIgnored(windowName, ignored)
    settings.setWindowIgnored(windowName, ignored)
end

return api
