------------------------------------------------------
-- WindowUtils - Splitter Module
-- Draggable panel dividers for two-panel layouts
------------------------------------------------------

local styles = require("modules/styles")

local splitter = {}

local TRANSPARENT = { 0, 0, 0, 0 }
local SNAP_INCREMENT = 0.05
local COLLAPSE_SPEED = 6.0
local COLLAPSE_MIN = 0.01

local function isCtrlHeld()
    return ImGui.IsKeyDown(ImGuiKey.LeftCtrl) or ImGui.IsKeyDown(ImGuiKey.RightCtrl)
end

local function snapValue(val)
    return math.floor(val / SNAP_INCREMENT + 0.5) * SNAP_INCREMENT
end

--------------------------------------------------------------------------------
-- Size Specification Helpers
--------------------------------------------------------------------------------

--- Parse a size spec: number (pixels), string "30%" (percentage), or nil (flex)
local function parseSizeSpec(spec, available)
    if type(spec) == "number" then
        return spec
    elseif type(spec) == "string" then
        local pct = tonumber(spec:match("^(%d+%.?%d*)%%$"))
        if pct then
            return math.floor(available * pct / 100)
        end
    end
    return nil
end

--- Compute initial pixel sizes from panel definitions
local function computeInitialSizes(panels, available, isVertical)
    local sizeKey = isVertical and "height" or "width"
    local minKey = isVertical and "minHeight" or "minWidth"
    local maxKey = isVertical and "maxHeight" or "maxWidth"
    local n = #panels

    local sizes = {}
    local fixedTotal = 0
    local flexTotal = 0
    local flexIndices = {}

    -- Phase 1: classify each panel
    for i = 1, n do
        local p = panels[i]
        local sz = parseSizeSpec(p[sizeKey], available)
        if sz then
            sizes[i] = sz
            fixedTotal = fixedTotal + sz
        else
            local weight = p.flex or 1
            sizes[i] = weight
            flexTotal = flexTotal + weight
            flexIndices[#flexIndices + 1] = i
        end
    end

    -- Phase 2: distribute remaining space to flex panels
    local remaining = available - fixedTotal
    if remaining < 0 then remaining = 0 end
    for _, i in ipairs(flexIndices) do
        local weight = sizes[i]
        sizes[i] = flexTotal > 0 and math.floor(remaining * weight / flexTotal) or 0
    end

    -- Phase 3: clamp to min/max
    for i = 1, n do
        local p = panels[i]
        local minSz = parseSizeSpec(p[minKey], available)
        local maxSz = parseSizeSpec(p[maxKey], available)
        if minSz and sizes[i] < minSz then sizes[i] = minSz end
        if maxSz and sizes[i] > maxSz then sizes[i] = maxSz end
    end

    return sizes
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local splitStates = {}

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
            dragging = false,
            -- Collapse animation
            collapsed = false,
            restorePct = nil,
            animFrom = nil,
            animTo = nil,
            animProgress = 1.0,
            animLastTime = nil
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
        childW = 0
        childH = grabW
    else
        childW = grabW
        childH = 0
    end

    local grabFlags = ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
    if ImGui.BeginChild("##splitter_grab_" .. id, childW, childH, false, grabFlags) then
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

    -- Double-click to collapse/expand (only for 2-panel states with pct)
    if state.hovering and ImGui.IsMouseDoubleClicked(0) and state.pct then
        state.dragging = false
        if not state.collapsed then
            state.restorePct = state.pct
            local target
            if state.pct <= 0.5 then
                target = state.minPct
            else
                target = state.maxPct
            end
            state.collapsed = true
            state.animFrom = state.pct
            state.animTo = target
            state.animProgress = 0.0
            state.animLastTime = os.clock()
        else
            state.animFrom = state.pct
            state.animTo = state.restorePct or state.defaultPct
            state.animProgress = 0.0
            state.animLastTime = os.clock()
            state.collapsed = false
        end
    end

    -- Animation tick
    if state.animProgress and state.animProgress < 1.0 and state.pct then
        local now = os.clock()
        local dt = now - (state.animLastTime or now)
        state.animLastTime = now
        state.animProgress = math.min(1.0, state.animProgress + COLLAPSE_SPEED * dt)
        local t = state.animProgress
        local eased = t * t * (3 - 2 * t)
        state.pct = state.animFrom + (state.animTo - state.animFrom) * eased
        state.dragging = false
    end

    -- Cancel collapse if user starts dragging
    if state.dragging and state.collapsed then
        state.collapsed = false
        state.animProgress = 1.0
    end

    -- Apply drag delta (only for states with pct; multi handles its own)
    if state.dragging and state.pct and (not state.animProgress or state.animProgress >= 1.0) then
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

    ImGui.BeginChild("##splitter_left_" .. id, leftW, 0, false)
    if leftFn then leftFn() end
    ImGui.EndChild()

    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)

    drawGrabBar(id, state, false)

    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)

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

    ImGui.BeginChild("##splitter_top_" .. id, availW, topH, false)
    if topFn then topFn() end
    ImGui.EndChild()

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

    drawGrabBar(id, state, true)

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

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
        state.collapsed = false
        state.animProgress = 1.0
    end
