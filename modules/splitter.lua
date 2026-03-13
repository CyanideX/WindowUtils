------------------------------------------------------
-- WindowUtils - Splitter Module
-- Draggable panel dividers for two-panel layouts
------------------------------------------------------

local styles = require("modules/styles")

local splitter = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local splitStates = {} -- [id] = { pct, defaultPct, minPct, maxPct, grabWidth, hovering, dragging }

local function getState(id, opts)
    if not splitStates[id] then
        opts = opts or {}
        splitStates[id] = {
            pct = opts.defaultPct or 0.5,
            defaultPct = opts.defaultPct or 0.5,
            minPct = opts.minPct or 0.1,
            maxPct = opts.maxPct or 0.9,
            grabWidth = opts.grabWidth or 6,
            hovering = false,
            dragging = false
        }
    end
    return splitStates[id]
end

--------------------------------------------------------------------------------
-- Internal: Draw the grab bar as a styled child window
--------------------------------------------------------------------------------

local _grabIcon = nil
local _grabIconV = nil

local function getGrabIcon()
    if not _grabIcon then
        _grabIcon = IconGlyphs and IconGlyphs.DragVertical or "||"
    end
    return _grabIcon
end

local function getGrabIconV()
    if not _grabIconV then
        _grabIconV = IconGlyphs and IconGlyphs.DragHorizontal or "=="
    end
    return _grabIconV
end

local function drawGrabBar(id, state, isVertical)
    -- Color based on state
    local bgColor
    if state.dragging then
        bgColor = styles.colors.splitterDrag or styles.colors.green
    elseif state.hovering then
        bgColor = styles.colors.splitterHover or { 0.3, 0.5, 0.7, 0.5 }
    else
        bgColor = { 0, 0, 0, 0 }
    end

    local iconColor
    if state.dragging or state.hovering then
        iconColor = styles.colors.splitterIconHi or styles.colors.textWhite
    else
        iconColor = styles.colors.splitterIcon or styles.colors.greyLight
    end

    local grabW = state.grabWidth
    local icon = isVertical and getGrabIconV() or getGrabIcon()

    if not isVertical then
        ImGui.SameLine()
    end

    ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)

    local childW, childH
    if isVertical then
        childW = 0 -- fill width
        childH = grabW
    else
        childW = grabW
        childH = 0 -- fill height (uses -1 internally via remaining)
    end

    if ImGui.BeginChild("##splitter_grab_" .. id, childW, childH, false, ImGuiWindowFlags.NoMove) then
        -- Center the icon
        local winW, winH = ImGui.GetWindowSize()
        local textW, textH = ImGui.CalcTextSize(icon)
        ImGui.SetCursorPosX((winW - textW) / 2)
        ImGui.SetCursorPosY((winH - textH) / 2)

        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(iconColor[1], iconColor[2], iconColor[3], iconColor[4]))
        ImGui.Text(icon)
        ImGui.PopStyleColor()
    end
    ImGui.EndChild()

    -- Check hover after EndChild
    state.hovering = ImGui.IsItemHovered()

    ImGui.PopStyleVar()
    ImGui.PopStyleColor()

    -- Start drag
    if state.hovering and ImGui.IsMouseDragging(0, 0) then
        state.dragging = true
    end

    -- Stop drag
    if state.dragging and not ImGui.IsMouseDragging(0, 0) then
        state.dragging = false
    end

    -- Apply drag delta
    if state.dragging then
        if isVertical then
            local _, totalH = ImGui.GetContentRegionAvail()
            -- For vertical, we need the parent window height
            local _, parentH = ImGui.GetWindowSize()
            local dy = select(2, ImGui.GetMouseDragDelta(0, 0))
            local newPct = state.pct + (dy / parentH)
            state.pct = math.max(state.minPct, math.min(state.maxPct, newPct))
            ImGui.ResetMouseDragDelta()
        else
            local totalW = ImGui.GetContentRegionAvail()
            -- For horizontal, use parent window width
            local parentW = ImGui.GetWindowContentRegionWidth()
            local dx = ImGui.GetMouseDragDelta(0, 0)
            local newPct = state.pct + (dx / parentW)
            state.pct = math.max(state.minPct, math.min(state.maxPct, newPct))
            ImGui.ResetMouseDragDelta()
        end
    end

    -- Resize cursor
    if state.hovering or state.dragging then
        if isVertical then
            ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeNS)
        else
            ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
        end
    end

    if not isVertical then
        ImGui.SameLine()
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Horizontal split (left | right)
-- @param id string: Unique splitter ID
-- @param leftFn function: Renders left panel content
-- @param rightFn function: Renders right panel content
-- @param opts table|nil: { defaultPct=0.5, minPct=0.1, maxPct=0.9, grabWidth=6 }
-- @return number: Current split percentage
function splitter.horizontal(id, leftFn, rightFn, opts)
    local state = getState(id, opts)
    local grabW = state.grabWidth

    -- Calculate panel widths from available space
    local availW = ImGui.GetContentRegionAvail()
    local usableW = availW - grabW
    local leftW = math.floor(usableW * state.pct)
    local rightW = usableW - leftW

    -- Left panel
    ImGui.BeginChild("##splitter_left_" .. id, leftW, 0, false)
    if leftFn then leftFn() end
    ImGui.EndChild()

    -- Grab bar
    drawGrabBar(id, state, false)

    -- Right panel
    ImGui.BeginChild("##splitter_right_" .. id, rightW, 0, false)
    if rightFn then rightFn() end
    ImGui.EndChild()

    return state.pct
end

--- Vertical split (top / bottom)
-- @param id string: Unique splitter ID
-- @param topFn function: Renders top panel content
-- @param bottomFn function: Renders bottom panel content
-- @param opts table|nil: { defaultPct=0.5, minPct=0.1, maxPct=0.9, grabWidth=6 }
-- @return number: Current split percentage
function splitter.vertical(id, topFn, bottomFn, opts)
    local state = getState(id, opts)
    local grabH = state.grabWidth

    -- Calculate panel heights from available space
    local _, availH = ImGui.GetContentRegionAvail()
    local usableH = availH - grabH
    local topH = math.floor(usableH * state.pct)
    local bottomH = usableH - topH

    -- Top panel
    local availW = ImGui.GetContentRegionAvail()
    ImGui.BeginChild("##splitter_top_" .. id, availW, topH, false)
    if topFn then topFn() end
    ImGui.EndChild()

    -- Grab bar
    drawGrabBar(id, state, true)

    -- Bottom panel
    ImGui.BeginChild("##splitter_bottom_" .. id, availW, bottomH, false)
    if bottomFn then bottomFn() end
    ImGui.EndChild()

    return state.pct
end

--- Get current split percentage for an ID
-- @param id string: Splitter ID
-- @return number|nil: Current percentage, or nil if not initialized
function splitter.getSplitPct(id)
    local state = splitStates[id]
    return state and state.pct or nil
end

--- Set split percentage programmatically
-- @param id string: Splitter ID
-- @param pct number: New percentage (will be clamped to min/max)
function splitter.setSplitPct(id, pct)
    local state = splitStates[id]
    if state then
        state.pct = math.max(state.minPct, math.min(state.maxPct, pct))
    end
end

--- Reset to default percentage
-- @param id string: Splitter ID
function splitter.reset(id)
    local state = splitStates[id]
    if state then
        state.pct = state.defaultPct
    end
end

-- Aliases for brevity
splitter.h = splitter.horizontal
splitter.v = splitter.vertical

return splitter
