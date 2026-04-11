------------------------------------------------------
-- WindowUtils - Controls Hold Buttons
-- Hold-to-confirm: HoldButton, ActionButton, hold progress helpers
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")
local core = require("modules/controls/core")
local display = require("modules/controls/display")

local frameCache = core.frameCache
local cachedCalcTextSize = core.cachedCalcTextSize

local M = {}

--------------------------------------------------------------------------------
-- Module-local state
--------------------------------------------------------------------------------

local holdStates = {}           -- HoldButton per-id state
local HOLD_OVERLAY_COLOR = nil  -- Cached overlay color for HoldButton

-- Reused tables for ActionButton (avoids per-frame allocation)
local actionButtonHoldOpts = { duration = 0, style = "", progressDisplay = "external" }
local actionButtonResult = { primaryClicked = false, secondaryTriggered = false }

--------------------------------------------------------------------------------
-- Hold-to-Confirm Button
--------------------------------------------------------------------------------

--- Create a hold-to-confirm button with progress fill overlay
---@param id string Unique button ID (also used as label in legacy mode)
---@param label string Button label text
---@param opts? table {duration?, style?, width?, progressDisplay?, progressStyle?, disabled?, tooltip?, overlayColor?, onClick?, onHold?}
---@return boolean triggered True if the hold completed
---@return boolean clicked True if released before hold completed
function M.HoldButton(id, label, opts)
    opts = opts or {}
    local duration = opts.duration or 2.0
    local styleName = opts.style or "danger"
    local width = opts.width or 0
    if width < 0 then width = ImGui.GetContentRegionAvail() end
    local progressDisplay = opts.progressDisplay or "overlay"
    local progressStyle = opts.progressStyle or "danger"
    local isDisabled = opts.disabled or false

    if isDisabled then ImGui.BeginDisabled(true) end

    if not holdStates[id] then
        holdStates[id] = {
            holding = false,
            completed = false,
            startTime = 0,
            holdDuration = duration,
            progress = 0,
            lastTime = os.clock(),
            displayLabel = label .. "##hold_" .. id,
        }
    end
    local state = holdStates[id]
    state.holdDuration = duration
    local now = os.clock()
    local dt = now - state.lastTime
    state.lastTime = now

    local triggered = false
    local clicked = false

    if state.completed and not ImGui.IsMouseDown(0) then
        state.completed = false
    end

    if progressDisplay == "replace" and state.holding then
        display.ProgressBar(state.progress, width > 0 and width or nil, 0, "", progressStyle)
        if not ImGui.IsMouseDown(0) then
            clicked = state.holding
            state.holding = false
        elseif not state.completed then
            state.progress = math.min((now - state.startTime) / duration, 1.0)
            if state.progress >= 1.0 then
                state.progress = 0
                state.holding = false
                state.completed = true
                triggered = true
            end
        end
        if isDisabled then ImGui.EndDisabled() end
        if opts.tooltip then tooltips.Show(opts.tooltip) end
        if triggered and opts.onHold then opts.onHold() end
        if clicked and opts.onClick then opts.onClick() end
        return triggered, clicked
    end

    local displayLabel = state.displayLabel
    styles.PushButton(styleName)
    ImGui.Button(displayLabel, width, 0)
    local isActive = ImGui.IsItemActive()
    styles.PopButton(styleName)

    if isActive and not state.holding and not state.completed then
        state.holding = true
        state.startTime = now
        state.progress = 0
    end

    if state.holding then
        if (isActive or ImGui.IsMouseDown(0)) and not state.completed then
            state.progress = math.min((now - state.startTime) / duration, 1.0)
            if state.progress >= 1.0 then
                state.progress = 0
                state.holding = false
                state.completed = true
                triggered = true
            end
        else
            state.holding = false
            clicked = true
        end
    end

    if not state.holding and state.progress > 0 then
        state.progress = math.max(0, state.progress - dt * 4)
    end

    if progressDisplay == "overlay" and state.progress > 0 then
        local minX, minY = ImGui.GetItemRectMin()
        local maxX, maxY = ImGui.GetItemRectMax()
        local fillX = minX + (maxX - minX) * state.progress

        local drawList = ImGui.GetWindowDrawList()
        local color
        if opts.overlayColor then
            local oc = opts.overlayColor
            color = ImGui.GetColorU32(oc[1], oc[2], oc[3], oc[4])
        else
            if not HOLD_OVERLAY_COLOR then
                HOLD_OVERLAY_COLOR = ImGui.GetColorU32(0.16, 0.16, 0.16, 0.31)
            end
            color = HOLD_OVERLAY_COLOR
        end
        ImGui.ImDrawListAddRectFilled(drawList, minX, minY, fillX, maxY, color, 2.0)
    end
    -- "external" mode: no visual - other elements read via getHoldProgress()

    if isDisabled then ImGui.EndDisabled() end
    if opts.tooltip then tooltips.Show(opts.tooltip) end

    if triggered and opts.onHold then opts.onHold() end
    if clicked and opts.onClick then opts.onClick() end

    return triggered, clicked
end

