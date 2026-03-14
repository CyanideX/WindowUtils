------------------------------------------------------
-- WindowUtils - Tabs Module
-- Styled tab bars with badge and disabled tab support
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")

local tabs = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- Badge layout constants (fractions of font size or pixel offsets)
local BADGE_CIRCLE_PAD  = 2     -- padding inside number badge circle
local BADGE_TEXT_PAD    = 4     -- extra horizontal padding for badge text
local BADGE_EDGE_OFFSET = 2     -- offset from item rect edge
local BADGE_SEGMENTS    = 24    -- circle segment count for number badge
local DOT_RADIUS_FACTOR = 0.15  -- dot radius as fraction of font size
local DOT_OFFSET_X      = 0.2   -- horizontal offset as fraction of font size
local DOT_OFFSET_Y      = 0.3   -- vertical offset as fraction of font size
local DOT_SEGMENTS      = 16    -- circle segment count for dot badge
local DOT_PAD_FACTOR    = 0.35  -- label padding width as fraction of font size

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

--- Render a tab bar with content callbacks.
---@param id string Unique tab bar ID
---@param tabDefs table[] Array of tab definitions {label, content?, badge?, disabled?, tooltip?}
---@param opts? table Options {flags?: number}
---@return number selected 1-based active tab index (0 if empty)
---@return boolean changed True on the frame the user clicked a different tab
function tabs.bar(id, tabDefs, opts)
    if not tabDefs or #tabDefs == 0 then return 0, false end

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
                    local radius = math.max(textH * 0.5 + BADGE_CIRCLE_PAD, textW * 0.5 + BADGE_TEXT_PAD)
                    local padCount = math.ceil((radius * 2) / spaceW)
                    label = label .. string.rep(" ", padCount)
                else
                    label = label .. string.rep(" ", math.ceil(ImGui.GetFontSize() * DOT_PAD_FACTOR / spaceW))
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
                    local radius = math.max(textH * 0.5 + BADGE_CIRCLE_PAD, textW * 0.5 + BADGE_TEXT_PAD)
                    local cx = maxX - radius - BADGE_EDGE_OFFSET
                    local cy = minY + radius + BADGE_EDGE_OFFSET

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, radius, cachedBadgeColor, BADGE_SEGMENTS)
                    ImGui.ImDrawListAddText(drawList, fontSize, cx - textW * 0.5, cy - textH * 0.5, cachedTextColor, badgeText)
                elseif tab.badge == true then
                    local dotRadius = fontSize * DOT_RADIUS_FACTOR
                    local cx = maxX - dotRadius - fontSize * DOT_OFFSET_X
                    local cy = minY + dotRadius + fontSize * DOT_OFFSET_Y

                    ImGui.ImDrawListAddCircleFilled(drawList, cx, cy, dotRadius, cachedDotColor, DOT_SEGMENTS)
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
