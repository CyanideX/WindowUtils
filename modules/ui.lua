------------------------------------------------------
-- WindowUtils - UI Module
-- Settings window and GUI components
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")

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
        settings.master.enabled, changed = ImGui.Checkbox("Enable Master Override", settings.master.enabled)
        if changed then settings.save() end

        if settings.master.enabled then
            ImGui.TextColored(0.5, 0.8, 0.5, 1.0, "Master settings active - overriding all mods")
        else
            ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "Master settings disabled - mods use their own")
        end

        ImGui.Separator()
        ImGui.Spacing()

        -- Settings (always editable, but only apply when enabled)
        if not settings.master.enabled then
            ImGui.BeginDisabled()
        end

        -- Grid settings
        ImGui.Text("Grid")
        settings.master.gridEnabled, changed = ImGui.Checkbox("Grid Snapping", settings.master.gridEnabled)
        if changed then settings.save() end

        ImGui.SetNextItemWidth(120)
        local gridSize = settings.master.gridSize
        gridSize, changed = ImGui.SliderInt("Grid Size", gridSize, 5, 50)
        if changed then
            settings.master.gridSize = gridSize
            settings.save()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Animation settings
        ImGui.Text("Animation")
        settings.master.animationEnabled, changed = ImGui.Checkbox("Snap Animation", settings.master.animationEnabled)
        if changed then settings.save() end

        ImGui.SetNextItemWidth(120)
        local duration = settings.master.animationDuration
        duration, changed = ImGui.SliderFloat("Duration", duration, 0.05, 0.5, "%.2f s")
        if changed then
            settings.master.animationDuration = duration
            settings.save()
        end

        ImGui.SetNextItemWidth(120)
        local currentIndex = findEasingIndex(settings.master.easeFunction)
        local newIndex
        newIndex, changed = ImGui.Combo("Easing", currentIndex, settings.easingNames, #settings.easingNames)
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
