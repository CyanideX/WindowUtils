------------------------------------------------------
-- WindowUtils - Splitter Core
-- Shared state, bar rendering, animation, color resolution
------------------------------------------------------

local styles = require("modules/styles")
local utils = require("modules/utils")
local coreModule = require("core/core")
local controls = require("modules/controls")
local expand = require("modules/expand")
local frameContext = require("core/frameContext")

local easeInOut = coreModule.easeInOut

local M = {}

local TRANSPARENT = { 0, 0, 0, 0 }
local COLLAPSE_SPEED = 6.0
local COLLAPSE_MIN = 0.01

M.TRANSPARENT = TRANSPARENT
M.COLLAPSE_SPEED = COLLAPSE_SPEED
M.COLLAPSE_MIN = COLLAPSE_MIN

-- Cached minimum sizes per splitter (computed per-frame, used for window constraints)
local splitterMinSizes = {}

local isCtrlHeld = utils.isCtrlHeld
local isShiftHeld = utils.isShiftHeld
local snapValue = function(val) return utils.snapToIncrement(val) end

-- Expose for split.lua / toggle.lua
M.isCtrlHeld = isCtrlHeld
M.isShiftHeld = isShiftHeld
M.snapValue = snapValue

--------------------------------------------------------------------------------
-- Size Specification Helpers
--------------------------------------------------------------------------------

local parseSizeSpec = utils.parseSizeSpec
M.parseSizeSpec = parseSizeSpec

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

    local remaining = available - fixedTotal
    if remaining < 0 then remaining = 0 end
    for _, i in ipairs(flexIndices) do
        local weight = sizes[i]
        sizes[i] = flexTotal > 0 and math.floor(remaining * weight / flexTotal) or 0
    end

    for i = 1, n do
        local p = panels[i]
        local minSz = parseSizeSpec(p[minKey], available)
        local maxSz = parseSizeSpec(p[maxKey], available)
        if minSz and sizes[i] < minSz then sizes[i] = minSz end
        if maxSz and sizes[i] > maxSz then sizes[i] = maxSz end
    end

    return sizes
end

M.computeInitialSizes = computeInitialSizes

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local splitStates = {}
local multiStates = {}
local toggleStates = {}

M.splitStates = splitStates
M.multiStates = multiStates
M.toggleStates = toggleStates
M.splitterMinSizes = splitterMinSizes

local function getState(id, opts)
    if not splitStates[id] then
        opts = opts or {}
        splitStates[id] = {
            pct = opts.defaultPct or 0.5,
            defaultPct = opts.defaultPct or 0.5,
            minPct = opts.minPct or 0.1,
            maxPct = opts.maxPct or 0.9,
            grabWidth = opts.grabWidth or controls.getFrameCache().itemSpacingX,
            hovering = false,
            dragging = false,
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

M.getState = getState

--------------------------------------------------------------------------------
-- Grab Icon Helpers
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

M.getGrabIcon = getGrabIcon
M.getGrabIconV = getGrabIconV

--------------------------------------------------------------------------------
-- Bar Rendering
--------------------------------------------------------------------------------

--- Shared bar rendering: styled child window with centered icon.
--- Returns the hover state of the child.
local BAR_FLAGS = ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
M.BAR_FLAGS = BAR_FLAGS

local function drawBar(childId, barWidth, icon, bgColor, iconColor, isVertical)
    ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)

    local childW = isVertical and 0 or barWidth
    local childH = isVertical and barWidth or 0

    if ImGui.BeginChild(childId, childW, childH, false, BAR_FLAGS) then
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

    local hovering = ImGui.IsItemHovered()

    ImGui.PopStyleVar()
    ImGui.PopStyleColor()

    return hovering
end

M.drawBar = drawBar

--------------------------------------------------------------------------------
-- Animation Helpers
--------------------------------------------------------------------------------

--- Tick a from->to easeInOut animation. Returns interpolated value.
local function tickAnimation(anim, speed)
    local now = frameContext.get().clock
    local dt = now - (anim.animLastTime or now)
    anim.animLastTime = now
    anim.animProgress = math.min(1.0, anim.animProgress + speed * dt)
    return anim.animFrom + (anim.animTo - anim.animFrom) * easeInOut(anim.animProgress)
end

M.tickAnimation = tickAnimation

