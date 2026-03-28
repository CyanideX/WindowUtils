------------------------------------------------------
-- WindowUtils - UI Module
-- Settings window using library components
------------------------------------------------------

local settings  = require("modules/settings")
local core      = require("modules/core")
local controls  = require("modules/controls")
local styles    = require("modules/styles")
local splitter  = require("modules/splitter")
local effects   = require("modules/effects")
local discovery = require("modules/discovery")
local utils     = require("modules/utils")
local tooltips  = require("modules/tooltips")

local ui = {}

ui.state = {
    showWindow = false
}

ui.selectedSection = 1

ui.sections = {}

-- Measured each frame, used for experimental panel sizing next frame
local cachedExperimentalH = nil

local CONTENT_BG = { 0.65, 0.7, 1.0, 0.0225 }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function findEasingIndex(key)
    for i, k in ipairs(settings.easingKeys) do
        if k == key then return i - 1 end
    end
    return 3 -- default: easeInOut
end

--------------------------------------------------------------------------------
-- Section 1: General
--------------------------------------------------------------------------------

local function drawGeneralSection()
    local c = controls.bind(settings.master, settings.defaults, settings.save)

    ImGui.Text("Master Override")
    ImGui.Dummy(0, 0)
    local _, changed = c:Checkbox("Enable Master Override", "enabled", {
        tooltip = "Override all mod settings with master configuration"
    })
    if changed then core.invalidateGridCache() end

    controls.SectionHeader("General", 10, 0)
    c:Checkbox("Show Tooltips", "tooltipsEnabled", {
        tooltip = "Show Tooltips on Hover",
        alwaysShowTooltip = true
    })

    ImGui.SameLine()
    _, changed = c:Checkbox("Debug Output", "debugOutput", {
        tooltip = "Print Debug Messages to Console",
        alwaysShowTooltip = true
    })
    if changed then settings.debugPrint("Debug Output Enabled") end

    controls.SectionHeader("Experimental", 10, 0)
    local toggleId = "gui_outer_tgl_trail"
    local isOpen = splitter.getToggle(toggleId) or false
    local newOpen
    newOpen, changed = controls.Checkbox("Show Experimental Settings", isOpen, {
        tooltip = "Expand the Experimental panel at the bottom of the window\n\nYou can also toggle it by clicking the arrow at the bottom edge"
    })
    if changed then
        splitter.setToggle(toggleId, newOpen)
    end
end

--------------------------------------------------------------------------------
-- Section 2: Grid
--------------------------------------------------------------------------------

