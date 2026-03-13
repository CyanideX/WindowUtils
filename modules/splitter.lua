------------------------------------------------------
-- WindowUtils - Splitter Module
-- Draggable panel dividers for two-panel layouts
------------------------------------------------------

local styles = require("modules/styles")

local splitter = {}

local TRANSPARENT = { 0, 0, 0, 0 }

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
            grabWidth = opts.grabWidth or ImGui.GetStyle().ItemSpacing.x,
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
local iconSizeCache = {}

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
        bgColor = TRANSPARENT
    end

    local iconColor
    if state.dragging or state.hovering then
        iconColor = styles.colors.splitterIconHi or styles.colors.textWhite
    else
        iconColor = styles.colors.splitterIcon or styles.colors.greyLight
    end

    local grabW = state.grabWidth
    local icon = isVertical and getGrabIconV() or getGrabIcon()

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

    local grabFlags = ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
    if ImGui.BeginChild("##splitter_grab_" .. id, childW, childH, false, grabFlags) then
        -- Center the icon (cache text size per icon string)
        local winW, winH = ImGui.GetWindowSize()
        if not iconSizeCache[icon] then
            iconSizeCache[icon] = { ImGui.CalcTextSize(icon) }
        end
        local textW, textH = iconSizeCache[icon][1], iconSizeCache[icon][2]
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
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Horizontal split (left | right)
function splitter.horizontal(id, leftFn, rightFn, opts)
    local state = getState(id, opts)
    local grabW = state.grabWidth
    local spacingX = ImGui.GetStyle().ItemSpacing.x

    local availW = ImGui.GetContentRegionAvail()
    local usableW = availW - grabW
    local leftW = math.floor(usableW * state.pct)
    local rightW = usableW - leftW

    -- Left panel
    ImGui.BeginChild("##splitter_left_" .. id, leftW, 0, false)
    if leftFn then leftFn() end
    ImGui.EndChild()

    -- Flush: remove SameLine spacing gap
    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)

    -- Grab bar
    drawGrabBar(id, state, false)

    -- Flush: remove SameLine spacing gap
    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)

    -- Right panel
    ImGui.BeginChild("##splitter_right_" .. id, rightW, 0, false)
    if rightFn then rightFn() end
    ImGui.EndChild()

    return state.pct
end

--- Vertical split (top / bottom)
function splitter.vertical(id, topFn, bottomFn, opts)
    local state = getState(id, opts)
    local grabH = state.grabWidth
    local spacingY = ImGui.GetStyle().ItemSpacing.y

    local availW, availH = ImGui.GetContentRegionAvail()
    local usableH = availH - grabH
    local topH = math.floor(usableH * state.pct)
    local bottomH = usableH - topH

    -- Top panel
    ImGui.BeginChild("##splitter_top_" .. id, availW, topH, false)
    if topFn then topFn() end
    ImGui.EndChild()

    -- Flush: remove implicit vertical spacing
    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

    -- Grab bar
    drawGrabBar(id, state, true)

    -- Flush: remove implicit vertical spacing
    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

    -- Bottom panel
    ImGui.BeginChild("##splitter_bottom_" .. id, availW, bottomH, false)
    if bottomFn then bottomFn() end
    ImGui.EndChild()

    return state.pct
end

--- Get current split percentage for an ID
function splitter.getSplitPct(id)
    local state = splitStates[id]
    return state and state.pct or nil
end

--- Set split percentage programmatically
function splitter.setSplitPct(id, pct)
    local state = splitStates[id]
    if state then
        state.pct = math.max(state.minPct, math.min(state.maxPct, pct))
    end
end

--- Reset to default percentage
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