--- Cancel ItemSpacing between adjacent elements.
local function cancelSpacing(isVertical, spacing)
    if isVertical then
        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacing)
    else
        ImGui.SameLine()
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacing)
    end
end

M.cancelSpacing = cancelSpacing

--- Tick a toggle open/close animation (same smoothstep as splitter.toggle).
--- Returns the eased interpolation value in [0, 1].
local function tickToggle(tglState)
    local target = tglState.isOpen and 1.0 or 0.0
    local now = frameContext.get().clock
    local dt = now - tglState.lastTime
    tglState.lastTime = now
    -- Skip work when fully settled
    if tglState.animProgress == target then
        return easeInOut(target)
    end
    if not tglState.animate then
        tglState.animProgress = target
    elseif tglState.animProgress < target then
        tglState.animProgress = math.min(target, tglState.animProgress + tglState.speed * dt)
    elseif tglState.animProgress > target then
        tglState.animProgress = math.max(target, tglState.animProgress - tglState.speed * dt)
    end
    return easeInOut(tglState.animProgress)
end

M.tickToggle = tickToggle

--------------------------------------------------------------------------------
-- Color Resolution
--------------------------------------------------------------------------------

--- Resolve bar colors from drag/hover state.
local function resolveBarColors(state, customBg)
    local bgColor, iconColor
    if state.dragging then
        bgColor = styles.colors.splitterDrag or styles.colors.green
    elseif state.hovering then
        bgColor = styles.colors.splitterHover or { 0.3, 0.5, 0.7, 0.5 }
    else
        bgColor = customBg or TRANSPARENT
    end
    if state.dragging or state.hovering then
        iconColor = styles.colors.splitterIconHi or styles.colors.textWhite
    else
        iconColor = styles.colors.splitterIcon or styles.colors.greyLight
    end
    return bgColor, iconColor
end

M.resolveBarColors = resolveBarColors

--------------------------------------------------------------------------------
-- Chevron Helpers
--------------------------------------------------------------------------------

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

M.getToggleIcon = getToggleIcon

--------------------------------------------------------------------------------
-- Grab Bar (used by both split and multi)
--------------------------------------------------------------------------------

local function drawGrabBar(id, state, isVertical)
    local grabW = state.grabWidth
    local icon = isVertical and getGrabIconV() or getGrabIcon()
    local bgColor, iconColor = resolveBarColors(state)

    state.hovering = drawBar("##splitter_grab_" .. id, grabW, icon, bgColor, iconColor, isVertical)

    if state.hovering and ImGui.IsMouseDragging(0, 0) then
        state.dragging = true
    end
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
            state.animLastTime = frameContext.get().clock
        else
            state.animFrom = state.pct
            state.animTo = state.restorePct or state.defaultPct
            state.animProgress = 0.0
            state.animLastTime = frameContext.get().clock
            state.collapsed = false
        end
    end

    -- Animation tick
    if state.animProgress and state.animProgress < 1.0 and state.pct then
        state.pct = tickAnimation(state, COLLAPSE_SPEED)
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

    if state.hovering or state.dragging then
        if isVertical then
            ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeNS)
        else
            ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
        end
    end
end

M.drawGrabBar = drawGrabBar

--------------------------------------------------------------------------------
-- Toggle State Constructor
--------------------------------------------------------------------------------

local function getToggleState(id, opts)
    if not toggleStates[id] then
        opts = opts or {}

        -- Determine initial open state: check persisted state first
        local initialOpen = opts.defaultOpen ~= false
        local persist = opts.persist
        local windowName = opts.windowName
        local restoredDragSize = nil
        if windowName and persist then
            local saved, savedDragSize = coreModule.loadPanelState(windowName, id)
            if saved ~= nil then
                initialOpen = saved
                restoredDragSize = savedDragSize
            end
        end

        toggleStates[id] = {
            isOpen = initialOpen,
            animProgress = initialOpen and 1.0 or 0.0,
            lastTime = frameContext.get().clock,
            speed = opts.speed or COLLAPSE_SPEED,
            animate = opts.animate ~= false,
            barWidth = opts.barWidth or controls.getFrameCache().itemSpacingX,
            barBg = opts.barBg,
            hovering = false,
            dragging = false,           -- expand mode: drag-in-progress
            expandDragStart = nil,      -- expand mode: panel size at drag start
            expandId = nil,             -- set by splitter.toggle() when opts.expand is truthy
            toggleOnClick = opts.toggleOnClick or false,
            pressedForToggle = false,   -- toggleOnClick: tracks press-to-release cycle
            pressedOnBar = false,       -- expand: tracks press on bar for drag initiation
            persist = persist,          -- persistence mode: "auto", "manual", true, or false/nil
            windowName = windowName,    -- window name for persistence
            restoredDragSize = restoredDragSize, -- flex drag size from previous session
        }
    end
    return toggleStates[id]
