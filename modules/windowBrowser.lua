------------------------------------------------------
-- WindowUtils - Window Browser Module
-- Browse and manage discovered CET windows
------------------------------------------------------

local settings  = require("modules/settings")
local core      = require("modules/core")
local controls  = require("modules/controls")
local styles    = require("modules/styles")
local utils     = require("modules/utils")
local tooltips  = require("modules/tooltips")
local discovery = require("modules/discovery")
local search    = require("modules/search")

local browser = {}

local searchState = nil
local WINDOW_NAME = "Window Browser##WindowUtils"

local function icon(name)
    return utils.resolveIcon(name) or "?"
end

local function drawEntry(name, category)
    local override = settings.windows.overrides[name]
    local btnW = utils.minIconButtonWidth()
    local isHidden = (category == "hidden")
    local isIgnored = (category == "ignored")

    -- pOpen toggle
    local pOpenIcon = override and icon("ToggleSwitch") or icon("ToggleSwitchOffOutline")
    if isHidden or isIgnored then
        ImGui.BeginDisabled()
        controls.Button(pOpenIcon .. "##popen_" .. name, "disabled", btnW)
        ImGui.EndDisabled()
        tooltips.Show(isIgnored
            and "Unignore this window to change Close Button setting"
            or "Unhide this window to change Close Button setting")
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
    local ignoreIcon = isIgnored and icon("Cancel") or icon("CircleOffOutline")
    local ignoreStyle = isIgnored and "danger" or "inactive"
    if controls.Button(ignoreIcon .. "##ign_" .. name, ignoreStyle, btnW) then
        settings.setWindowIgnored(name, not isIgnored)
    end
    tooltips.Show(isIgnored
        and "Stop ignoring this window\nWindowUtils will manage it again"
        or "Ignore this window completely\nWindowUtils will not apply any overrides")

    ImGui.SameLine()

    -- Visibility toggle
    local eyeIcon = isHidden and icon("EyeOff") or icon("EyeOutline")
    if isIgnored then
        ImGui.BeginDisabled()
        controls.Button(eyeIcon .. "##vis_" .. name, "disabled", btnW)
        ImGui.EndDisabled()
        tooltips.Show("Unignore this window to change visibility")
    else
        if controls.Button(eyeIcon .. "##vis_" .. name, "inactive", btnW) then
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

    -- Window name
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

function browser.draw()
    if not settings.master.enabled then return end
    if not settings.master.showExperimental then return end
    if not settings.master.windowBrowserOpen then return end
    if not settings.master.overrideAllWindows then return end

    local dw, dh = GetDisplayResolution()
    ImGui.SetNextWindowSize(dw * 0.15, dh * 0.35, ImGuiCond.FirstUseEver)
    core.setNextWindowSizeConstraintsPercent(12, 15, 50, 90, WINDOW_NAME)

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

    if not searchState then
        searchState = search.new("wb_search")
    end
    search.SearchBar(searchState, { cols = 12 })

    local filter = searchState:getQuery():lower()
    local windows = discovery.getActiveWindows()
    local visibleWindows = {}
    local hiddenWindows = {}
    local ignoredWindows = {}

    for _, windowInfo in ipairs(windows) do
        local name = windowInfo.name
        if name:sub(1, 3) == "###" then goto skipWindow end
        if filter == "" or name:lower():find(filter, 1, true) then
            if settings.isWindowIgnored(name) then
                ignoredWindows[#ignoredWindows + 1] = name
            elseif settings.isWindowHidden(name) then
                hiddenWindows[#hiddenWindows + 1] = name
            else
                visibleWindows[#visibleWindows + 1] = name
            end
        end
        ::skipWindow::
    end

    local lowerCache = {}
    for _, name in ipairs(visibleWindows) do lowerCache[name] = name:lower() end
    for _, name in ipairs(hiddenWindows) do lowerCache[name] = name:lower() end
    for _, name in ipairs(ignoredWindows) do lowerCache[name] = name:lower() end
    local function cmpAlpha(a, b) return lowerCache[a] < lowerCache[b] end
    table.sort(visibleWindows, cmpAlpha)
    table.sort(hiddenWindows, cmpAlpha)
    table.sort(ignoredWindows, cmpAlpha)

    -- Bulk action header
    controls.Separator(4, 4)
    local btnW = utils.minIconButtonWidth()
    local headerIndent = ImGui.GetStyle().WindowPadding.x
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + headerIndent)

    local allVisible = {}
    for _, name in ipairs(visibleWindows) do allVisible[#allVisible + 1] = name end
    for _, name in ipairs(hiddenWindows) do allVisible[#allVisible + 1] = name end
    for _, name in ipairs(ignoredWindows) do allVisible[#allVisible + 1] = name end

    if controls.Button(icon("ToggleSwitchOffOutline") .. "##wb_toggle_all", "inactive", btnW) then
        for _, name in ipairs(allVisible) do
            local override = settings.windows.overrides[name]
            if not override and not settings.isWindowIgnored(name) and not settings.isWindowHidden(name) then
                settings.setWindowOverride(name, true)
            end
        end
    end
    tooltips.Show("Toggle All\nEnable Close Button on all visible windows")

    ImGui.SameLine()

    if controls.Button(icon("CircleOffOutline") .. "##wb_ignore_all", "inactive", btnW) then
        for _, name in ipairs(allVisible) do
            if not settings.isWindowIgnored(name) then
                settings.setWindowIgnored(name, true)
            end
        end
    end
    tooltips.Show("Ignore All\nIgnore all listed windows")

    ImGui.SameLine()

    if controls.Button(icon("EyeOff") .. "##wb_hide_all", "inactive", btnW) then
        for _, name in ipairs(allVisible) do
            if not settings.isWindowIgnored(name) and not settings.isWindowHidden(name) then
                settings.setWindowOverride(name, nil)
                settings.setWindowHidden(name, true)
            end
        end
    end
    tooltips.Show("Hide All\nHide all listed windows")

    ImGui.SameLine()

    styles.PushTextMuted()
    ImGui.Text("Window Name")
    styles.PopTextMuted()

    ImGui.Dummy(0, 2)

    if controls.BeginFillChild("wb_list") then
        for _, name in ipairs(visibleWindows) do
            drawEntry(name, "visible")
        end

        if #hiddenWindows > 0 then
            ImGui.Separator()
            if ImGui.CollapsingHeader("Hidden") then
                for _, name in ipairs(hiddenWindows) do
                    drawEntry(name, "hidden")
                end
            end
        end

        if #ignoredWindows > 0 then
            ImGui.Separator()
            if ImGui.CollapsingHeader("Ignored") then
                for _, name in ipairs(ignoredWindows) do
                    drawEntry(name, "ignored")
                end
            end
        end
    end
    controls.EndFillChild("wb_list")

    core.update(WINDOW_NAME, {
        gridEnabled = settings.master.gridEnabled,
        animationEnabled = settings.master.animationEnabled,
        animationDuration = settings.master.animationDuration,
        treatAllDragsAsWindowDrag = true,
    })

    ImGui.End()
end

function browser.clearSearch()
    if searchState then searchState:clear() end
end

return browser