end

--------------------------------------------------------------------------------
-- Multi-panel split (flat breakpoints with independent dividers)
--------------------------------------------------------------------------------

local multiStates = {}

local function getMultiState(id, n, opts, panels)
    -- Recreate state if panel count changed
    if multiStates[id] and #multiStates[id].dividers ~= n - 1 then
        multiStates[id] = nil
    end
    if not multiStates[id] then
        opts = opts or {}
        local grabWidth = opts.grabWidth or ImGui.GetStyle().ItemSpacing.x
        local defaultPcts = opts.defaultPcts
        local minGap = opts.minPct or 0.05
        local isVertical = (opts.direction or "horizontal") == "vertical"

        -- Create N-1 breakpoints as cumulative fractions (0..1)
        local breakpoints = {}
        local hasWeightedPanels = false

        if panels then
            local sizeKey = isVertical and "height" or "width"
            for _, p in ipairs(panels) do
                if p[sizeKey] or p.flex then
                    hasWeightedPanels = true
                    break
                end
            end
        end

        if hasWeightedPanels then
            local refSize = 1000
            local sizes = computeInitialSizes(panels, refSize, isVertical)
            local total = 0
            for i = 1, n do total = total + sizes[i] end
            if total < 1 then total = 1 end
            local cumulative = 0
            for i = 1, n - 1 do
                cumulative = cumulative + sizes[i]
                breakpoints[i] = cumulative / total
            end
        elseif defaultPcts and #defaultPcts >= n then
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

        -- Divider states
        local dividers = {}
        for i = 1, n - 1 do
            dividers[i] = {
                grabWidth = grabWidth,
                hovering = false,
                dragging = false,
                -- Collapse animation
                collapsed = false,
                restoreBp = nil,
                animFrom = nil,
                animTo = nil,
                animProgress = 1.0,
                animLastTime = nil
            }
        end

        local defaults = {}
        for i = 1, #breakpoints do defaults[i] = breakpoints[i] end

        multiStates[id] = {
            breakpoints = breakpoints,
            defaults = defaults,
            dividers = dividers,
            grabWidth = grabWidth,
            minGap = minGap,
            panelDefs = panels,
            isVertical = isVertical
        }
    end
    return multiStates[id]
end

--- Get minimum fraction for a panel based on its constraints
local function getPanelMinFrac(panelDefs, panelIdx, totalSize, minGap, isVertical)
    if not panelDefs or not panelDefs[panelIdx] then return minGap end
    local key = isVertical and "minHeight" or "minWidth"
    local spec = panelDefs[panelIdx][key]
    local px = parseSizeSpec(spec, totalSize)
    return px and math.max(px / totalSize, COLLAPSE_MIN) or minGap
end

--- Get maximum fraction for a panel based on its constraints
local function getPanelMaxFrac(panelDefs, panelIdx, totalSize, isVertical)
    if not panelDefs or not panelDefs[panelIdx] then return 1.0 end
    local key = isVertical and "maxHeight" or "maxWidth"
    local spec = panelDefs[panelIdx][key]
    local px = parseSizeSpec(spec, totalSize)
    return px and (px / totalSize) or 1.0
end

--- Render a right-click context menu for a multi-splitter divider
local function drawContextMenu(id, i, ms, isVertical)
    if ImGui.BeginPopupContextItem("##splitter_ctx_" .. id .. "_d" .. i) then
        local resetLabel = isVertical and "Reset Column" or "Reset Row"
        if ImGui.MenuItem(resetLabel) then
            for j = 1, #ms.defaults do
                ms.breakpoints[j] = ms.defaults[j]
                ms.dividers[j].collapsed = false
                ms.dividers[j].animProgress = 1.0
            end
        end
        if ImGui.MenuItem("Reset All") then
            for _, state in pairs(multiStates) do
                for j = 1, #state.defaults do
                    state.breakpoints[j] = state.defaults[j]
                end
                for j = 1, #state.dividers do
                    state.dividers[j].collapsed = false
                    state.dividers[j].animProgress = 1.0
                end
            end
        end
        ImGui.EndPopup()
    end