end

M.getToggleState = getToggleState

--------------------------------------------------------------------------------
-- Toggle Bar Rendering
--------------------------------------------------------------------------------

local function drawToggleBar(id, state, side)
    local isVert = (side == "top" or side == "bottom")
    local barW = state.barWidth

    -- Icon selection
    local icon
    if state.expandId and not state.toggleOnClick then
        -- Expand without toggleOnClick: always show drag handle
        icon = isVert and getGrabIconV() or getGrabIcon()
    elseif state.expandId and state.dragging then
        -- Expand with toggleOnClick, actively dragging: show drag handle
        icon = isVert and getGrabIconV() or getGrabIcon()
    else
        -- Normal toggle or expand with toggleOnClick (idle): show toggle arrow
        local arrowOpen = state.isOpen
        if state.expandId then arrowOpen = not arrowOpen end
        icon = getToggleIcon(side, arrowOpen)
    end

    local bgColor, iconColor = resolveBarColors(state, state.barBg)
    state.hovering = drawBar("##toggle_bar_" .. id, barW, icon, bgColor, iconColor, isVert)

    if state.expandId then
        -- === Expand mode ===

        -- Drag: only when open and fully expanded
        local canDrag = state.isOpen and state.animProgress >= 1.0

        -- Track press on bar for drag initiation
        if state.hovering and ImGui.IsItemClicked(0) and canDrag then
            state.pressedOnBar = true
        end
        if not ImGui.IsMouseDown(0) then
            state.pressedOnBar = false
        end

        if not state.dragging and state.pressedOnBar
                and ImGui.IsMouseDragging(0, 2) then
            state.dragging = true
            state.pressedOnBar = false
        end
        if state.dragging and not ImGui.IsMouseDown(0) then
            state.dragging = false
            state.expandDragStart = nil
            expand.commitDrag(state.expandId)
            -- Persist the new drag size after user finishes resizing
            if state.persist and state.windowName then
                local ds = expand.getTargetSize(state.expandId)
                coreModule.savePanelState(state.windowName, id, state.isOpen, state.persist, ds)
            end
        end

        if state.dragging then
            state.expandDragStart = true
            local dirMul = (side == "right" or side == "bottom") and 1 or -1
            local delta = isVert
                and select(2, ImGui.GetMouseDragDelta(0, 0))
                or (ImGui.GetMouseDragDelta(0, 0))
            expand.applyDrag(state.expandId, delta, dirMul)
        end

        -- Toggle
        local toggled = false
        if state.toggleOnClick then
            if state.hovering and ImGui.IsItemClicked(0) and not state.dragging then
                state.pressedForToggle = true
            end
            if state.pressedForToggle and (state.dragging or state.pressedOnBar == false) then
                -- Cancel toggle if drag started
                if state.dragging then
                    state.pressedForToggle = false
                end
            end
            if state.pressedForToggle and not ImGui.IsMouseDown(0) then
                state.pressedForToggle = false
                if not state.dragging then
                    toggled = true
                end
            end
        else
            if state.hovering and ImGui.IsMouseDoubleClicked(0) then
                toggled = true
            end
        end

        if toggled then
            state.dragging = false
            state.expandDragStart = nil
            expand.commitDrag(state.expandId)
            state.isOpen = not state.isOpen
            if not state.animate then
                state.animProgress = state.isOpen and 1.0 or 0.0
            end
            expand.onToggle(state.expandId, state.isOpen)
            if state.persist and state.windowName then
                local ds = expand.getTargetSize(state.expandId)
                coreModule.savePanelState(state.windowName, id, state.isOpen, state.persist, ds)
            end
        end

        -- Cursor
        if state.hovering or state.dragging then
            if state.dragging then
                ImGui.SetMouseCursor(isVert and ImGuiMouseCursor.ResizeNS or ImGuiMouseCursor.ResizeEW)
            elseif canDrag then
                ImGui.SetMouseCursor(isVert and ImGuiMouseCursor.ResizeNS or ImGuiMouseCursor.ResizeEW)
            else
                ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
            end
        end
    else
        -- === Normal toggle mode: single-click ===
        if state.hovering and ImGui.IsItemClicked(0) then
            state.isOpen = not state.isOpen
            if not state.animate then
                state.animProgress = state.isOpen and 1.0 or 0.0
            end
            if state.persist and state.windowName then
                coreModule.savePanelState(state.windowName, id, state.isOpen, state.persist, nil)
            end
        end

        if state.hovering then
            ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
        end
    end
