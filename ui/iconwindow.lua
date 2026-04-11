------------------------------------------------------
-- WindowUtils - Icon Browser Window
-- Standalone window for browsing CET icon glyphs
------------------------------------------------------

local settings    = require("core/settings")
local core        = require("core/core")
local iconbrowser = require("modules/iconbrowser")
local search      = require("modules/search")

local iconwindow = {}

local WINDOW_NAME = "Icon Browser##WindowUtils"

-- Persistent selection for the standalone window
local selected = nil

function iconwindow.draw()
    if not settings.master.iconBrowserOpen then return end

    local dw, dh = GetDisplayResolution()
    ImGui.SetNextWindowSize(dw * 0.20, dh * 0.50, ImGuiCond.FirstUseEver)
    core.setNextWindowSizeConstraintsPercent(12, 20, 40, 80, WINDOW_NAME)

    if not ImGui.Begin(WINDOW_NAME) then
        core.update(WINDOW_NAME, {
            gridEnabled = settings.master.gridEnabled,
            animationEnabled = settings.master.animationEnabled,
            animationDuration = settings.master.animationDuration,
            treatAllDragsAsWindowDrag = true,
        })
        ImGui.End()
        return
    end

    selected = iconbrowser.draw("iconwindow", selected, function(name, glyph)
        selected = name
    end, { showSearch = true, showPreview = true })

    core.update(WINDOW_NAME, {
        gridEnabled = settings.master.gridEnabled,
        animationEnabled = settings.master.animationEnabled,
        animationDuration = settings.master.animationDuration,
        treatAllDragsAsWindowDrag = true,
    })

    ImGui.End()
end

function iconwindow.clearSearch()
    local state = search.get("iconbrowser_iconwindow")
    if state then state:clear() end
end

return iconwindow
