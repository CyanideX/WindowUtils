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

            local open = ImGui.BeginTabItem(tab.label .. "##" .. id .. "_" .. i, tabFlags)

            -- Badge rendering (small colored dot or number after the tab label)
            if tab.badge and not disabled then
                if not cachedBadgeColor then
                    cachedBadgeColor = styles.ToColor(styles.colors.red)
                    cachedTextColor = styles.ToColor(styles.colors.textWhite)
                    cachedDotColor = styles.ToColor(styles.colors.green)
                end

                local maxX, minY = ImGui.GetItemRectMax()
                local drawList = ImGui.GetWindowDrawList()

                if type(tab.badge) == "number" and tab.badge > 0 then
                    local badgeText = tostring(tab.badge)
                    local textW, textH = ImGui.CalcTextSize(badgeText)
                    local radius = math.max(textH * 0.5 + 2, textW * 0.5 + 4)
                    local cx = maxX - 2
                    local cy = minY + radius + 2

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, radius, cachedBadgeColor, 12)
                    ImGui.ImDrawListAddText(drawList, ImGui.GetFontSize(), cx - textW * 0.5, cy - textH * 0.5, cachedTextColor, badgeText)
                elseif tab.badge == true then
                    local dotRadius = 3
                    local cx = maxX - 2
                    local cy = minY + dotRadius + 4

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, dotRadius, cachedDotColor, 8)
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

    return state.selected
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
