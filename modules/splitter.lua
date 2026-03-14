------------------------------------------------------
-- WindowUtils - Splitter Module
-- Draggable panel dividers for two-panel layouts
------------------------------------------------------

local styles = require("modules/styles")

local splitter = {}

local TRANSPARENT = { 0, 0, 0, 0 }
local SNAP_INCREMENT = 0.05

local function isCtrlHeld()
    return ImGui.IsKeyDown(ImGuiKey.LeftCtrl) or ImGui.IsKeyDown(ImGuiKey.RightCtrl)
end

local function snapValue(val)
    return math.floor(val / SNAP_INCREMENT + 0.5) * SNAP_INCREMENT
end

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

    -- Double-click to reset
    if state.hovering and ImGui.IsMouseDoubleClicked(0) then
        if state.pct and state.defaultPct then
            state.pct = state.defaultPct
        end
        state.dragging = false
    end

    -- Apply drag delta (only for states with pct; multi handles its own)
    if state.dragging and state.pct then
        -- Save origin on drag start
        if not state.dragStart then state.dragStart = state.pct end

        if isVertical then
            local _, parentH = ImGui.GetWindowSize()
            local dy = select(2, ImGui.GetMouseDragDelta(0, 0))
            local newPct = state.dragStart + (dy / parentH)
            if isCtrlHeld() then newPct = snapValue(newPct) end
            state.pct = math.max(state.minPct, math.min(state.maxPct, newPct))
        else
            local parentW = ImGui.GetWindowContentRegionWidth()
            local dx = ImGui.GetMouseDragDelta(0, 0)
            local newPct = state.dragStart + (dx / parentW)
            if isCtrlHeld() then newPct = snapValue(newPct) end
            state.pct = math.max(state.minPct, math.min(state.maxPct, newPct))
        end
    else
        state.dragStart = nil
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

--------------------------------------------------------------------------------
-- Multi-panel split (flat breakpoints with independent dividers)
--------------------------------------------------------------------------------

local multiStates = {} -- [id] = { breakpoints, defaults, dividers, grabWidth, minGap }

local function getMultiState(id, n, opts)
    if not multiStates[id] then
        opts = opts or {}
        local grabWidth = opts.grabWidth or ImGui.GetStyle().ItemSpacing.x
        local defaultPcts = opts.defaultPcts
        local minGap = opts.minPct or 0.05

        -- Create N-1 breakpoints as cumulative fractions (0..1)
        local breakpoints = {}
        if defaultPcts and #defaultPcts >= n then
            local cumulative = 0
            for i = 1, n - 1 do
                cumulative = cumulative + defaultPcts[i]
                breakpoints[i] = cumulative
            end
        else
            for i = 1, n - 1 do
                breakpoints[i] = i / n
            end
        end

        -- Divider states (no pct — drag applied by multi() itself)
        local dividers = {}
        for i = 1, n - 1 do
            dividers[i] = {
                grabWidth = grabWidth,
                hovering = false,
                dragging = false
            }
        end

        local defaults = {}
        for i = 1, #breakpoints do defaults[i] = breakpoints[i] end

        multiStates[id] = {
            breakpoints = breakpoints,
            defaults = defaults,
            dividers = dividers,
            grabWidth = grabWidth,
            minGap = minGap
        }
    end
    return multiStates[id]
end

