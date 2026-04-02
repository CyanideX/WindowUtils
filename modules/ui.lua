------------------------------------------------------
-- WindowUtils - UI Module
-- Settings window using library components
------------------------------------------------------

local settings  = require("modules/settings")
local core      = require("modules/core")
local controls  = require("modules/controls")
local styles    = require("modules/styles")
local splitter  = require("modules/splitter")
local expand    = require("modules/expand")
local effects   = require("modules/effects")
local utils     = require("modules/utils")
local tooltips  = require("modules/tooltips")
local search    = require("modules/search")
local uidefs    = require("modules/uidefs")

local ui = {}

ui.state = {
    showWindow = false
}

ui.selectedSection = 1
ui.sections = {}

local CONTENT_BG = { 0.65, 0.7, 1.0, 0.0225 }

-- Shared bind context for all settings sections (created in ui.init)
local c

--------------------------------------------------------------------------------
-- Section 1: General
--------------------------------------------------------------------------------

local function drawGeneralSection()

    c:Header("Master Override", "general.override")
    ImGui.Dummy(0, 0)
    local _, changed = c:Checkbox("Enable Master Override", "enabled")
    if changed then core.invalidateGridCache() end

    c:SectionHeader("General", "general.settings", 10, 0)
    c:Checkbox("Show Tooltips", "tooltipsEnabled")

    ImGui.SameLine()
    _, changed = c:Checkbox("Debug Output", "debugOutput")
    if changed then settings.debugPrint("Debug Output Enabled") end

    c:SectionHeader("Experimental", "general.experimental", 10, 0)
    -- showExperimental drives the splitter toggle, not a simple settings key
    local toggleId = "gui_experimental"
    local isOpen = splitter.getToggle(toggleId) or false
    local newOpen
    newOpen, changed = c:Checkbox("Show Experimental Settings", "showExperimental")
    -- showExperimental is stored in settings.master but also drives the splitter
    if changed then
        splitter.setToggle(toggleId, settings.master.showExperimental)
    end
end

--------------------------------------------------------------------------------
-- Section 2: Grid
--------------------------------------------------------------------------------

