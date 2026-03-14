------------------------------------------------------
-- WindowUtils - Splitter Module
-- Draggable panel dividers for two-panel layouts
------------------------------------------------------

local styles = require("modules/styles")
local utils = require("modules/utils")

local splitter = {}

local TRANSPARENT = { 0, 0, 0, 0 }
local COLLAPSE_SPEED = 6.0
local COLLAPSE_MIN = 0.01

local isCtrlHeld = utils.isCtrlHeld
local isShiftHeld = utils.isShiftHeld
local snapValue = function(val) return utils.snapToIncrement(val) end

--------------------------------------------------------------------------------
-- Size Specification Helpers
--------------------------------------------------------------------------------

local parseSizeSpec = utils.parseSizeSpec

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
---@param id string Unique splitter identifier
---@param leftFn? function Render callback for the left panel
---@param rightFn? function Render callback for the right panel
---@param opts? table Options: defaultPct, minPct, maxPct, grabWidth
---@return number pct Current split fraction (0..1)
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
---@param id string Unique splitter identifier
---@param topFn? function Render callback for the top panel
---@param bottomFn? function Render callback for the bottom panel
---@param opts? table Options: defaultPct, minPct, maxPct, grabWidth
---@return number pct Current split fraction (0..1)
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
---@param id string Splitter identifier
---@return number|nil pct Current split fraction, or nil if not found
function splitter.getSplitPct(id)
    local state = splitStates[id]
    return state and state.pct or nil
end

--- Set split percentage programmatically
---@param id string Splitter identifier
---@param pct number Desired split fraction (clamped to minPct..maxPct)
function splitter.setSplitPct(id, pct)
    local state = splitStates[id]
    if state then
        state.pct = math.max(state.minPct, math.min(state.maxPct, pct))
    end
end

--- Reset to default percentage
---@param id string Splitter identifier
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
                -- Animation (used by context menu reset)
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

--- Get minimum fraction for a panel based on its constraints.
--- When no explicit min is set, auto-floors to icon button width + window padding.
--- Set autoMin = false on a panel definition to opt out.
local function getPanelMinFrac(panelDefs, panelIdx, totalSize, minGap, isVertical)
    if not panelDefs or not panelDefs[panelIdx] then return minGap end
    local panel = panelDefs[panelIdx]
    local key = isVertical and "minHeight" or "minWidth"
    local spec = panel[key]
    local px = parseSizeSpec(spec, totalSize)

    -- Auto-detect minimum when no explicit min is set
    if not px and panel.autoMin ~= false then
        local autoMinPx = utils.minIconButtonWidth()
        local padKey = isVertical and "y" or "x"
        autoMinPx = autoMinPx + ImGui.GetStyle().WindowPadding[padKey] * 2
        px = autoMinPx
    end

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

--------------------------------------------------------------------------------
-- Toggle Panel helpers (shared by splitter.multi edge toggles and splitter.toggle)
--------------------------------------------------------------------------------

local toggleStates = {}

local _chevrons = nil
local function ensureChevrons()
    if _chevrons then return end
    _chevrons = {
        left  = IconGlyphs and IconGlyphs.ChevronLeft or "<",
        right = IconGlyphs and IconGlyphs.ChevronRight or ">",
        up    = IconGlyphs and IconGlyphs.ChevronUp or "^",
        down  = IconGlyphs and IconGlyphs.ChevronDown or "v",
    }
end

local function getToggleIcon(side, isOpen)
    ensureChevrons()
    if side == "left" then
        return isOpen and _chevrons.left or _chevrons.right
    elseif side == "right" then
        return isOpen and _chevrons.right or _chevrons.left
    elseif side == "top" then
        return isOpen and _chevrons.up or _chevrons.down
    else
        return isOpen and _chevrons.down or _chevrons.up
    end
end

local function getToggleState(id, opts)
    if not toggleStates[id] then
        opts = opts or {}
        toggleStates[id] = {
            isOpen = opts.defaultOpen ~= false,
            animProgress = (opts.defaultOpen ~= false) and 1.0 or 0.0,
            lastTime = os.clock(),
            speed = opts.speed or COLLAPSE_SPEED,
            barWidth = opts.barWidth or ImGui.GetStyle().ItemSpacing.x,
            hovering = false,
        }
    end
    return toggleStates[id]
end