--------------------------------------------------------------------------------
-- Hold Progress Helpers
--------------------------------------------------------------------------------

--- Get the current hold progress for a button ID
---@param id string Button ID to query
---@return number|nil progress Hold progress 0.0-1.0, or nil if not holding
function M.getHoldProgress(id)
    local state = holdStates[id]
    if not state or not state.holding then return nil end
    return math.min((os.clock() - state.startTime) / state.holdDuration, 1.0)
end

--- Display a progress bar showing another button's hold progress
---@param sourceId string Button ID whose hold progress to display
---@param width? number Bar width in pixels (default fills available)
---@param progressStyle? string Style name for the progress bar (default "danger")
---@return boolean shown True if a progress bar was rendered
function M.ShowHoldProgress(sourceId, width, progressStyle)
    local progress = M.getHoldProgress(sourceId)
    if not progress then return false end

    width = width or ImGui.GetContentRegionAvail()
    progressStyle = progressStyle or "danger"
    display.ProgressBar(progress, width, 0, "", progressStyle)
    return true
end

--- Return the progress and source ID of the first actively-held button from a list.
---@param ids string[] Array of button IDs to check
---@return number|nil progress Hold progress 0.0-1.0, or nil if none active
---@return string|nil sourceId The ID of the first active button, or nil
function M.getFirstActiveHoldProgress(ids)
    if not ids then return nil end
    for i = 1, #ids do
        local progress = M.getHoldProgress(ids[i])
        if progress then return progress, ids[i] end
    end
    return nil
end

--- Render a progress bar for the first active hold source, or return false.
---@param ids string[] Array of button IDs to check
---@param width? number Bar width in pixels (default fills available)
---@param progressStyle? string Style name (default "danger")
---@return boolean shown True if a progress bar was rendered
function M.ShowFirstActiveHoldProgress(ids, width, progressStyle)
    local progress = M.getFirstActiveHoldProgress(ids)
    if not progress then return false end

    width = width or ImGui.GetContentRegionAvail()
    progressStyle = progressStyle or "danger"
    display.ProgressBar(progress, width, 0, "", progressStyle)
    return true
end

--------------------------------------------------------------------------------
-- Action Button (compound: primary label + secondary hold icon)
--------------------------------------------------------------------------------

--- Compound action button: primary label + secondary icon with cross-element progress
---@param id string Unique button group ID
---@param label string Primary button label text
---@param opts? table {onPrimary?, onSecondary?, secondaryIcon?, secondaryDuration?, secondaryStyle?, progressStyle?, style?, isActive?, width?}
---@return table result {primaryClicked: boolean, secondaryTriggered: boolean}
function M.ActionButton(id, label, opts)
    opts = opts or {}
    local onPrimary = opts.onPrimary
    local onSecondary = opts.onSecondary
    local secondaryIcon = opts.secondaryIcon or (IconGlyphs and IconGlyphs.TrashCanOutline or "X")
    local secondaryDuration = opts.secondaryDuration or 1.0
    local secondaryStyle = opts.secondaryStyle or "danger"
    local progressStyle = opts.progressStyle or "danger"
    local style = opts.style or "inactive"
    local isActive = opts.isActive
    local totalWidth = opts.width

    local secondaryWidth = 0
    if onSecondary then
        local iconWidth = cachedCalcTextSize(secondaryIcon)
        local framePadX = frameCache.framePaddingX * 2
        local spacing = frameCache.itemSpacingX
        secondaryWidth = iconWidth + framePadX + spacing
    end
    local mainWidth = (totalWidth or ImGui.GetContentRegionAvail()) - secondaryWidth

    local secondaryId = id .. "_secondary"
    local primaryClicked = false

    -- Primary button: show progress bar from secondary hold, or normal button
    if onSecondary and M.ShowHoldProgress(secondaryId, mainWidth, progressStyle) then
        -- (progress bar replaces primary button while held)
    else
        local resolvedStyle = isActive and "active" or style
        styles.PushButton(resolvedStyle)
        primaryClicked = ImGui.Button(label, mainWidth, 0)
        styles.PopButton(resolvedStyle)
    end

    if primaryClicked and onPrimary then
        onPrimary()
    end

    -- Secondary button (hold to confirm)
    local secondaryTriggered = false
    if onSecondary then
        ImGui.SameLine()
        actionButtonHoldOpts.duration = secondaryDuration
        actionButtonHoldOpts.style = secondaryStyle
        secondaryTriggered = M.HoldButton(secondaryId, secondaryIcon, actionButtonHoldOpts)
        if secondaryTriggered then
            onSecondary()
        end
    end

    actionButtonResult.primaryClicked = primaryClicked
    actionButtonResult.secondaryTriggered = secondaryTriggered
    return actionButtonResult
end

--------------------------------------------------------------------------------
-- State Reset
--------------------------------------------------------------------------------

--- Reset hold state for a specific button ID
---@param id string Button ID to reset
---@return nil
function M.resetHoldState(id)
    holdStates[id] = nil
end

--- Reset all hold states.
---@return nil
function M.resetAllHoldStates()
    holdStates = {}
end

return M
