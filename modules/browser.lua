------------------------------------------------------
-- WindowUtils - Window Browser Module
-- Displays all discovered windows with management controls
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")
local discovery = require("modules/discovery")
local controls = require("modules/controls")
local styles = require("modules/styles")

local OFFSCREEN_THRESHOLD = core.OFFSCREEN_THRESHOLD

local browser = {}

-- Browser window state
browser.state = {
    showWindow = false,
    filterText = "",
}

--------------------------------------------------------------------------------
-- Window Control
--------------------------------------------------------------------------------

--- Show the window browser.
function browser.show()
    browser.state.showWindow = true
end

--- Hide the window browser.
function browser.hide()
    browser.state.showWindow = false
end

--- Toggle the window browser visibility.
function browser.toggle()
    browser.state.showWindow = not browser.state.showWindow
end

--- Check if the window browser is visible.
---@return boolean
function browser.isVisible()
    return browser.state.showWindow
end

--------------------------------------------------------------------------------
-- Status Helpers
--------------------------------------------------------------------------------

local function getStatusLabel(probePhase)
    if probePhase == core.PROBE_ACTIVE then
        return "Active", "success"
    elseif probePhase == core.PROBE_BLOCKED then
        return "Blocked", "danger"
    elseif probePhase == core.PROBE_SKIP or probePhase == core.PROBE_CHECK then
        return "Probing", "warning"
    end
    return "--", "muted"
end

local function drawStatusText(label, style)
    if style == "success" then
        controls.TextSuccess(label)
    elseif style == "danger" then
        controls.TextDanger(label)
    elseif style == "warning" then
        controls.TextWarning(label)
    else
        controls.TextMuted(label)
    end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

--- Render the window browser (call once per frame from onDraw).
function browser.draw()
    if not browser.state.showWindow then return end

    ImGui.SetNextWindowSize(560, 420, ImGuiCond.FirstUseEver)
    local visible, open = ImGui.Begin("Window Browser###WindowUtilsBrowser", true)

    if not open then
        browser.state.showWindow = false
        ImGui.End()
        return
    end

    if not visible then
        ImGui.End()
        return
    end

    -- Check if discovery is available
    if not discovery.isAvailable() then
        controls.TextWarning("RedCetWM plugin not found")
        controls.TextMuted("Install Window Manager for window discovery")
        ImGui.End()
        return
    end

    -- Filter input
    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    styles.PushOutlined()
    local newFilter = ImGui.InputText("##browserFilter", browser.state.filterText, 256)
    styles.PopOutlined()
    if newFilter then
        browser.state.filterText = newFilter
    end

    ImGui.Dummy(0, 2)

    -- Get data
    local windows = discovery.getActiveWindows()
    local extStates = core.getExternalWindowStates()

    -- Build exclusion set for display
    local excludedSet = {}
    if settings.master.excludedWindows then
        for _, name in ipairs(settings.master.excludedWindows) do
            excludedSet[name] = true
        end
    end

    -- Build p_open set for display
    local pOpenSet = settings.master.windowPOpen or {}

    -- Count stats
    local totalCount = #windows
    local activeCount = 0
    local blockedCount = 0
    for _, info in pairs(extStates) do
        if info.probePhase == core.PROBE_ACTIVE then
            activeCount = activeCount + 1
        elseif info.probePhase == core.PROBE_BLOCKED then
            blockedCount = blockedCount + 1
        end
    end

    controls.TextMuted(string.format(
        "Discovered: %d  |  Active: %d  |  Blocked: %d  |  Excluded: %d",
        totalCount, activeCount, blockedCount,
        settings.master.excludedWindows and #settings.master.excludedWindows or 0
    ))

    ImGui.Dummy(0, 2)
    ImGui.Separator()

    local totalWidth = ImGui.GetContentRegionAvail()
    ImGui.Columns(4, "##browserCols", true)
    ImGui.SetColumnWidth(0, totalWidth * 0.55)  -- Window Name
    ImGui.SetColumnWidth(1, totalWidth * 0.15)  -- Status
    ImGui.SetColumnWidth(2, totalWidth * 0.15)  -- Enabled
    ImGui.SetColumnWidth(3, totalWidth * 0.15)  -- pOpen

    styles.PushTextMuted()
    ImGui.Text("Window Name")
    ImGui.NextColumn()
    ImGui.Text("Status")
    ImGui.NextColumn()
    ImGui.Text("Enabled")
    ImGui.NextColumn()
    ImGui.Text("pOpen")
    ImGui.NextColumn()
    styles.PopTextMuted()

    ImGui.Separator()

    local filterLower = browser.state.filterText:lower()

    for _, windowInfo in ipairs(windows) do
        local name = windowInfo.name

        -- Apply filter
        if filterLower == "" or name:lower():find(filterLower, 1, true) then
            -- Skip offscreen windows
            if windowInfo.posX < OFFSCREEN_THRESHOLD and windowInfo.posY < OFFSCREEN_THRESHOLD then
                ImGui.Text(name)
                if ImGui.IsItemHovered() then
                    ImGui.BeginTooltip()
                    ImGui.Text(name)
                    ImGui.Text(string.format("Position: %d, %d", windowInfo.posX, windowInfo.posY))
                    ImGui.Text(string.format("Size: %d x %d", windowInfo.sizeX, windowInfo.sizeY))
                    if windowInfo.collapsed then
                        ImGui.Text("Collapsed: Yes")
                    end
                    ImGui.EndTooltip()
                end
                ImGui.NextColumn()

                local extState = extStates[name]
                if extState then
                    local label, style = getStatusLabel(extState.probePhase)
                    drawStatusText(label, style)
                else
                    controls.TextMuted("--")
                end
                ImGui.NextColumn()

                local isEnabled = not excludedSet[name]
                local newEnabled, changed = ImGui.Checkbox("##en_" .. name, isEnabled)
                if changed then
                    if newEnabled then
                        core.removeExclusion(name)
                        excludedSet[name] = nil
                    else
                        core.addExclusion(name)
                        excludedSet[name] = true
                    end
                end
                ImGui.NextColumn()

                local hasPOpen = pOpenSet[name] == true
                local newPOpen
                newPOpen, changed = ImGui.Checkbox("##po_" .. name, hasPOpen)
                if changed then
                    core.setPOpen(name, newPOpen or nil)
                    pOpenSet[name] = newPOpen or nil
                end
                ImGui.NextColumn()
            end
        end
    end

    ImGui.Columns(1)
    ImGui.End()
end

return browser