local function drawGridSection()

    if not settings.master.enabled then ImGui.BeginDisabled() end

    c:Header("Grid Snapping", "grid")
    ImGui.Dummy(0, 0)
    c:Checkbox("Enable Grid Snapping", "gridEnabled")

    if not settings.master.gridEnabled then ImGui.BeginDisabled() end

    ImGui.SameLine()
    c:Checkbox("Snap Collapsed", "snapCollapsed")

    -- Grid scale: transform in uidefs maps gridUnits to/from scale index
    local validUnits = settings.getValidGridUnits(10)
    local maxScale = math.min(#validUnits, 5)
    local currentScale = 1
    for i, units in ipairs(validUnits) do
        if i <= maxScale and units == settings.master.gridUnits then currentScale = i end
    end
    local gridSize = validUnits[currentScale] * settings.GRID_UNIT_SIZE
    local _, scaleChanged = c:SliderInt(nil, "gridUnits", 1, maxScale, {
        format = "Scale %d (" .. gridSize .. "px)",
    })
    if scaleChanged then
        core.invalidateGridCache()
        if settings.master.autoAdjustOnResize then
            core.snapAllWindows()
        end
    end

    c:Checkbox("Auto Adjust", "autoAdjustOnResize")

    c:SectionHeader("Animation", "grid", 10, 0)
    c:Checkbox("Snap Animation", "animationEnabled")

    if not settings.master.animationEnabled then ImGui.BeginDisabled() end
    c:SliderFloat(nil, "animationDuration")
    c:Combo(nil, "easeFunction")
    if not settings.master.animationEnabled then ImGui.EndDisabled() end

    if not settings.master.gridEnabled then ImGui.EndDisabled() end
    if not settings.master.enabled then ImGui.EndDisabled() end
end

--------------------------------------------------------------------------------
-- Section 3: Visuals
--------------------------------------------------------------------------------

local function drawVisualsSection()
    local previewActive = false

    c:Header("Grid Visualization", "visuals")
    ImGui.Dummy(0, 0)

    if not settings.master.gridEnabled then
        controls.StatusBar("Grid Snapping Disabled - Preview Only")
    end

    c:Checkbox("Enable", "gridVisualizationEnabled")

    if not settings.master.gridVisualizationEnabled then ImGui.BeginDisabled() end

    ImGui.SameLine()
    c:Checkbox("On Drag Only ##grid", "gridShowOnDragOnly")

    if not settings.master.gridShowOnDragOnly then ImGui.BeginDisabled() end

    ImGui.SameLine()
    c:Checkbox("Guides", "gridGuidesEnabled")

    if not settings.master.gridGuidesEnabled then ImGui.BeginDisabled() end
    c:SliderFloat(nil, "gridGuidesDimming")
    previewActive = previewActive or ImGui.IsItemActive()
    if not settings.master.gridGuidesEnabled then ImGui.EndDisabled() end

    c:Checkbox("Feathered Grid", "gridFeatherEnabled")

    if not settings.master.gridFeatherEnabled then ImGui.BeginDisabled() end
    c:SliderFloat(nil, "gridFeatherRadius")
    previewActive = previewActive or ImGui.IsItemActive()
    c:SliderFloat(nil, "gridFeatherPadding")
    previewActive = previewActive or ImGui.IsItemActive()
    c:SliderFloat(nil, "gridFeatherCurve")
    previewActive = previewActive or ImGui.IsItemActive()
    if not settings.master.gridFeatherEnabled then ImGui.EndDisabled() end

    if not settings.master.gridShowOnDragOnly then ImGui.EndDisabled() end

    c:SliderFloat(nil, "gridLineThickness")
    previewActive = previewActive or ImGui.IsItemActive()
    c:ColorEdit4(nil, "gridLineColor")
    previewActive = previewActive or ImGui.IsItemActive()

    if not settings.master.gridVisualizationEnabled then ImGui.EndDisabled() end

    effects.state.previewActive = previewActive
end

--------------------------------------------------------------------------------
-- Section 4: Background
--------------------------------------------------------------------------------

local function drawBackgroundSection()

    c:Header("Dim Background", "background.dim")
    ImGui.Dummy(0, 0)
    c:Checkbox("Dim Background", "gridDimBackground")

    if not settings.master.gridDimBackground then ImGui.BeginDisabled() end
    ImGui.SameLine()
    c:Checkbox("On Drag Only##dimBg", "gridDimBackgroundOnDragOnly")
    c:SliderFloat(nil, "gridDimBackgroundOpacity")
    if not settings.master.gridDimBackground then ImGui.EndDisabled() end

    c:SectionHeader("Blur", "background.blur", 10, 0)

    local blurAvailable = effects.isBlurAvailable()

    if not blurAvailable then
        controls.StatusBar("XUtils Not Installed")
        ImGui.BeginDisabled()
    end

    -- Blur checkbox has side effects beyond simple save
    local blurValue, blurChanged = c:Checkbox("Blur on Overlay Open", "blurOnOverlayOpen")
    if blurChanged then
        if not blurAvailable then
            settings.master.blurOnOverlayOpen = false
            settings.markDirty()
        elseif settings.master.blurOnOverlayOpen and effects.isOverlayOpen()
           and not settings.master.blurOnDragOnly then
            effects.enableBlur()
        elseif not settings.master.blurOnOverlayOpen then
            effects.disableBlur()
        end
    end

    if not blurAvailable then
        ImGui.EndDisabled()
    end

    if not settings.master.blurOnOverlayOpen or not blurAvailable then
        ImGui.BeginDisabled()
    end

    ImGui.SameLine()
    local _, dragChanged = c:Checkbox("On Drag Only##blur", "blurOnDragOnly")
    if dragChanged then
        if not settings.master.blurOnDragOnly and effects.isOverlayOpen() then
            effects.enableBlur()
        elseif settings.master.blurOnDragOnly and not effects.blur.wasDragging then
            effects.disableBlur()
        end
    end

    local _
    _, changed = c:SliderFloat(nil, "blurIntensity")
    if changed then effects.updateBlurIntensity(settings.master.blurIntensity) end

    if not settings.master.blurOnOverlayOpen or not blurAvailable then
        ImGui.EndDisabled()
    end

    c:SectionHeader("Transition", "background.transition", 10, 0)
    c:SliderFloat(nil, "fadeInDuration")
    c:SliderFloat(nil, "fadeOutDuration")
    c:Checkbox("Quick Exit", "quickExit")
end

--------------------------------------------------------------------------------
-- Section 5: Experimental (bottom edge toggle)
--------------------------------------------------------------------------------

local function drawExperimentalSection()

    if not settings.master.enabled then ImGui.BeginDisabled() end

    c:Header("Experimental", "experimental")
    ImGui.Dummy(0, 0)

    local discoveryAvailable = core.isDiscoveryAvailable()

    if not discoveryAvailable then
        controls.StatusBar("Window Manager Not Installed")
        tooltips.Show("RedCetWM plugin is required to enable experimental settings.")
    end

    if discoveryAvailable then
        local _, changed = c:Checkbox("Override All Windows", "overrideAllWindows", {
            tooltip = "Apply Grid Snapping to All CET Windows\n(Requires Window Manager's RedCetWM plugin)\n\nRespects Window Manager hidden/locked states.\nMay conflict with windows using older versions of WindowUtils.",
            alwaysShowTooltip = true
        })
        if changed then core.invalidateGridCache() end
    end

    if settings.master.overrideAllWindows and discoveryAvailable then
        ImGui.SameLine()
        c:Checkbox("Scrollbar Style", "overrideStyling")
        ImGui.SameLine()
        c:Checkbox("No Scrollbar", "disableScrollbar")
        c:SliderFloat(nil, "probeInterval")

        c:Checkbox("Auto-Remove Empty Windows", "autoRemoveEmptyWindows", {
            tooltip = "Automatically stop managing windows that are no longer drawn by any mod.\n When disabled, empty shells instantly clear when clicked.\n\nMay cause windows to flicker (see Window Browser for fix).",
            alwaysShowTooltip = true
        })

        if settings.master.autoRemoveEmptyWindows then
            ImGui.SameLine()
            c:Checkbox("Batch Auto-Remove", "batchAutoRemove")
            c:SliderFloat(nil, "autoRemoveInterval")
        end

        c:Checkbox("Window Browser", "windowBrowserOpen")
    end

    if not settings.master.enabled then ImGui.EndDisabled() end
end

--------------------------------------------------------------------------------
-- Window Browser (separate ImGui window)
--------------------------------------------------------------------------------

local windowBrowser = require("modules/windowBrowser")

--------------------------------------------------------------------------------
-- Sidebar Navigation
--------------------------------------------------------------------------------

local function drawSidebar()
    local state = ui.searchState
    for _, entry in ipairs(ui.sections) do
        local dimmed = not state:isEmpty() and not state:categoryHasMatch(entry.category, ui.defs)
        if dimmed then ImGui.PushStyleVar(ImGuiStyleVar.Alpha, state.dimAlpha) end
        if controls.DynamicButton(entry.label, entry.icon, {
            style = ui.selectedSection == entry.page and "active" or "inactive",
            width = -1,
        }) then
            ui.selectedSection = entry.page
        end
        if dimmed then ImGui.PopStyleVar() end
    end
end

--------------------------------------------------------------------------------
-- Content Panel (dispatches to selected section)
--------------------------------------------------------------------------------

local function drawContentPanel()
    if controls.BeginFillChild("gui_section_scroll", { bg = CONTENT_BG }) then
        if ui.selectedSection == 1 then
            drawGeneralSection()
        elseif ui.selectedSection == 2 then
            drawGridSection()
        elseif ui.selectedSection == 3 then
            drawVisualsSection()
        elseif ui.selectedSection == 4 then
            drawBackgroundSection()
        end
    end
    controls.EndFillChild("gui_section_scroll")
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local GUI_WINDOW_NAME = settings.NAME

function ui.init()
    local ic = IconGlyphs or {}
    ui.sections = {
        { label = "General",    icon = ic.Tune        or "?", page = 1, category = "general" },
        { label = "Grid",       icon = ic.Grid        or "?", page = 2, category = "grid" },
        { label = "Visuals",    icon = ic.Eye         or "?", page = 3, category = "visuals" },
        { label = "Background", icon = ic.Brightness6 or "?", page = 4, category = "background" },
    }
    ui.searchState = search.new("wu_settings")
    ui.defs = uidefs.init()
    c = controls.bind(settings.master, settings.defaults, settings.markDirty, {
        search = ui.searchState, defs = ui.defs,
    })
    ui.state.showWindow = settings.master.showGuiWindow
end

function ui.drawWindow()
    if not ui.state.showWindow then return end

    local displayW, displayH = GetDisplayResolution()
    local padX = ImGui.GetStyle().WindowPadding.x * 2
    local padY2 = ImGui.GetStyle().WindowPadding.y * 2
    local pctMinW = displayW * 0.25
    local pctMinH = displayH * 0.30
    local innerMinW = splitter.getMinSize("gui_inner") or 0
    local outerMinH = splitter.getMinSize("gui_outer") or 0
    local minW = math.max(innerMinW + padX, pctMinW)
    local minH = math.max(outerMinH + padY2, pctMinH)

    ImGui.SetNextWindowSize(displayW * 0.30, displayH * 0.40, ImGuiCond.FirstUseEver)

    local maxHPct = splitter.getExpandConstraint("gui_experimental")
    local maxH = maxHPct and (displayH * maxHPct / 100) or (displayH * 0.5)
    core.setNextWindowSizeConstraints(minW, minH, displayW * 0.45, maxH, GUI_WINDOW_NAME)

    if not ImGui.Begin(GUI_WINDOW_NAME, ImGuiWindowFlags.NoScrollbar) then
        core.update(GUI_WINDOW_NAME, {
            gridEnabled = settings.master.gridEnabled,
            animationEnabled = settings.master.animationEnabled,
            animationDuration = settings.master.animationDuration,
            treatAllDragsAsWindowDrag = true
        })
        ImGui.End()
        return
    end

    local sidebarMaxW = math.floor(displayW * 0.15)

    splitter.toggle("gui_experimental", {
        { content = function()
            controls.Panel("gui_experimental_panel", function()
                drawExperimentalSection()
                local padY = ImGui.GetStyle().WindowPadding.y
                expand.setMeasuredSize("gui_experimental", ImGui.GetCursorPosY() + padY)
            end)
        end },
        { content = function()
            splitter.multi("gui_inner", {
                { maxWidth = sidebarMaxW, content = function()
                    controls.Panel("gui_nav", function()
                        drawSidebar()
                    end)
                end },
                { content = function()
                    controls.Column("gui_right", {
                        { auto = true, content = function()
                            controls.Panel("gui_search", function()
                                search.SearchBar(ui.searchState, { cols = 12 })
                            end, { height = "auto" })
                        end },
                        { flex = 1, content = function()
                            drawContentPanel()
                        end },
                    })
                end },
            }, { direction = "horizontal", defaultPcts = { 0.3, 0.7 } })
        end },
    }, {
        side = "bottom",
        size = 200,
        defaultOpen = settings.master.showExperimental,
        expand = true,
        sizeMode = "auto",
        windowName = GUI_WINDOW_NAME,
        normalConstraintPct = 50,
        toggleOnClick = true,
    })

    expand.applyWindowSize(GUI_WINDOW_NAME)

    local expOpen = splitter.getToggle("gui_experimental") or false
    if expOpen ~= settings.master.showExperimental then
        settings.master.showExperimental = expOpen
        settings.markDirty()
    end

    core.update(GUI_WINDOW_NAME, {
        gridEnabled = settings.master.gridEnabled,
        animationEnabled = settings.master.animationEnabled,
        animationDuration = settings.master.animationDuration,
        treatAllDragsAsWindowDrag = true
    })

    ImGui.End()

    windowBrowser.draw()
end

function ui.show()
    ui.state.showWindow = true
    settings.master.showGuiWindow = true
    settings.save()
end

function ui.hide()
    ui.state.showWindow = false
    settings.master.showGuiWindow = false
    settings.save()
end

function ui.toggle()
    ui.state.showWindow = not ui.state.showWindow
    settings.master.showGuiWindow = ui.state.showWindow
    settings.save()
end

---@return boolean
function ui.isVisible()
    return ui.state.showWindow
end

--- Clear search states on overlay close.
function ui.onOverlayClose()
    if ui.searchState then ui.searchState:clear() end
    windowBrowser.clearSearch()
end

return ui