end

--- Multi-panel layout with independent flat breakpoints.
--- Each divider moves independently — dragging divider i only affects panels i and i+1.
function splitter.multi(id, panels, opts)
    if not panels or #panels < 2 then return end
    opts = opts or {}
    local n = #panels
    local isVertical = (opts.direction or "horizontal") == "vertical"
    local ms = getMultiState(id, n, opts, panels)
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
                drawContextMenu(id, i, ms, isVertical)
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
                drawContextMenu(id, i, ms, isVertical)
                ImGui.SameLine()
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)
            end
        end
    end

    -- Double-click divider: collapse/expand the smaller adjacent panel
    for i = 1, n - 1 do
        if ms.dividers[i].hovering and ImGui.IsMouseDoubleClicked(0) then
            local div = ms.dividers[i]
            div.dragging = false

            if not div.collapsed then
                local leftStart = (i == 1) and 0 or ms.breakpoints[i - 1]
                local rightEnd = (i == n - 1) and 1 or ms.breakpoints[i + 1]
                local leftSize = ms.breakpoints[i] - leftStart
                local rightSize = rightEnd - ms.breakpoints[i]

                div.restoreBp = ms.breakpoints[i]

                if leftSize <= rightSize then
                    div.animTo = leftStart + COLLAPSE_MIN
                else
                    div.animTo = rightEnd - COLLAPSE_MIN
                end

                div.collapsed = true
                div.animFrom = ms.breakpoints[i]
                div.animProgress = 0.0
                div.animLastTime = os.clock()
            else
                div.animFrom = ms.breakpoints[i]
                div.animTo = div.restoreBp or ms.defaults[i]
                div.animProgress = 0.0
                div.animLastTime = os.clock()
                div.collapsed = false
            end
            break
        end
    end

    -- Animation tick for multi dividers
    for i = 1, n - 1 do
        local div = ms.dividers[i]
        if div.animProgress and div.animProgress < 1.0 then
            local now = os.clock()
            local dt = now - (div.animLastTime or now)
            div.animLastTime = now
            div.animProgress = math.min(1.0, div.animProgress + COLLAPSE_SPEED * dt)
            local t = div.animProgress
            local eased = t * t * (3 - 2 * t)
            ms.breakpoints[i] = div.animFrom + (div.animTo - div.animFrom) * eased
            div.dragging = false
        end
    end

    -- Apply drag updates AFTER all rendering (prevents one-frame desync / rubber banding)
    for i = 1, n - 1 do
        if ms.dividers[i].dragging and (not ms.dividers[i].animProgress or ms.dividers[i].animProgress >= 1.0) then
            -- Cancel collapse if user drags
            if ms.dividers[i].collapsed then
                ms.dividers[i].collapsed = false
                ms.dividers[i].animProgress = 1.0
            end

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

                    if oldBp > 0 then
                        local leftScale = newBp / oldBp
                        for j = 1, i - 1 do
                            ms.breakpoints[j] = ms.breakpoints[j] * leftScale
                        end
                    end

                    if oldBp < 1 then
                        local rightScale = (1 - newBp) / (1 - oldBp)
                        for j = i + 1, n - 1 do
                            ms.breakpoints[j] = newBp + (ms.breakpoints[j] - oldBp) * rightScale
                        end
                    end
                else
                    -- Constraint-aware clamping
                    local loBase = (i == 1) and 0 or ms.breakpoints[i - 1]
                    local hiBase = (i == n - 1) and 1 or ms.breakpoints[i + 1]

                    local leftMin = getPanelMinFrac(ms.panelDefs, i, totalSize, minGap, isVertical)
                    local rightMin = getPanelMinFrac(ms.panelDefs, i + 1, totalSize, minGap, isVertical)
                    local leftMax = getPanelMaxFrac(ms.panelDefs, i, totalSize, isVertical)
                    local rightMax = getPanelMaxFrac(ms.panelDefs, i + 1, totalSize, isVertical)

                    local lo = loBase + leftMin
                    local hi = hiBase - rightMin

                    -- Enforce max constraints
                    local loMax = loBase + leftMax
                    local hiMin = hiBase - rightMax
                    if loMax < hi then hi = math.min(hi, loMax) end
                    if hiMin > lo then lo = math.max(lo, hiMin) end

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
        for i = 1, #ms.dividers do
            ms.dividers[i].collapsed = false
            ms.dividers[i].animProgress = 1.0
        end
    end
end

-- Aliases for brevity
splitter.h = splitter.horizontal
splitter.v = splitter.vertical
splitter.m = splitter.multi

return splitter
