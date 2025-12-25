------------------------------------------------------
-- WindowUtils - External API Module
-- Clean interface for other mods to control WindowUtils
-- Usage: local wu = GetMod("WindowUtils"); if wu then wu.API.Toggle() end
-- print(GetMod("WindowUtils").api.IsEnabled())
------------------------------------------------------

local settings = require("modules/settings")
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

function api.SetEnabled(enabled)
    settings.master.enabled = enabled
    settings.save()
end

--------------------------------------------------------------------------------
-- Grid Control
--------------------------------------------------------------------------------

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

function api.SetGridEnabled(enabled)
    settings.master.gridEnabled = enabled
    settings.save()
end

function api.ToggleGrid()
    settings.master.gridEnabled = not settings.master.gridEnabled
    settings.save()
    return settings.master.gridEnabled
end

--------------------------------------------------------------------------------
-- Animation Control
--------------------------------------------------------------------------------

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

function api.SetAnimationEnabled(enabled)
    settings.master.animationEnabled = enabled
    settings.save()
end

function api.ToggleAnimation()
    settings.master.animationEnabled = not settings.master.animationEnabled
    settings.save()
    return settings.master.animationEnabled
end

--------------------------------------------------------------------------------
-- Tooltips Control
--------------------------------------------------------------------------------

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

function api.SetTooltipsEnabled(enabled)
    settings.master.tooltipsEnabled = enabled
    settings.save()
end

function api.ToggleTooltips()
    settings.master.tooltipsEnabled = not settings.master.tooltipsEnabled
    settings.save()
    return settings.master.tooltipsEnabled
end

--------------------------------------------------------------------------------
-- Settings Access
--------------------------------------------------------------------------------

function api.GetSettings()
    return settings.master
end

return api
