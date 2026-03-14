------------------------------------------------------
-- WindowUtils - External API Module
-- Clean interface for other mods to control WindowUtils
--
-- Usage:
--   local wu = GetMod("WindowUtils")
--   if wu then
--       wu.API.Toggle()                    -- Toggle settings window
--       wu.API.EnableGrid()                -- Enable grid snapping
--       print(wu.API.IsEnabled())          -- Check master override status
--   end
--
-- For advanced settings not exposed as functions, use GetSettings():
--   local s = wu.API.GetSettings()
--   s.snapCollapsed = true                 -- Snap collapsed windows
--   s.blurOnOverlayOpen = true             -- Enable background blur
--   s.blurOnDragOnly = false               -- Blur always when overlay open
--   s.blurIntensity = 0.005                -- Blur strength (0.001-0.02)
--   s.gridVisualizationEnabled = true      -- Show grid overlay
--   s.gridDimBackground = true             -- Dim background behind grid
--   s.gridDimBackgroundOpacity = 0.10      -- Dimming opacity (0-1)
--   s.overrideAllWindows = false           -- Apply to all CET windows (experimental)
--
-- Note: After modifying settings via GetSettings(), call settings.save()
-- if you need persistence, or the changes will only last until restart.
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")
local ui = require("modules/ui")

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

--- Enable the master override.
function api.Enable()
    settings.master.enabled = true
    settings.save()
end

--- Disable the master override.
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

--- Enable grid snapping.
function api.EnableGrid()
    settings.master.gridEnabled = true
    settings.save()
end

--- Disable grid snapping.
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

--- Enable snap animation.
function api.EnableAnimation()
    settings.master.animationEnabled = true
    settings.save()
end

--- Disable snap animation.
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

--- Enable tooltips.
function api.EnableTooltips()
    settings.master.tooltipsEnabled = true
    settings.save()
end

--- Disable tooltips.
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

return api