--- Multi-panel layout with independent flat breakpoints.
--- Each divider moves independently — dragging divider i only affects panels i and i+1.
function splitter.multi(id, panels, opts)
    if not panels or #panels < 2 then return end
    opts = opts or {}
    local n = #panels
    local isVertical = (opts.direction or "horizontal") == "vertical"
    local ms = getMultiState(id, n, opts)
    local grabW = ms.grabWidth
    local minGap = ms.minGap

    -- Pre-compute all panel sizes from current breakpoints (before any drag updates)
    local sizes = {}
    local totalSize, totalAvail

    if isVertical then
        local availW, availH = ImGui.GetContentRegionAvail()
        local spacingY = ImGui.GetStyle().ItemSpacing.y
        local usableH = availH - (n - 1) * grabW
        if usableH < 1 then return end
        totalSize = usableH
        totalAvail = availH

        local consumed = 0
        for i = 1, n do
            local startFrac = (i == 1) and 0 or ms.breakpoints[i - 1]
            local endFrac = (i == n) and 1 or ms.breakpoints[i]
            if i == n then
                sizes[i] = usableH - consumed
            else
                sizes[i] = math.floor(usableH * (endFrac - startFrac))
                consumed = consumed + sizes[i]
            end
        end

        -- Render all panels and grab bars
        for i = 1, n do
            ImGui.BeginChild("##splitter_multi_" .. id .. "_p" .. i, availW, sizes[i], false)
            if panels[i].content then panels[i].content() end
            ImGui.EndChild()

            if i < n then
                ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)
                drawGrabBar(id .. "_d" .. i, ms.dividers[i], true)
                ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)
            end
        end
    else
        local availW = ImGui.GetContentRegionAvail()
        local spacingX = ImGui.GetStyle().ItemSpacing.x
        local usableW = availW - (n - 1) * grabW
        if usableW < 1 then return end
        totalSize = usableW
        totalAvail = availW

        local consumed = 0
        for i = 1, n do
            local startFrac = (i == 1) and 0 or ms.breakpoints[i - 1]
            local endFrac = (i == n) and 1 or ms.breakpoints[i]
            if i == n then
                sizes[i] = usableW - consumed
            else
                sizes[i] = math.floor(usableW * (endFrac - startFrac))
                consumed = consumed + sizes[i]
            end
        end

        -- Render all panels and grab bars
        for i = 1, n do
            ImGui.BeginChild("##splitter_multi_" .. id .. "_p" .. i, sizes[i], 0, false)
            if panels[i].content then panels[i].content() end
            ImGui.EndChild()

            if i < n then
                ImGui.SameLine()
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)
                drawGrabBar(id .. "_d" .. i, ms.dividers[i], false)
                ImGui.SameLine()
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)
            end
        end
    end

    -- Double-click any divider to reset ALL breakpoints to defaults
    for i = 1, n - 1 do
        if ms.dividers[i].hovering and ImGui.IsMouseDoubleClicked(0) then
            for j = 1, n - 1 do
                ms.breakpoints[j] = ms.defaults[j]
                ms.dividers[j].dragging = false
            end
            break
        end
    end

    -- Apply drag updates AFTER all rendering (prevents one-frame desync / rubber banding)
    for i = 1, n - 1 do
        if ms.dividers[i].dragging then
            -- Save origin on drag start
            if not ms.dividers[i].dragOrigin then
                ms.dividers[i].dragOrigin = ms.breakpoints[i]
            end

            local dx, dy = ImGui.GetMouseDragDelta(0, 0)
            local delta = isVertical and dy or dx
            if delta ~= 0 then
                local oldBp = ms.breakpoints[i]
                local newBp = ms.dividers[i].dragOrigin + (delta / totalSize)
                if isCtrlHeld() then
                    -- Snap in pixel space relative to full available width/height
                    -- so positions align across rows with different panel counts
                    local pixFrac = (newBp * totalSize + (i - 0.5) * grabW) / totalAvail
                    pixFrac = snapValue(pixFrac)
                    newBp = (pixFrac * totalAvail - (i - 0.5) * grabW) / totalSize
                end
                local shiftHeld = ImGui.IsKeyDown(ImGuiKey.LeftShift)
                              or ImGui.IsKeyDown(ImGuiKey.RightShift)

                if shiftHeld then
                    -- Shift: scale all other breakpoints proportionally
                    newBp = math.max(minGap, math.min(1 - minGap, newBp))
                    ms.breakpoints[i] = newBp

                    -- Scale left side: remap [0, oldBp] -> [0, newBp]
                    if oldBp > 0 then
                        local leftScale = newBp / oldBp
                        for j = 1, i - 1 do
                            ms.breakpoints[j] = ms.breakpoints[j] * leftScale
                        end
                    end

                    -- Scale right side: remap [oldBp, 1] -> [newBp, 1]
                    if oldBp < 1 then
                        local rightScale = (1 - newBp) / (1 - oldBp)
                        for j = i + 1, n - 1 do
                            ms.breakpoints[j] = newBp + (ms.breakpoints[j] - oldBp) * rightScale
                        end
                    end
                else
                    -- No shift: only affect adjacent panels
                    local lo = (i == 1) and minGap or (ms.breakpoints[i - 1] + minGap)
                    local hi = (i == n - 1) and (1 - minGap) or (ms.breakpoints[i + 1] - minGap)
                    ms.breakpoints[i] = math.max(lo, math.min(hi, newBp))
                end
            end
        else
            ms.dividers[i].dragOrigin = nil
        end
    end
end

--- Reset a multi-splitter to default breakpoints
function splitter.resetMulti(id)
    local ms = multiStates[id]
    if ms then
        for i = 1, #ms.defaults do
            ms.breakpoints[i] = ms.defaults[i]
        end
    end
end

-- Aliases for brevity
splitter.h = splitter.horizontal
splitter.v = splitter.vertical
splitter.m = splitter.multi

return splitter
