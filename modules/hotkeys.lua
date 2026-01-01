------------------------------------------------------
-- WindowUtils - Hotkeys Module
-- Registers keyboard shortcuts for WindowUtils functions
------------------------------------------------------

local ui = require("modules/ui")

local hotkeys = {}

--- Register all hotkeys
function hotkeys.register()
    registerHotkey("ToggleWindowUtilsGUI", "Toggle Window Utils GUI", function()
        ui.toggle()
    end)
end

return hotkeys
