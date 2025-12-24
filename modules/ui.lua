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
-- Grid Visualization
--------------------------------------------------------------------------------

local function drawGridVisualization()
    if not settings.master.gridVisualizationEnabled then return end

    -- If "show on drag only" is enabled, only show when a window is being dragged
    if settings.master.gridShowOnDragOnly and not core.isAnyWindowDragging() then
        return
    end

    local gridSize = settings.master.gridUnits * settings.GRID_UNIT_SIZE
    local drawList = ImGui.GetBackgroundDrawList()
    local displayWidth, displayHeight = GetDisplayResolution()
    local thickness = settings.master.gridLineThickness

    -- White with low alpha for visibility without obstruction
    local gridColor = ImGui.GetColorU32(1.0, 1.0, 1.0, 0.15)

    -- Draw vertical lines
    local x = 0
    while x <= displayWidth do
        ImGui.ImDrawListAddLine(drawList, x, 0, x, displayHeight, gridColor, thickness)
        x = x + gridSize
    end

    -- Draw horizontal lines
    local y = 0
    while y <= displayHeight do
        ImGui.ImDrawListAddLine(drawList, 0, y, displayWidth, y, gridColor, thickness)
        y = y + gridSize
    end
end

--------------------------------------------------------------------------------
-- Settings Window
--------------------------------------------------------------------------------

function ui.drawSettingsWindow()
    -- Draw grid visualization (independent of window visibility)
    drawGridVisualization()

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

        settings.master.gridVisualizationEnabled, changed = controls.Checkbox("Grid Visualization", settings.master.gridVisualizationEnabled, settings.defaults.gridVisualizationEnabled, "Show Grid Overlay", true)
        if changed then settings.save() end

        -- Grid visualization sub-options (indented, only when visualization enabled)
        if settings.master.gridVisualizationEnabled then
            ImGui.SameLine()
            settings.master.gridShowOnDragOnly, changed = controls.Checkbox("Show on Drag Only", settings.master.gridShowOnDragOnly, settings.defaults.gridShowOnDragOnly, "Only Show Grid While Dragging Windows", true)
            if changed then settings.save() end

            local thickness = settings.master.gridLineThickness
            thickness, changed = controls.SliderFloat(IconGlyphs.FormatLineWeight, "gridThickness", thickness, 0.5, 5.0, "%.1f px", nil, settings.defaults.gridLineThickness, "Grid Line Thickness")
            if changed then
                settings.master.gridLineThickness = thickness
                settings.save()
            end
        end

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
