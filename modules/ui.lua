------------------------------------------------------
-- WindowUtils - UI Module
-- Settings window and GUI components
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")
local controls = require("modules/controls")

local ui = {}

-- GUI state
ui.state = {
    isOverlayOpen = false,
    showWindow = false
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function findEasingIndex(name)
    for i, n in ipairs(settings.easingNames) do
        if n == name then
            return i - 1  -- ImGui combo is 0-indexed
        end
    end
    return 3  -- default to easeInOut
end

--------------------------------------------------------------------------------
-- Settings Window
--------------------------------------------------------------------------------

function ui.drawSettingsWindow()
    if not ui.state.showWindow then return end

    ImGui.SetNextWindowSize(320, 280, ImGuiCond.FirstUseEver)
    ui.state.showWindow = ImGui.Begin("WindowUtils Settings", ui.state.showWindow, ImGuiWindowFlags.NoCollapse)

    if ui.state.showWindow then
        -- Master override toggle
        local changed
        settings.master.enabled, changed = controls.Checkbox("Enable Master Override", settings.master.enabled)
        if changed then settings.save() end

        if settings.master.enabled then
            controls.TextSuccess("Master settings active - overriding all mods")
        else
            controls.TextMuted("Master settings disabled - mods use their own")
        end

        -- Settings (always editable, but only apply when enabled)
        if not settings.master.enabled then
            ImGui.BeginDisabled()
        end

        -- General settings
        controls.SectionHeader("General", 10, 0)
        settings.master.tooltipsEnabled, changed = controls.Checkbox("Show Tooltips", settings.master.tooltipsEnabled, settings.defaults.tooltipsEnabled, "Show Tooltips on Hover", true)
        if changed then settings.save() end

        -- Grid settings
        controls.SectionHeader("Grid", 10, 0)
        settings.master.gridEnabled, changed = controls.Checkbox("Grid Snapping", settings.master.gridEnabled, settings.defaults.gridEnabled, "Snap Windows to Grid When Released")
        if changed then settings.save() end

        local gridUnits = settings.master.gridUnits
        local unitFormat = gridUnits == 1 and "%d Unit" or "%d Units"
        gridUnits, changed = controls.SliderInt(IconGlyphs.Grid, "gridUnits", gridUnits, 1, 10, unitFormat, nil, settings.defaults.gridUnits, "Grid Units (1 Unit = 20px).")
        if changed then
            settings.master.gridUnits = gridUnits
            settings.save()
        end

        -- Animation settings
        controls.SectionHeader("Animation", 10, 0)
        settings.master.animationEnabled, changed = controls.Checkbox("Snap Animation", settings.master.animationEnabled, settings.defaults.animationEnabled, "Animate Window Snapping")
        if changed then settings.save() end

        local duration = settings.master.animationDuration
        duration, changed = controls.SliderFloat(IconGlyphs.TimerOutline, "animDuration", duration, 0.05, 0.5, "%.2f s", nil, settings.defaults.animationDuration, "Animation Duration")
        if changed then
            settings.master.animationDuration = duration
            settings.save()
        end

        local currentIndex = findEasingIndex(settings.master.easeFunction)
        local defaultEasingIndex = findEasingIndex(settings.defaults.easeFunction)
        local newIndex
        newIndex, changed = controls.Combo(IconGlyphs.SineWave, "easing", currentIndex, settings.easingNames, nil, defaultEasingIndex, "Easing Function")
        if changed then
            settings.master.easeFunction = settings.easingNames[newIndex + 1]
            settings.save()
        end

        if not settings.master.enabled then
            ImGui.EndDisabled()
        end

        -- Update with WindowUtils (for this window)
        core.update("WindowUtils Settings", {
            gridEnabled = settings.master.gridEnabled,
            animationEnabled = settings.master.animationEnabled,
            animationDuration = settings.master.animationDuration
        })
    end

    ImGui.End()
end

--------------------------------------------------------------------------------
-- Window Control API
--------------------------------------------------------------------------------

function ui.show()
    ui.state.showWindow = true
end

function ui.hide()
    ui.state.showWindow = false
end

function ui.toggle()
    ui.state.showWindow = not ui.state.showWindow
end

function ui.isVisible()
    return ui.state.showWindow
end

return ui
