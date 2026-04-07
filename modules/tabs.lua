------------------------------------------------------
-- WindowUtils - Tabs
-- Styled tab bars with badges and disabled support
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")

local tabs = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local BADGE_CIRCLE_PAD  = 2
local BADGE_TEXT_PAD    = 4
local BADGE_EDGE_OFFSET = 2
local BADGE_SEGMENTS    = 24
local DOT_RADIUS_FACTOR = 0.15
local DOT_OFFSET_X      = 0.2
local DOT_OFFSET_Y      = 0.3
local DOT_SEGMENTS      = 16
local DOT_PAD_FACTOR    = 0.35

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local tabStates = {}

local cachedBadgeColor = nil
local cachedTextColor  = nil
local cachedDotColor   = nil

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Render a tab bar with content callbacks.
---@param id string Unique tab bar ID
---@param tabDefs table[] Array of tab definitions {label, content?, badge?, disabled?, tooltip?}
---@param opts? table Options {flags?: number}
---@return number selected 1-based active tab index (0 if empty)
---@return boolean changed True on the frame the user clicked a different tab
function tabs.bar(id, tabDefs, opts)
    if not tabDefs or #tabDefs == 0 then return 0, false end

    if not cachedBadgeColor then
        cachedBadgeColor = styles.ToColor(styles.colors.red)
        cachedTextColor  = styles.ToColor(styles.colors.textWhite)
        cachedDotColor   = styles.ToColor(styles.colors.green)
    end

    opts = opts or {}
    local flags = opts.flags or 0

    if not tabStates[id] then
        tabStates[id] = { selected = 1 }
    end
    local state = tabStates[id]

    local prevSelected = state.selected

    if ImGui.BeginTabBar(id, flags) then
        local spaceW = ImGui.CalcTextSize(" ")
        local fontSize = ImGui.GetFontSize()
        local drawList = ImGui.GetWindowDrawList()

        for i, tab in ipairs(tabDefs) do
            local disabled = tab.disabled or false
            local tabFlags = 0

            if state.pendingSelect == i then
                tabFlags = ImGuiTabItemFlags.SetSelected
                state.pendingSelect = nil
            end

            if disabled then
                ImGui.BeginDisabled()
            end

            -- Pad label for badge overlay space
            local label = tab.label
            local hasBadgeNum = not disabled and type(tab.badge) == "number" and tab.badge > 0
            local hasBadgeDot = not disabled and tab.badge == true
            local badgeTextW, badgeTextH, badgeRadius
            if hasBadgeNum or hasBadgeDot then
                if hasBadgeNum then
                    local badgeText = tostring(tab.badge)
                    badgeTextW, badgeTextH = ImGui.CalcTextSize(badgeText)
                    badgeRadius = math.max(badgeTextH * 0.5 + BADGE_CIRCLE_PAD, badgeTextW * 0.5 + BADGE_TEXT_PAD)
                    local padCount = math.ceil((badgeRadius * 2) / spaceW)
                    label = label .. string.rep(" ", padCount)
                else
                    label = label .. string.rep(" ", math.ceil(fontSize * DOT_PAD_FACTOR / spaceW))
                end
            end

            local open = ImGui.BeginTabItem(label .. "##" .. id .. "_" .. i, tabFlags)

            -- Badge overlay
            if tab.badge and not disabled then
                local _, minY = ImGui.GetItemRectMin()
                local maxX = ImGui.GetItemRectMax()

                if hasBadgeNum then
                    local cx = maxX - badgeRadius - BADGE_EDGE_OFFSET
                    local cy = minY + badgeRadius + BADGE_EDGE_OFFSET

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, badgeRadius, cachedBadgeColor, BADGE_SEGMENTS)
                    ImGui.ImDrawListAddText(drawList, fontSize, cx - badgeTextW * 0.5, cy - badgeTextH * 0.5, cachedTextColor, tostring(tab.badge))
                elseif tab.badge == true then
                    local dotRadius = fontSize * DOT_RADIUS_FACTOR
                    local cx = maxX - dotRadius - fontSize * DOT_OFFSET_X
                    local cy = minY + dotRadius + fontSize * DOT_OFFSET_Y

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, dotRadius, cachedDotColor, DOT_SEGMENTS)
                end
            end

            if tab.tooltip and ImGui.IsItemHovered() then
                tooltips.ShowAlways(tab.tooltip)
            end

            if disabled then
                ImGui.EndDisabled()
            end

            if open then
                state.selected = i

                if tab.content then
                    if tab.noScroll then
                        -- Fill available space with no scrollbar for tabs that manage their own layout
                        local cw, ch = ImGui.GetContentRegionAvail()
                        local flags = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
                        if ImGui.BeginChild("##" .. id .. "_noscroll_" .. i, cw, ch, false, flags) then
                            tab.content()
                        end
                        ImGui.EndChild()
                    else
                        tab.content()
                    end
                end

                ImGui.EndTabItem()
            end
        end

        ImGui.EndTabBar()
    end

    local changed = state.selected ~= prevSelected
    return state.selected, changed
end

--- Programmatically select a tab by index (takes effect next frame).
---@param id string Tab bar ID
---@param index number 1-based tab index
function tabs.select(id, index)
    if not tabStates[id] then
        tabStates[id] = { selected = 1 }
    end
    tabStates[id].pendingSelect = index
end

--- Get currently selected tab index.
---@param id string Tab bar ID
---@return number index 1-based index (1 if not initialized)
function tabs.getSelected(id)
    local state = tabStates[id]
    return state and state.selected or 1
end

return tabs