end

M.drawToggleBar = drawToggleBar

--------------------------------------------------------------------------------
-- Multi-panel State Constructor
--------------------------------------------------------------------------------

local function getMultiState(id, n, opts, panels)
    if multiStates[id] and #multiStates[id].dividers ~= n - 1 then
        multiStates[id] = nil
    end
    if not multiStates[id] then
        opts = opts or {}
        local grabWidth = opts.grabWidth or controls.getFrameCache().itemSpacingX
        local defaultPcts = opts.defaultPcts
        local minGap = opts.minPct or 0.05
        local isVertical = (opts.direction or "horizontal") == "vertical"

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

        local dividers = {}
        for i = 1, n - 1 do
            dividers[i] = {
                grabWidth = grabWidth,
                hovering = false,
                dragging = false,
                animFrom = nil,  -- animation fields used by context menu reset
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
            isVertical = isVertical,
            effectiveBps = {},  -- reused per-frame for clamping
            minFracs = {},      -- reused per-frame for min fraction cache
            dirty = true,       -- skip enforcement pass when nothing changed
            lastTotalAvail = nil -- track available space for resize detection
        }
    end
    return multiStates[id]
end

M.getMultiState = getMultiState

--------------------------------------------------------------------------------
-- Panel Min/Max Fraction Helpers
--------------------------------------------------------------------------------

--- Get minimum fraction for a panel based on its constraints.
--- When no explicit min is set, auto-floors to icon button width + window padding.
--- Set autoMin = false on a panel definition to opt out.
local function getPanelMinFrac(panelDefs, panelIdx, totalSize, minGap, isVertical)
    if not panelDefs or not panelDefs[panelIdx] then return minGap end
    local panel = panelDefs[panelIdx]
    local key = isVertical and "minHeight" or "minWidth"
    local spec = panel[key]
    if type(spec) == "function" then spec = spec() end
    local px = parseSizeSpec(spec, totalSize)

    -- Auto-detect minimum when no explicit min is set (uses per-frame cache)
    if not px and panel.autoMin ~= false then
        local fc = controls.getFrameCache()
        local autoMinPx = fc.minIconButtonWidth
        autoMinPx = autoMinPx + (isVertical and fc.windowPaddingY or fc.windowPaddingX) * 2
        px = autoMinPx
    end

    return px and math.max(px / totalSize, COLLAPSE_MIN) or minGap
end

M.getPanelMinFrac = getPanelMinFrac

--- Get maximum fraction for a panel based on its constraints
local function getPanelMaxFrac(panelDefs, panelIdx, totalSize, isVertical)
    if not panelDefs or not panelDefs[panelIdx] then return 1.0 end
    local key = isVertical and "maxHeight" or "maxWidth"
    local spec = panelDefs[panelIdx][key]
    local px = parseSizeSpec(spec, totalSize)
    return px and (px / totalSize) or 1.0
end

M.getPanelMaxFrac = getPanelMaxFrac

--------------------------------------------------------------------------------
-- Min Size Query
--------------------------------------------------------------------------------

--- Get the cached minimum size (in pixels) for a splitter's primary direction.
---@param id string Splitter identifier
---@return number|nil minSize Minimum pixels, or nil if splitter hasn't rendered yet
function M.getMinSize(id)
    return splitterMinSizes[id]
end

--------------------------------------------------------------------------------
-- Destroy
--------------------------------------------------------------------------------

--- Remove all internal state associated with a splitter ID.
---@param id string Splitter identifier
function M.destroy(id)
    splitStates[id] = nil
    splitterMinSizes[id] = nil

    -- Multi-panel derived state
    if multiStates[id] then
        multiStates[id] = nil
    end

    -- Toggle states (direct and derived from multi edge panels)
    toggleStates[id] = nil
    toggleStates[id .. "_tgl_lead"] = nil
    toggleStates[id .. "_tgl_trail"] = nil
end

return M