local function drawToggleBar(id, state, side)
    local isVert = (side == "top" or side == "bottom")
    local icon = getToggleIcon(side, state.isOpen)
    local barW = state.barWidth

    local bgColor = state.hovering
        and (styles.colors.splitterHover or { 0.3, 0.5, 0.7, 0.5 })
        or TRANSPARENT
    local iconColor = state.hovering
        and (styles.colors.splitterIconHi or styles.colors.textWhite)
        or (styles.colors.splitterIcon or styles.colors.greyLight)

    ImGui.PushStyleColor(ImGuiCol.ChildBg,
        ImGui.GetColorU32(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)

    local childW = isVert and 0 or barW
    local childH = isVert and barW or 0
    local grabFlags = ImGuiWindowFlags.NoMove
        + ImGuiWindowFlags.NoScrollbar
        + ImGuiWindowFlags.NoScrollWithMouse

    if ImGui.BeginChild("##toggle_bar_" .. id, childW, childH, false, grabFlags) then
        local winW, winH = ImGui.GetWindowSize()
        if not iconSizeCache[icon] then
            iconSizeCache[icon] = { ImGui.CalcTextSize(icon) }
        end
        local textW, textH = iconSizeCache[icon][1], iconSizeCache[icon][2]
        ImGui.SetCursorPosX((winW - textW) / 2)
        ImGui.SetCursorPosY((winH - textH) / 2)

        ImGui.PushStyleColor(ImGuiCol.Text,
            ImGui.GetColorU32(iconColor[1], iconColor[2], iconColor[3], iconColor[4]))
        ImGui.Text(icon)
        ImGui.PopStyleColor()
    end
    ImGui.EndChild()

    state.hovering = ImGui.IsItemHovered()

    ImGui.PopStyleVar()
    ImGui.PopStyleColor()

    if state.hovering and ImGui.IsItemClicked(0) then
        state.isOpen = not state.isOpen
    end

    if state.hovering then
        ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
    end
end

--- Render a right-click context menu for a multi-splitter divider
local function drawContextMenu(id, i, ms, isVertical)
    if ImGui.BeginPopupContextItem("##splitter_ctx_" .. id .. "_d" .. i) then
        local resetLabel = isVertical and "Reset Column" or "Reset Row"
        if ImGui.MenuItem(resetLabel) then
            for j = 1, #ms.defaults do
                ms.breakpoints[j] = ms.defaults[j]
            end
        end
        if ImGui.MenuItem("Reset All") then
            for _, state in pairs(multiStates) do
                for j = 1, #state.defaults do
                    state.breakpoints[j] = state.defaults[j]
                end
            end
        end
        ImGui.EndPopup()
    end
end

--- Multi-panel layout with independent flat breakpoints.
--- Each divider moves independently — dragging divider i only affects panels i and i+1.
---@param id string Unique splitter identifier
---@param panels table Array of panel definitions ({ content, width/height, minWidth/minHeight, maxWidth/maxHeight, flex, toggle, size })
---@param opts? table Options: direction ("horizontal"|"vertical"), grabWidth, minPct, defaultPcts
function splitter.multi(id, panels, opts)
    if not panels or #panels < 2 then return end
    opts = opts or {}
    local n = #panels
    local isVertical = (opts.direction or "horizontal") == "vertical"

    -- Detect edge toggle panels (only first/last may be toggles)
    local leadToggle = panels[1] and panels[1].toggle and panels[1] or nil
    local trailToggle = panels[n] and panels[n].toggle and panels[n] or nil

    -- Build core (draggable) panel list
    local corePanels = {}
    local coreStart = leadToggle and 2 or 1
    local coreEnd = trailToggle and (n - 1) or n
    for i = coreStart, coreEnd do
        corePanels[#corePanels + 1] = panels[i]
    end
    local coreN = #corePanels
    if coreN < 1 then return end

    local ms = getMultiState(id, coreN, opts, corePanels)
    local grabW = ms.grabWidth
    local minGap = ms.minGap

    -- Available space
    local availW, availH = ImGui.GetContentRegionAvail()
    local totalAvail = isVertical and availH or availW
    local spacing = isVertical and ImGui.GetStyle().ItemSpacing.y
                                or ImGui.GetStyle().ItemSpacing.x

    -- Toggle animation helper (same smoothstep as splitter.toggle)
    local function tickToggle(tglState)
        local now = os.clock()
        local dt = now - tglState.lastTime
        tglState.lastTime = now
        local target = tglState.isOpen and 1.0 or 0.0
        if tglState.animProgress < target then
            tglState.animProgress = math.min(target, tglState.animProgress + tglState.speed * dt)
        elseif tglState.animProgress > target then
            tglState.animProgress = math.max(target, tglState.animProgress - tglState.speed * dt)
        end
        local t = tglState.animProgress
        return t * t * (3 - 2 * t)
    end

    -- Compute toggle animated sizes
    local leadState, leadSize, leadBarW = nil, 0, 0
    if leadToggle then
        leadState = getToggleState(id .. "_tgl_lead", leadToggle)
        local eased = tickToggle(leadState)
        local expandedSize = parseSizeSpec(leadToggle.size, totalAvail) or 0
        leadSize = math.floor(expandedSize * eased)
        leadBarW = leadState.barWidth
    end

    local trailState, trailSize, trailBarW = nil, 0, 0
    if trailToggle then
        trailState = getToggleState(id .. "_tgl_trail", trailToggle)
        local eased = tickToggle(trailState)
        local expandedSize = parseSizeSpec(trailToggle.size, totalAvail) or 0
        trailSize = math.floor(expandedSize * eased)
        trailBarW = trailState.barWidth
    end

    -- Core panel space = total minus toggle panels and bars
    local toggleSpace = leadSize + leadBarW + trailSize + trailBarW
    local coreAvail = totalAvail - toggleSpace
    local coreUsable = coreAvail - (coreN > 1 and (coreN - 1) * grabW or 0)
    if coreUsable < 1 then return end
    local totalSize = coreUsable

    -- Compute core panel pixel sizes from breakpoints
    local sizes = {}
    local consumed = 0
    for i = 1, coreN do
        local startFrac = (i == 1) and 0 or ms.breakpoints[i - 1]
        local endFrac = (i == coreN) and 1 or ms.breakpoints[i]
        if i == coreN then
            sizes[i] = coreUsable - consumed
        else
            sizes[i] = math.floor(coreUsable * (endFrac - startFrac))
            consumed = consumed + sizes[i]
        end
    end

    -- Cancel ItemSpacing between elements (matches splitter.horizontal / .vertical)
    local function cancelSpacing()
        if isVertical then
            ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacing)
        else
            ImGui.SameLine()
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacing)
        end
    end

    local noScroll = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
    local leadSide = isVertical and "top" or "left"
    local trailSide = isVertical and "bottom" or "right"

    -- 1. Lead toggle panel + toggle bar
    if leadToggle then
        if leadSize > 0 then
            local cw = isVertical and availW or leadSize
            local ch = isVertical and leadSize or 0
            ImGui.BeginChild("##splitter_multi_" .. id .. "_tgl_lead", cw, ch, false, noScroll)
            if leadToggle.content then leadToggle.content() end
            ImGui.EndChild()
            cancelSpacing()
        end
        drawToggleBar(id .. "_tgl_lead", leadState, leadSide)
        cancelSpacing()
    end

    -- 2. Core panels with dividers
    for i = 1, coreN do
        local cw = isVertical and availW or sizes[i]
        local ch = isVertical and sizes[i] or 0
        ImGui.BeginChild("##splitter_multi_" .. id .. "_p" .. i, cw, ch, false)
        if corePanels[i].content then corePanels[i].content() end
        ImGui.EndChild()

        if i < coreN then
            cancelSpacing()
            drawGrabBar(id .. "_d" .. i, ms.dividers[i], isVertical)
            drawContextMenu(id, i, ms, isVertical)
            cancelSpacing()
        end
    end

    -- 3. Trail toggle bar + toggle panel
    if trailToggle then
        cancelSpacing()
        drawToggleBar(id .. "_tgl_trail", trailState, trailSide)
        if trailSize > 0 then
            cancelSpacing()
            local cw = isVertical and availW or trailSize
            local ch = isVertical and trailSize or 0
            ImGui.BeginChild("##splitter_multi_" .. id .. "_tgl_trail", cw, ch, false, noScroll)
            if trailToggle.content then trailToggle.content() end
            ImGui.EndChild()
        end
    end

    -- Animation tick for multi dividers (used by context menu "Reset")
    for i = 1, coreN - 1 do
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
    for i = 1, coreN - 1 do
        if ms.dividers[i].dragging and (not ms.dividers[i].animProgress or ms.dividers[i].animProgress >= 1.0) then
            if not ms.dividers[i].dragOrigin then
                ms.dividers[i].dragOrigin = ms.breakpoints[i]
            end

            local dx, dy = ImGui.GetMouseDragDelta(0, 0)
            local delta = isVertical and dy or dx
            if delta ~= 0 then
                local oldBp = ms.breakpoints[i]
                local newBp = ms.dividers[i].dragOrigin + (delta / totalSize)
                if isCtrlHeld() then
                    local pixFrac = (newBp * totalSize + (i - 0.5) * grabW) / coreAvail
                    pixFrac = snapValue(pixFrac)
                    newBp = (pixFrac * coreAvail - (i - 0.5) * grabW) / totalSize
                end
                local shiftHeld = isShiftHeld()

                if shiftHeld then
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
                        for j = i + 1, coreN - 1 do
                            ms.breakpoints[j] = newBp + (ms.breakpoints[j] - oldBp) * rightScale
                        end
                    end
                else
                    local loBase = (i == 1) and 0 or ms.breakpoints[i - 1]
                    local hiBase = (i == coreN - 1) and 1 or ms.breakpoints[i + 1]

                    local leftMin = getPanelMinFrac(ms.panelDefs, i, totalSize, minGap, isVertical)
                    local rightMin = getPanelMinFrac(ms.panelDefs, i + 1, totalSize, minGap, isVertical)
                    local leftMax = getPanelMaxFrac(ms.panelDefs, i, totalSize, isVertical)
                    local rightMax = getPanelMaxFrac(ms.panelDefs, i + 1, totalSize, isVertical)

                    local lo = loBase + leftMin
                    local hi = hiBase - rightMin

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
---@param id string Multi-splitter identifier
function splitter.resetMulti(id)
    local ms = multiStates[id]
    if ms then
        for i = 1, #ms.defaults do
            ms.breakpoints[i] = ms.defaults[i]
        end
        for i = 1, #ms.dividers do
            ms.dividers[i].animProgress = 1.0
        end
    end