local function drawGridSection()
    local c = controls.bind(settings.master, settings.defaults, settings.save)

    if not settings.master.enabled then ImGui.BeginDisabled() end

    ImGui.Text("Grid Snapping")
    ImGui.Dummy(0, 0)
    c:Checkbox("Enable Grid Snapping", "gridEnabled", {
        tooltip = "Snap Windows to Grid When Released"
    })

    if not settings.master.gridEnabled then ImGui.BeginDisabled() end

    ImGui.SameLine()
    c:Checkbox("Snap Collapsed", "snapCollapsed", {
        tooltip = "Snap Collapsed Windows When Dragged"
    })

    local validUnits = settings.getValidGridUnits(10)
    local maxScale = math.min(#validUnits, 5)
    local currentScale = 1
    local defaultScale = 1

    for i, units in ipairs(validUnits) do
        if i <= maxScale then
            if units == settings.master.gridUnits then currentScale = i end
            if units == settings.defaults.gridUnits then defaultScale = i end
        end
    end

    local gridSize = validUnits[currentScale] * settings.GRID_UNIT_SIZE
    local newScale, changed = controls.SliderInt("Grid", "gridScale", currentScale, 1, maxScale, {
        format = "Scale %d (" .. gridSize .. "px)",
        default = defaultScale,
        tooltip = "Grid Scale (maps to valid grid sizes for your resolution)"
    })
    if changed then
        settings.master.gridUnits = validUnits[newScale]
        settings.save()
        core.invalidateGridCache()
        if settings.master.autoAdjustOnResize then
            core.snapAllWindows()
        end
    end

    c:Checkbox("Auto Adjust", "autoAdjustOnResize", {
        tooltip = "Automatically re-snap all windows to the new grid when scale changes"
    })

    controls.SectionHeader("Animation", 10, 0)
    c:Checkbox("Snap Animation", "animationEnabled", {
        tooltip = "Animate Window Snapping"
    })

    if not settings.master.animationEnabled then ImGui.BeginDisabled() end

    c:SliderFloat("TimerOutline", "animationDuration", 0.05, 1.0, {
        format = "%.2f s",
        tooltip = "Animation Duration"
    })

    c:Combo("SineWave", "easeFunction", settings.easingNames, {
        tooltip = "Easing Function",
        transform = {
            read  = function(v) return findEasingIndex(v) end,
            write = function(v) return settings.easingKeys[v + 1] end,
        },
    })

    if not settings.master.animationEnabled then ImGui.EndDisabled() end
    if not settings.master.gridEnabled then ImGui.EndDisabled() end
    if not settings.master.enabled then ImGui.EndDisabled() end
end

--------------------------------------------------------------------------------
-- Section 3: Visuals
--------------------------------------------------------------------------------

local function drawVisualsSection()
    local c = controls.bind(settings.master, settings.defaults, settings.save)
    local previewActive = false

    ImGui.Text("Grid Visualization")
    ImGui.Dummy(0, 0)

    if not settings.master.gridEnabled then
        controls.StatusBar("Grid Snapping Disabled - Preview Only")
    end

    c:Checkbox("Enable", "gridVisualizationEnabled", {
        tooltip = "Display Grid Lines on Screen"
    })

    if not settings.master.gridVisualizationEnabled then ImGui.BeginDisabled() end

    ImGui.SameLine()
    c:Checkbox("On Drag Only ##grid", "gridShowOnDragOnly", {
        tooltip = "Only Show Grid While Dragging Windows"
    })

    if not settings.master.gridShowOnDragOnly then ImGui.BeginDisabled() end

    ImGui.SameLine()
    c:Checkbox("Guides", "gridGuidesEnabled", {
        tooltip = "Highlight Alignment Lines at Window Edges\n(Dims full grid, shows full-brightness lines at snapped edges)\nCan be combined with Feathered Grid\n\nTip: Hold Shift while dragging to lock movement to one axis"
    })

    if not settings.master.gridGuidesEnabled then ImGui.BeginDisabled() end
    c:SliderFloat("Brightness5", "gridGuidesDimming", 0, 1, {
        percent = true,
        tooltip = "Grid Dimming (opacity of grid lines when guides active)"
    })
    previewActive = previewActive or ImGui.IsItemActive()
    if not settings.master.gridGuidesEnabled then ImGui.EndDisabled() end

    c:Checkbox("Feathered Grid", "gridFeatherEnabled", {
        tooltip = "Show Grid Only Around Active Window"
    })

    if not settings.master.gridFeatherEnabled then ImGui.BeginDisabled() end
    c:SliderFloat("BlurRadial", "gridFeatherRadius", 200, 1200, {
        format = "%.0f px",
        tooltip = "Feather Radius (distance where grid fades to zero)"
    })
    previewActive = previewActive or ImGui.IsItemActive()
    c:SliderFloat("SelectionEllipse", "gridFeatherPadding", 0, 120, {
        format = "%.0f px",
        tooltip = "Window Padding (area around window with full opacity)"
    })
    previewActive = previewActive or ImGui.IsItemActive()
    c:SliderFloat("ChartBellCurveCumulative", "gridFeatherCurve", 1.0, 12.0, {
        format = "%.1f",
        tooltip = "Feather Curve (higher = faster drop near window, gradual fade at edges)"
    })
    previewActive = previewActive or ImGui.IsItemActive()
    if not settings.master.gridFeatherEnabled then ImGui.EndDisabled() end

    if not settings.master.gridShowOnDragOnly then ImGui.EndDisabled() end

    c:SliderFloat("FormatLineWeight", "gridLineThickness", 0.5, 5.0, {
        format = "%.1f px",
        tooltip = "Grid Line Thickness"
    })
    previewActive = previewActive or ImGui.IsItemActive()
    c:ColorEdit4("Palette", "gridLineColor", {
        tooltip = "Grid Line Color"
    })
    previewActive = previewActive or ImGui.IsItemActive()

    if not settings.master.gridVisualizationEnabled then ImGui.EndDisabled() end

    effects.state.previewActive = previewActive
end

--------------------------------------------------------------------------------
-- Section 4: Background
--------------------------------------------------------------------------------

local function drawBackgroundSection()
    local c = controls.bind(settings.master, settings.defaults, settings.save)

    ImGui.Text("Dim Background")
    ImGui.Dummy(0, 0)
    c:Checkbox("Dim Background", "gridDimBackground", {
        tooltip = "Darken Screen When Grid Overlay Visible"
    })

    if not settings.master.gridDimBackground then ImGui.BeginDisabled() end
    ImGui.SameLine()
    c:Checkbox("On Drag Only##dimBg", "gridDimBackgroundOnDragOnly", {
        tooltip = "Only Dim Background While Dragging Windows"
    })
    c:SliderFloat("Brightness4", "gridDimBackgroundOpacity", 0.1, 0.9, {
        format = "%.2f",
        tooltip = "Background Dimming Opacity"
    })
    if not settings.master.gridDimBackground then ImGui.EndDisabled() end

    controls.SectionHeader("Blur", 10, 0)

    local blurAvailable = effects.isBlurAvailable()

    if not blurAvailable then
        controls.StatusBar("XUtils Not Installed")
        ImGui.BeginDisabled()
    end

    local blurValue = blurAvailable and settings.master.blurOnOverlayOpen or false
    local changed
    blurValue, changed = controls.Checkbox("Blur on Overlay Open", blurValue, {
        default = settings.defaults.blurOnOverlayOpen,
        tooltip = blurAvailable
            and "Blur Game Background When CET Overlay Opens"
            or "Download the required library files"
    })
    if changed and blurAvailable then
        settings.master.blurOnOverlayOpen = blurValue
        settings.save()
        if settings.master.blurOnOverlayOpen and effects.state.isOverlayOpen
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
    local newBlurDragOnly
    newBlurDragOnly, changed = controls.Checkbox("On Drag Only##blur",
        settings.master.blurOnDragOnly, {
            default = settings.defaults.blurOnDragOnly,
            tooltip = "Only Blur While Dragging Windows"
        })
    if changed then
        settings.master.blurOnDragOnly = newBlurDragOnly
        settings.save()
        if not settings.master.blurOnDragOnly and effects.state.isOverlayOpen then
            effects.enableBlur()
        elseif settings.master.blurOnDragOnly and not effects.blur.wasDragging then
            effects.disableBlur()
        end
    end

    local _
    _, changed = c:SliderFloat("Blur", "blurIntensity", 0.001, 0.02, {
        format = "%.4f",
        tooltip = "Blur Intensity"
    })
    if changed then effects.updateBlurIntensity(settings.master.blurIntensity) end

    if not settings.master.blurOnOverlayOpen or not blurAvailable then
        ImGui.EndDisabled()
    end

    controls.SectionHeader("Transition", 10, 0)
    c:SliderFloat("TransitionMasked", "fadeInDuration", 0.05, 1.0, {
        format = "%.2f s",
        tooltip = "Fade In Duration"
    })
    c:SliderFloat("TransitionMasked", "fadeOutDuration", 0.05, 1.0, {
        format = "%.2f s",
        tooltip = "Fade Out Duration"
    })
    c:Checkbox("Quick Exit", "quickExit", {
        tooltip = "Faster dim and blur transition when closing CET overlay"
    })
end

--------------------------------------------------------------------------------
-- Section 5: Experimental (bottom edge toggle)
--------------------------------------------------------------------------------

local function drawExperimentalSection()
    local c = controls.bind(settings.master, settings.defaults, settings.save)

    if not settings.master.enabled then ImGui.BeginDisabled() end

    ImGui.Text("Experimental")
    ImGui.Dummy(0, 0)

    local discoveryAvailable = core.isDiscoveryAvailable()

    if not discoveryAvailable then
        controls.StatusBar("RedCetWM Plugin Not Installed")
    end

    if not discoveryAvailable then ImGui.BeginDisabled() end

    local _, changed = c:Checkbox("Override All Windows", "overrideAllWindows", {
        tooltip = "Apply Grid Snapping to All CET Windows\n(Requires Window Manager's RedCetWM plugin)\n\nRespects Window Manager hidden/locked states.\nMay conflict with windows using older versions of WindowUtils.",
        alwaysShowTooltip = true
    })
    if changed then core.invalidateGridCache() end

    if not discoveryAvailable then ImGui.EndDisabled() end

    if settings.master.overrideAllWindows and discoveryAvailable then
        c:SliderFloat("TimerSand", "probeInterval", 0.1, 5.0, {
            format = "%.1f s",
            tooltip = "Re-Probe Interval\nHow often to scan for newly-drawn windows"
        })

        c:Checkbox("Auto-Remove Empty Windows", "autoRemoveEmptyWindows", {
            tooltip = "Automatically stop managing windows that are no longer drawn by any mod.\n When disabled, empty shells instantly clear when clicked.\n\nMay cause windows to flicker (see Window Browser for fix).",
            alwaysShowTooltip = true
        })

        if settings.master.autoRemoveEmptyWindows then
            ImGui.SameLine()
            c:Checkbox("Batch Auto-Remove", "batchAutoRemove", {
                tooltip = "Check all windows simultaneously each interval\nWhen off, checks one window per interval (round-robin)"
            })

            c:SliderFloat("TimerSand", "autoRemoveInterval", 0.1, 5.0, {
                format = "%.1f s",
                tooltip = "Auto-Remove Interval\nHow often to check for empty window shells\nLower = faster cleanup, slightly more processing"
            })
        end

        c:Checkbox("Window Browser", "windowBrowserOpen", {
            tooltip = "Browse all discovered CET windows\n\nUse the toggle to fix windows that flicker and\ncan't be closed or collapsed properly.\nHide windows you don't need to declutter the list."
        })
    end

    if not settings.master.enabled then ImGui.EndDisabled() end
end

--------------------------------------------------------------------------------
-- Window Browser (separate ImGui window)
--------------------------------------------------------------------------------

local windowBrowserSearch = ""

local function drawWindowBrowserEntry(name, category)
    local ic = IconGlyphs or {}
    local override = settings.master.windowOverrides[name]
    local btnW = utils.minIconButtonWidth()
    local isHidden = (category == "hidden")
    local isIgnored = (category == "ignored")

    -- pOpen toggle
    local pOpenIcon = override and (ic.ToggleSwitch or "On") or (ic.ToggleSwitchOffOutline or "Off")
    if isHidden or isIgnored then
        ImGui.BeginDisabled()
        controls.Button(pOpenIcon .. "##popen_" .. name, "disabled", btnW)
        ImGui.EndDisabled()
        if isIgnored then
            tooltips.Show("Unignore this window to change Close Button setting")
        else
            tooltips.Show("Unhide this window to change Close Button setting")
        end
    else
        if controls.ToggleButton(pOpenIcon .. "##popen_" .. name, override, btnW) then
            if override then
                settings.setWindowOverride(name, nil)
            else
                settings.setWindowOverride(name, true)
            end
        end
        tooltips.Show(override
            and "Close Button enabled\nClick to disable"
            or "Enable Close Button\nAdds an X button to this window's title bar")
    end

    ImGui.SameLine()

    -- Ignore toggle
    local ignoreIcon = isIgnored and (ic.Cancel or "X") or (ic.CircleOffOutline or "-")
    local ignoreStyle = isIgnored and "danger" or "inactive"
    if controls.Button(ignoreIcon .. "##ign_" .. name, ignoreStyle, btnW) then
        settings.setWindowIgnored(name, not isIgnored)
    end
    tooltips.Show(isIgnored
        and "Stop ignoring this window\nWindowUtils will manage it again"
        or "Ignore this window completely\nWindowUtils will not apply any overrides")

    ImGui.SameLine()

    -- Visibility toggle (disabled when ignored)
    local eyeIcon = isHidden and (ic.EyeOff or "H") or (ic.EyeOutline or "V")
    local eyeStyle = "inactive"
    if isIgnored then
        ImGui.BeginDisabled()
        controls.Button(eyeIcon .. "##vis_" .. name, "disabled", btnW)
        ImGui.EndDisabled()
        tooltips.Show("Unignore this window to change visibility")
    else
        if controls.Button(eyeIcon .. "##vis_" .. name, eyeStyle, btnW) then
            if not isHidden then
                settings.setWindowOverride(name, nil)
            end
            settings.setWindowHidden(name, not isHidden)
        end
        tooltips.Show(isHidden
            and "Show this window in the browser"
            or "Hide this window from the browser\nMoves it to the Hidden section")
    end

    ImGui.SameLine()

    -- Window name (truncated to remaining width)
    local availWidth = ImGui.GetContentRegionAvail()
    local displayName, wasTruncated = utils.truncateText(name, availWidth)

    if isHidden or isIgnored then
        styles.PushTextMuted()
        ImGui.Text(displayName)
        styles.PopTextMuted()
    else
        ImGui.Text(displayName)
    end

    if wasTruncated and ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(name)
        ImGui.EndTooltip()
    end
end

local WB_WINDOW_NAME = "Window Browser##WindowUtils"

local function drawWindowOverridePanel()
    if not settings.master.windowBrowserOpen then return end
    if not settings.master.overrideAllWindows then return end

    local dw, dh = GetDisplayResolution()
    ImGui.SetNextWindowSize(dw * 0.18, dh * 0.35, ImGuiCond.FirstUseEver)
    core.setNextWindowSizeConstraintsPercent(10, 15, 30, 60, WB_WINDOW_NAME)

    if not ImGui.Begin(WB_WINDOW_NAME) then
        ImGui.End()
        return
    end

    local ic = IconGlyphs or {}
    windowBrowserSearch = controls.InputText(
        ic.Magnify or nil, "wb_search", windowBrowserSearch, { maxLength = 128 }
    )

    local filter = windowBrowserSearch:lower()
    local windows = discovery.getActiveWindows()
    local visibleWindows = {}
    local hiddenWindows = {}
    local ignoredWindows = {}

    for _, windowInfo in ipairs(windows) do
        local name = windowInfo.name
        if filter == "" or name:lower():find(filter, 1, true) then
            if settings.isWindowIgnored(name) then
                ignoredWindows[#ignoredWindows + 1] = name
            elseif settings.isWindowHidden(name) then
                hiddenWindows[#hiddenWindows + 1] = name
            else
                visibleWindows[#visibleWindows + 1] = name
            end
        end
    end

    if controls.BeginFillChild("wb_list", { bg = CONTENT_BG }) then
        for _, name in ipairs(visibleWindows) do
            drawWindowBrowserEntry(name, "visible")
        end

        if #hiddenWindows > 0 then
            ImGui.Separator()
            if ImGui.CollapsingHeader("Hidden") then
                for _, name in ipairs(hiddenWindows) do
                    drawWindowBrowserEntry(name, "hidden")
                end
            end
        end

        if #ignoredWindows > 0 then
            ImGui.Separator()
            if ImGui.CollapsingHeader("Ignored") then
                for _, name in ipairs(ignoredWindows) do
                    drawWindowBrowserEntry(name, "ignored")
                end
            end
        end
    end
    controls.EndFillChild("wb_list")

    ImGui.End()
end

--------------------------------------------------------------------------------
-- Sidebar Navigation
--------------------------------------------------------------------------------

local function drawSidebar()
    for _, entry in ipairs(ui.sections) do
        if controls.DynamicButton(entry.label, entry.icon, {
            style = ui.selectedSection == entry.page and "active" or "inactive",
            width = -1,
        }) then
            ui.selectedSection = entry.page
        end
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

--- Initialize section definitions and restore persisted state.
--- Call after IconGlyphs is available.
function ui.init()
    local ic = IconGlyphs or {}
    ui.sections = {
        { label = "General",    icon = ic.Tune        or "?", page = 1 },
        { label = "Grid",       icon = ic.Grid        or "?", page = 2 },
        { label = "Visuals",    icon = ic.Eye         or "?", page = 3 },
        { label = "Background", icon = ic.Brightness6 or "?", page = 4 },
    }
    ui.state.showWindow = settings.master.showGuiWindow
end

--- Render the full settings window (ImGui.Begin/End + layout).
function ui.drawWindow()
    if not ui.state.showWindow then return end

    -- Window size constraints: percentage-of-screen floor + panel content minimums
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
    core.setNextWindowSizeConstraints(minW, minH, displayW * 0.45, displayH * 0.5, GUI_WINDOW_NAME)

    if not ImGui.Begin(GUI_WINDOW_NAME) then
        core.update(GUI_WINDOW_NAME, {
            gridEnabled = settings.master.gridEnabled,
            animationEnabled = settings.master.animationEnabled,
            animationDuration = settings.master.animationDuration,
            treatAllDragsAsWindowDrag = true
        })
        ImGui.End()
        return
    end

    -- Use measured content height from previous frame, or text-metric estimate
    local padY = ImGui.GetStyle().WindowPadding.y
    local experimentalH = cachedExperimentalH
        or (ImGui.GetTextLineHeightWithSpacing() * 6 + ImGui.GetStyle().ItemSpacing.y * 5 + padY * 2)

    local sidebarMaxW = math.floor(displayW * 0.15)

    splitter.multi("gui_outer", {
        { content = function()
            splitter.multi("gui_inner", {
                { maxWidth = sidebarMaxW, content = function()
                    controls.Panel("gui_nav", function()
                        drawSidebar()
                    end)
                end },
                { content = function()
                    drawContentPanel()
                end },
            }, { direction = "horizontal", defaultPcts = { 0.3, 0.7 } })
        end },
        { toggle = true, size = experimentalH, defaultOpen = false, content = function()
            controls.Panel("gui_experimental", function()
                drawExperimentalSection()
                cachedExperimentalH = ImGui.GetCursorPosY() + padY
            end)
        end },
    }, { direction = "vertical" })

    core.update(GUI_WINDOW_NAME, {
        gridEnabled = settings.master.gridEnabled,
        animationEnabled = settings.master.animationEnabled,
        animationDuration = settings.master.animationDuration,
        treatAllDragsAsWindowDrag = true
    })

    ImGui.End()

    drawWindowOverridePanel()
end

--------------------------------------------------------------------------------
-- Window Control API
--------------------------------------------------------------------------------

--- Show the settings window and persist the state.
function ui.show()
    ui.state.showWindow = true
    settings.master.showGuiWindow = true
    settings.save()
end

--- Hide the settings window and persist the state.
function ui.hide()
    ui.state.showWindow = false
    settings.master.showGuiWindow = false
    settings.save()
end

--- Toggle settings window visibility and persist the state.
function ui.toggle()
    ui.state.showWindow = not ui.state.showWindow
    settings.master.showGuiWindow = ui.state.showWindow
    settings.save()
end

--- Return whether the settings window is currently visible.
---@return boolean
function ui.isVisible()
    return ui.state.showWindow
end

return ui
