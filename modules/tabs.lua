------------------------------------------------------
-- WindowUtils - Tabs Module
-- Styled tab bars with badge and disabled tab support
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")

local tabs = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local tabStates = {} -- [id] = { selected = 1 }

-- Cached badge colors (computed once on first use)
local cachedBadgeColor = nil
local cachedTextColor = nil
local cachedDotColor = nil

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Render a tab bar with content callbacks
function tabs.bar(id, tabDefs, opts)
    if not tabDefs or #tabDefs == 0 then return 0 end

    opts = opts or {}
    local flags = opts.flags or 0

    if not tabStates[id] then
        tabStates[id] = { selected = 1 }
    end
    local state = tabStates[id]

    local prevSelected = state.selected

    if ImGui.BeginTabBar(id, flags) then
        for i, tab in ipairs(tabDefs) do
            local disabled = tab.disabled or false
            local tabFlags = 0

            -- Force-select a tab if requested programmatically
            if state.pendingSelect == i then
                tabFlags = ImGuiTabItemFlags.SetSelected
                state.pendingSelect = nil
            end

            if disabled then
                ImGui.BeginDisabled()
            end

            -- Pad the label so badges fit inside the tab
            local label = tab.label
            local hasBadgeNum = not disabled and type(tab.badge) == "number" and tab.badge > 0
            local hasBadgeDot = not disabled and tab.badge == true
            if hasBadgeNum or hasBadgeDot then
                local spaceW = ImGui.CalcTextSize(" ")
                if hasBadgeNum then
                    local badgeText = tostring(tab.badge)
                    local textW, textH = ImGui.CalcTextSize(badgeText)
                    local radius = math.max(textH * 0.5 + 2, textW * 0.5 + 4)
                    local padCount = math.ceil((radius * 2) / spaceW)
                    label = label .. string.rep(" ", padCount)
                else
                    label = label .. string.rep(" ", math.ceil(ImGui.GetFontSize() * 0.35 / spaceW))
                end
            end

            local open = ImGui.BeginTabItem(label .. "##" .. id .. "_" .. i, tabFlags)

            -- Badge rendering (small colored dot or number after the tab label)
            if tab.badge and not disabled then
                if not cachedBadgeColor then
                    cachedBadgeColor = styles.ToColor(styles.colors.red)
                    cachedTextColor = styles.ToColor(styles.colors.textWhite)
                    cachedDotColor = styles.ToColor(styles.colors.green)
                end

                local _, minY = ImGui.GetItemRectMin()
                local maxX = ImGui.GetItemRectMax()
                local drawList = ImGui.GetWindowDrawList()
                local fontSize = ImGui.GetFontSize()

                if hasBadgeNum then
                    local badgeText = tostring(tab.badge)
                    local textW, textH = ImGui.CalcTextSize(badgeText)
                    local radius = math.max(textH * 0.5 + 2, textW * 0.5 + 4)
                    local cx = maxX - radius - 2
                    local cy = minY + radius + 2

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, radius, cachedBadgeColor, 24)
                    ImGui.ImDrawListAddText(drawList, fontSize, cx - textW * 0.5, cy - textH * 0.5, cachedTextColor, badgeText)
                elseif tab.badge == true then
                    local dotRadius = fontSize * 0.15
                    local cx = maxX - dotRadius - fontSize * 0.2
                    local cy = minY + dotRadius + fontSize * 0.3

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, dotRadius, cachedDotColor, 16)
                end
            end

            -- Tooltip on tab hover
            if tab.tooltip and ImGui.IsItemHovered() then
                tooltips.ShowAlways(tab.tooltip)
            end

            if disabled then
                ImGui.EndDisabled()
            end

            if open then
                state.selected = i

                -- Render tab content
                if tab.content then
                    tab.content()
                end

                ImGui.EndTabItem()
            end
        end

        ImGui.EndTabBar()
    end

    local changed = state.selected ~= prevSelected
    return state.selected, changed
end

--- Programmatically select a tab by index (1-based)
function tabs.select(id, index)
    if not tabStates[id] then
        tabStates[id] = { selected = 1 }
    end
    tabStates[id].pendingSelect = index
end

--- Get currently selected tab index (1-based)
function tabs.getSelected(id)
    local state = tabStates[id]
    return state and state.selected or 1
end

return tabs