end

--- Render a toggleable panel with animated open/close.
--- panels[1] = fixed/toggleable panel, panels[2] = flex panel.
---@param id string Unique toggle identifier
---@param panels table Two-element array: [1] = fixed panel { content }, [2] = flex panel { content }
---@param opts? table Options: side ("left"|"right"|"top"|"bottom"), size (number|string), defaultOpen (boolean), speed (number), barWidth (number)
---@return boolean isOpen Current open state
function splitter.toggle(id, panels, opts)
    opts = opts or {}
    local side = opts.side or "left"
    local isVert = (side == "top" or side == "bottom")
    local state = getToggleState(id, opts)

    -- Resolve expanded size
    local availW, availH = ImGui.GetContentRegionAvail()
    local totalAvail = isVert and availH or availW

    local expandedSize = parseSizeSpec(opts.size or 200, totalAvail) or 200

    -- Animation tick
    local now = os.clock()
    local dt = now - state.lastTime
    state.lastTime = now
    local target = state.isOpen and 1.0 or 0.0
    if state.animProgress < target then
        state.animProgress = math.min(target, state.animProgress + state.speed * dt)
    elseif state.animProgress > target then
        state.animProgress = math.max(target, state.animProgress - state.speed * dt)
    end
    local eased = state.animProgress * state.animProgress * (3 - 2 * state.animProgress)

    -- Compute panel size (spacing cancelled by SetCursorPos like regular splitters)
    local panelSize = math.floor(expandedSize * eased)
    local barW = state.barWidth
    local spacing = isVert and ImGui.GetStyle().ItemSpacing.y or ImGui.GetStyle().ItemSpacing.x
    local flexSize = math.max(totalAvail - panelSize - barW, 1)

    local fixedFirst = (side == "left" or side == "top")
    local fixedPanel = panels[1]
    local flexPanel = panels[2]

    local noScroll = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

    local function renderFixed()
        if panelSize > 0 then
            local cw = isVert and availW or panelSize
            local ch = isVert and panelSize or 0
            ImGui.BeginChild("##toggle_fixed_" .. id, cw, ch, false, noScroll)
            if fixedPanel.content then fixedPanel.content() end
            ImGui.EndChild()
        end
    end

    local function renderFlex()
        local cw = isVert and availW or flexSize
        local ch = isVert and flexSize or 0
        ImGui.BeginChild("##toggle_flex_" .. id, cw, ch, false)
        if flexPanel.content then flexPanel.content() end
        ImGui.EndChild()
    end

    -- Cancel ItemSpacing after each element (matches splitter.horizontal / .vertical)
    local function cancelSpacing()
        if isVert then
            ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacing)
        else
            ImGui.SameLine()
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacing)
        end
    end

    if fixedFirst then
        renderFixed()
        if panelSize > 0 then cancelSpacing() end
        drawToggleBar(id, state, side)
        cancelSpacing()
        renderFlex()
    else
        renderFlex()
        cancelSpacing()
        drawToggleBar(id, state, side)
        if panelSize > 0 then cancelSpacing() end
        renderFixed()
    end

    return state.isOpen
end

--- Programmatically set toggle state
---@param id string Toggle identifier
---@param open boolean Desired open state
function splitter.setToggle(id, open)
    local state = toggleStates[id]
    if state then state.isOpen = open end
end

--- Query toggle state
---@param id string Toggle identifier
---@return boolean|nil isOpen Current open state, or nil if not found
function splitter.getToggle(id)
    local state = toggleStates[id]
    return state and state.isOpen or nil
end

-- Aliases for brevity
splitter.h = splitter.horizontal
splitter.v = splitter.vertical
splitter.m = splitter.multi
splitter.t = splitter.toggle

return splitter
