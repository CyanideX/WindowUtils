------------------------------------------------------
-- WindowUtils - Splitter
-- Draggable panel dividers and toggle layouts
------------------------------------------------------
-- Thank you to KeanuWheeze for the guidance
------------------------------------------------------

local styles = require("modules/styles")
local utils = require("modules/utils")
local core = require("core/core")
local controls = require("modules/controls")
local expand = require("modules/expand")

local easeInOut = core.easeInOut

local splitter = {}

local TRANSPARENT = { 0, 0, 0, 0 }
local COLLAPSE_SPEED = 6.0
local COLLAPSE_MIN = 0.01

-- Cached minimum sizes per splitter (computed per-frame, used for window constraints)
local splitterMinSizes = {}

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

--- Shared bar rendering: styled child window with centered icon.
--- Returns the hover state of the child.
local BAR_FLAGS = ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

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

--- Tick a from→to easeInOut animation. Returns interpolated value.
local function tickAnimation(anim, speed)
    local now = os.clock()
    local dt = now - (anim.animLastTime or now)
    anim.animLastTime = now
    anim.animProgress = math.min(1.0, anim.animProgress + speed * dt)
    return anim.animFrom + (anim.animTo - anim.animFrom) * easeInOut(anim.animProgress)
end

--- Cancel ItemSpacing between adjacent elements.
local function cancelSpacing(isVertical, spacing)
    if isVertical then
        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacing)
    else
        ImGui.SameLine()
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacing)
    end
end

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
    local spacingX = controls.getFrameCache().itemSpacingX

    local availW = ImGui.GetContentRegionAvail()
    local usableW = availW - grabW
    local leftW = math.floor(usableW * state.pct)
    local rightW = usableW - leftW

    styles.PushScrollbar()

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

    styles.PopScrollbar()

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
    local spacingY = controls.getFrameCache().itemSpacingY

    local availW, availH = ImGui.GetContentRegionAvail()
    local usableH = availH - grabH
    local topH = math.floor(usableH * state.pct)
    local bottomH = usableH - topH

    styles.PushScrollbar()

    ImGui.BeginChild("##splitter_top_" .. id, availW, topH, false)
    if topFn then topFn() end
    ImGui.EndChild()

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

    drawGrabBar(id, state, true)

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

    ImGui.BeginChild("##splitter_bottom_" .. id, availW, bottomH, false)
    if bottomFn then bottomFn() end
    ImGui.EndChild()

    styles.PopScrollbar()

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

        -- Determine initial open state: check persisted state first
        local initialOpen = opts.defaultOpen ~= false
        local persist = opts.persist
        local windowName = opts.windowName
        local restoredDragSize = nil
        if windowName and persist then
            local saved, savedDragSize = core.loadPanelState(windowName, id)
            if saved ~= nil then
                initialOpen = saved
                restoredDragSize = savedDragSize
            end
        end

        toggleStates[id] = {
            isOpen = initialOpen,
            animProgress = initialOpen and 1.0 or 0.0,
            lastTime = os.clock(),
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
                core.savePanelState(state.windowName, id, state.isOpen, state.persist, ds)
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
                core.savePanelState(state.windowName, id, state.isOpen, state.persist, ds)
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
                core.savePanelState(state.windowName, id, state.isOpen, state.persist, nil)
            end
        end

        if state.hovering then
            ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
        end
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
            ms.dirty = true
        end
        if ImGui.MenuItem("Reset All") then
            for _, state in pairs(multiStates) do
                for j = 1, #state.defaults do
                    state.breakpoints[j] = state.defaults[j]
                end
                state.dirty = true
            end
        end
        ImGui.EndPopup()
    end
end

--------------------------------------------------------------------------------
-- Toggle Panel Rendering Helper
-- Shared by splitter.multi() for lead and trail edge toggle panels.
--------------------------------------------------------------------------------

--- Tick a toggle open/close animation (same smoothstep as splitter.toggle).
--- Returns the eased interpolation value in [0, 1].
local function tickToggle(tglState)
    local target = tglState.isOpen and 1.0 or 0.0
    local now = os.clock()
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

--- Render a toggle panel (lead or trail) with animation, size clamping, and child window.
--- For "lead" side: renders content first, then the toggle bar.
--- For "trail" side: renders the toggle bar first, then content.
---@param id string Base splitter identifier
---@param suffix string Toggle suffix ("lead" or "trail")
---@param panel table Panel definition with toggle, size, content fields
---@param side string Toggle bar side ("left", "right", "top", "bottom")
---@param isVertical boolean Whether the layout is vertical
---@param totalAvail number Total available space in the split direction
---@param availW number Available width from content region
---@param spacing number Item spacing to cancel between elements
---@param noScroll number ImGui child window flags for no-scroll
---@return table state Toggle state table
---@return number panelSize Computed panel size in pixels
---@return number barWidth Toggle bar width in pixels
local function renderTogglePanel(id, suffix, panel, side, isVertical, totalAvail, availW, spacing, noScroll)
    local tglId = id .. "_tgl_" .. suffix
    local state = getToggleState(tglId, panel)
    local eased = tickToggle(state)
    local expandedSize = parseSizeSpec(panel.size, totalAvail) or 0
    local panelSize = math.floor(expandedSize * eased)
    local barW = state.barWidth

    -- Skip sub-barW sizes to avoid CET min-height mismatch
    if panelSize > 0 and panelSize <= barW then
        if state.isOpen then
            panelSize = barW + 1
        else
            panelSize = 0
            state.animProgress = 0
        end
    end

    local isLead = (suffix == "lead")

    -- Render the child window content
    local function renderContent()
        if panelSize <= 0 then return end
        local cw = isVertical and availW or panelSize
        local ch = isVertical and panelSize or 0
        ImGui.BeginChild("##splitter_multi_" .. tglId, cw, ch, false, noScroll)
        if panelSize > barW and panel.content then
            local animating = state.animProgress > 0 and state.animProgress < 1
            if animating then ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 0) end
            panel.content()
            if animating then ImGui.PopStyleVar() end
        end
        ImGui.EndChild()
    end

    if isLead then
        -- Lead: content first, then bar
        renderContent()
        if panelSize > 0 then cancelSpacing(isVertical, spacing) end
        drawToggleBar(tglId, state, side)
        cancelSpacing(isVertical, spacing)
    else
        -- Trail: bar first, then content
        cancelSpacing(isVertical, spacing)
        drawToggleBar(tglId, state, side)
        if panelSize > 0 then cancelSpacing(isVertical, spacing) end
        renderContent()
    end

    return state, panelSize, barW
end

--------------------------------------------------------------------------------
-- Divider Drag Update
--------------------------------------------------------------------------------

--- Apply drag deltas to breakpoints after all panels have rendered.
--- Must run post-render to prevent one-frame desync / rubber banding.
---@param ms table Multi-state table (breakpoints, dividers, minGap, panelDefs, dirty)
---@param coreN number Number of core (non-toggle) panels
---@param totalSize number Usable pixel size for core panels (excluding grab bars)
---@param coreAvail number Total core available space (including grab bars)
---@param grabW number Grab bar width in pixels
---@param isVertical boolean Whether the layout is vertical
---@param minFracs table Pre-computed minimum fractions per panel
local function applyDividerDrags(ms, coreN, totalSize, coreAvail, grabW, isVertical, minFracs)
    local minGap = ms.minGap

    -- Animation tick for multi dividers (used by context menu "Reset")
    for i = 1, coreN - 1 do
        local div = ms.dividers[i]
        if div.animProgress and div.animProgress < 1.0 then
            ms.breakpoints[i] = tickAnimation(div, COLLAPSE_SPEED)
            div.dragging = false
            ms.dirty = true
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

                    local leftMin = minFracs[i]
                    local rightMin = minFracs[i + 1]
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
                ms.dirty = true
            end
        else
            ms.dividers[i].dragOrigin = nil
        end
    end
end

--- Multi-panel layout with independent flat breakpoints.
--- Each divider moves independently - dragging divider i only affects panels i and i+1.
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

    local noScroll = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

    local availW, availH = ImGui.GetContentRegionAvail()
    local totalAvail = isVertical and availH or availW
    local fc = controls.getFrameCache()
    local spacing = isVertical and fc.itemSpacingY or fc.itemSpacingX

    local leadState, leadSize, leadBarW = nil, 0, 0
    if leadToggle then
        leadState = getToggleState(id .. "_tgl_lead", leadToggle)
        local eased = tickToggle(leadState)
        local expandedSize = parseSizeSpec(leadToggle.size, totalAvail) or 0
        leadSize = math.floor(expandedSize * eased)
        leadBarW = leadState.barWidth
        -- Skip sub-barW sizes to avoid CET min-height mismatch
        if leadSize > 0 and leadSize <= leadBarW then
            if leadState.isOpen then
                leadSize = leadBarW + 1
            else
                leadSize = 0
                leadState.animProgress = 0
            end
        end
    end

    local trailState, trailSize, trailBarW = nil, 0, 0
    if trailToggle then
        trailState = getToggleState(id .. "_tgl_trail", trailToggle)
        local eased = tickToggle(trailState)
        local expandedSize = parseSizeSpec(trailToggle.size, totalAvail) or 0
        trailSize = math.floor(expandedSize * eased)
        trailBarW = trailState.barWidth
        if trailSize > 0 and trailSize <= trailBarW then
            if trailState.isOpen then
                trailSize = trailBarW + 1
            else
                trailSize = 0
                trailState.animProgress = 0
            end
        end
    end

    local toggleSpace = leadSize + leadBarW + trailSize + trailBarW
    local grabTotal = coreN > 1 and (coreN - 1) * grabW or 0
    local minCoreSpace = grabTotal + coreN  -- at least 1px per core panel
    local coreAvail = totalAvail - toggleSpace

    -- If toggles consume too much, compress them proportionally
    if coreAvail < minCoreSpace and (leadSize + trailSize) > 0 then
        local excess = minCoreSpace - coreAvail
        local toggleTotal = leadSize + trailSize
        if excess >= toggleTotal then
            leadSize = 0
            trailSize = 0
        else
            local ratio = excess / toggleTotal
            leadSize = math.max(0, math.floor(leadSize - leadSize * ratio))
            trailSize = math.max(0, math.floor(trailSize - trailSize * ratio))
        end
        toggleSpace = leadSize + leadBarW + trailSize + trailBarW
        coreAvail = totalAvail - toggleSpace
    end

    local coreUsable = coreAvail - grabTotal
    if coreUsable < 1 then return end  -- only fires if totalAvail is truly tiny
    local totalSize = coreUsable

    local minFracs = ms.minFracs
    for i = 1, coreN do
        minFracs[i] = getPanelMinFrac(corePanels, i, totalSize, minGap, isVertical)
    end

    if not ms.dirty then
        for i = 1, coreN - 1 do
            local div = ms.dividers[i]
            if div.dragging or (div.animProgress and div.animProgress < 1.0) then
                ms.dirty = true
                break
            end
        end
    end
    if not ms.dirty then
        if leadState and leadState.animProgress > 0 and leadState.animProgress < 1 then
            ms.dirty = true
        end
        if trailState and trailState.animProgress > 0 and trailState.animProgress < 1 then
            ms.dirty = true
        end
    end
    -- Available space changed (window resize)
    if not ms.dirty and ms.lastTotalAvail ~= totalAvail then
        ms.dirty = true
    end
    ms.lastTotalAvail = totalAvail

    local effectiveBps = ms.effectiveBps
    if ms.dirty then
        -- Per-frame enforcement of panel minimums (protects during window resize, not just drag)
        for i = 1, coreN - 1 do
            effectiveBps[i] = ms.breakpoints[i]
        end
        -- Forward pass: protect panels from left
        for i = 1, coreN - 1 do
            local prev = (i > 1) and effectiveBps[i - 1] or 0
            effectiveBps[i] = math.max(effectiveBps[i], prev + minFracs[i])
        end
        -- Backward pass: protect panels from right
        for i = coreN - 1, 1, -1 do
            local nxt = (i < coreN - 1) and effectiveBps[i + 1] or 1
            effectiveBps[i] = math.min(effectiveBps[i], nxt - minFracs[i + 1])
        end
        ms.dirty = false
    end

    local sizes = {}
    local consumed = 0
    for i = 1, coreN do
        local startFrac = (i == 1) and 0 or effectiveBps[i - 1]
        local endFrac = (i == coreN) and 1 or effectiveBps[i]
        if i == coreN then
            sizes[i] = coreUsable - consumed
        else
            sizes[i] = math.floor(coreUsable * (endFrac - startFrac))
            consumed = consumed + sizes[i]
        end
    end

    local totalMinPx = 0
    for i = 1, coreN do
        totalMinPx = totalMinPx + math.max(math.ceil(minFracs[i] * totalSize), 1)
    end
    splitterMinSizes[id] = totalMinPx + grabTotal + toggleSpace

    local leadSide = isVertical and "top" or "left"
    local trailSide = isVertical and "bottom" or "right"

    styles.PushScrollbar()

    -- 1. Lead toggle panel + toggle bar
    if leadToggle then
        renderTogglePanel(id, "lead", leadToggle, leadSide, isVertical, totalAvail, availW, spacing, noScroll)
    end

    -- 2. Core panels with dividers
    for i = 1, coreN do
        local cw = isVertical and availW or sizes[i]
        local ch = isVertical and sizes[i] or 0
        ImGui.BeginChild("##splitter_multi_" .. id .. "_p" .. i, cw, ch, false, noScroll)
        if corePanels[i].content then corePanels[i].content() end
        ImGui.EndChild()

        if i < coreN then
            cancelSpacing(isVertical, spacing)
            drawGrabBar(id .. "_d" .. i, ms.dividers[i], isVertical)
            drawContextMenu(id, i, ms, isVertical)
            cancelSpacing(isVertical, spacing)
        end
    end

    -- 3. Trail toggle bar + toggle panel
    if trailToggle then
        renderTogglePanel(id, "trail", trailToggle, trailSide, isVertical, totalAvail, availW, spacing, noScroll)
    end

    styles.PopScrollbar()

    -- 4. Post-render drag updates
    applyDividerDrags(ms, coreN, totalSize, coreAvail, grabW, isVertical, minFracs)
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
        ms.dirty = true
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
    state.toggleOnClick = opts.toggleOnClick or false

    local availW, availH = ImGui.GetContentRegionAvail()
    local totalAvail = isVert and availH or availW

    local defaultSize = parseSizeSpec(opts.size or 200, totalAvail) or 200

    local expandedSize = defaultSize
    if opts.expand then
        state.expandId = id
        expand.init(id, {
            windowName = opts.windowName,
            side = side,
            size = defaultSize,
            sizeMode = opts.sizeMode,
            normalConstraintPct = opts.normalConstraintPct,
            expandDuration = opts.expandDuration,
            expandEasing = opts.expandEasing,
            isOpen = state.isOpen,
            restoredDragSize = state.restoredDragSize,
        })
        local prevMode = state.sizeMode
        state.sizeMode = opts.sizeMode or "fixed"
        if state.sizeMode ~= prevMode and prevMode ~= nil then
            state.dragging = false
            state.expandDragStart = nil
            expand.commitDrag(id)
        end
        expandedSize = expand.getTargetSize(id) or defaultSize
    end

    local now = os.clock()
    local dt = now - state.lastTime
    state.lastTime = now
    local target = state.isOpen and 1.0 or 0.0
    if not state.animate then
        state.animProgress = target
    elseif state.animProgress < target then
        state.animProgress = math.min(target, state.animProgress + state.speed * dt)
    elseif state.animProgress > target then
        state.animProgress = math.max(target, state.animProgress - state.speed * dt)
    end
    local eased = easeInOut(state.animProgress)

    local panelSize = math.floor(expandedSize * eased)
    local barW = state.barWidth
    if panelSize > 0 and panelSize <= barW then
        if state.isOpen then
            panelSize = barW + 1
        else
            panelSize = 0
            state.animProgress = 0
        end
    end

    local fc = controls.getFrameCache()
    local spacing = isVert and fc.itemSpacingY or fc.itemSpacingX

    -- edgeFlush: when collapsed, bar sits flush against window edge (right/bottom only).
    -- When open, normal padding applies. Flex extends into freed padding when collapsed.
    local fixedFirst = (side == "left" or side == "top")
    local flushOffset = 0
    if opts.edgeFlush and not fixedFirst then
        flushOffset = isVert and fc.windowPaddingY or fc.windowPaddingX
    end

    local flexSize
    if opts.expand then
        expand.cacheBase(id, totalAvail, panelSize)
        if panelSize > 0 and not state.dragging then
            local baseAvail = expand.getBaseAvail(id)
            flexSize = math.max((baseAvail or totalAvail) - barW, 1)
        else
            flexSize = math.max(totalAvail - panelSize - barW, 1)
        end
    else
        flexSize = math.max(totalAvail - panelSize - barW, 1)
    end

    if flushOffset > 0 and panelSize == 0 then
        flexSize = flexSize + flushOffset
    end

    local fixedPanel = panels[1]
    local flexPanel = panels[2]

    local flexMinSpec = flexPanel and (isVert and flexPanel.minHeight or flexPanel.minWidth)
    if type(flexMinSpec) == "function" then flexMinSpec = flexMinSpec() end
    local flexMinPx = parseSizeSpec(flexMinSpec, totalAvail)
    if not flexMinPx then
        flexMinPx = fc.minIconButtonWidth
                  + (isVert and fc.windowPaddingY or fc.windowPaddingX) * 2
    end
    splitterMinSizes[id] = panelSize + barW + flexMinPx

    local noScroll = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

    local function renderFixed()
        if panelSize > 0 then
            local cw = isVert and availW or panelSize
            local ch = isVert and panelSize or 0
            ImGui.BeginChild("##toggle_fixed_" .. id, cw, ch, false, noScroll)
            if panelSize > state.barWidth and fixedPanel.content then
                local animating = state.animProgress > 0 and state.animProgress < 1
                if animating then ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 0) end
                fixedPanel.content()
                if animating then ImGui.PopStyleVar() end
            end
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

    styles.PushScrollbar()

    if fixedFirst then
        renderFixed()
        if panelSize > 0 then cancelSpacing(isVert, spacing) end
        drawToggleBar(id, state, side)
        cancelSpacing(isVert, spacing)
        renderFlex()
    else
        renderFlex()
        cancelSpacing(isVert, spacing)
        drawToggleBar(id, state, side)
        if panelSize > 0 then cancelSpacing(isVert, spacing) end
        renderFixed()
    end

    styles.PopScrollbar()

    -- Recompute panelSize for no-animation mode in case a toggle happened mid-frame (stale value)
    if opts.expand then
        local reportedSize = panelSize
        if not state.animate then
            state.animProgress = state.isOpen and 1.0 or 0.0
            local e = easeInOut(state.animProgress)
            reportedSize = math.floor(expandedSize * e)
        end
        local isAnimating = state.animProgress > 0 and state.animProgress < 1
        expand.afterRender(id, reportedSize, isAnimating, state.dragging)
    end

    return state.isOpen
end

--- Programmatically set toggle state
---@param id string Toggle identifier
---@param open boolean Desired open state
function splitter.setToggle(id, open)
    local state = toggleStates[id]
    if state then
        state.isOpen = open
        if not state.animate then
            state.animProgress = open and 1.0 or 0.0
        end
        if state.expandId then
            expand.onToggle(state.expandId, open)
        end
        if state.persist and state.windowName then
            local ds = state.expandId and expand.getTargetSize(state.expandId) or nil
            core.savePanelState(state.windowName, id, open, state.persist, ds)
        end
    end
end

--- Query toggle state
---@param id string Toggle identifier
---@return boolean|nil isOpen Current open state, or nil if not found
function splitter.getToggle(id)
    local state = toggleStates[id]
    return state and state.isOpen or nil
end

--- Query a panel's last saved open state from the window cache.
--- Works with any persist mode ("auto" or "manual"). Returns the state
--- that was saved when the game last closed, regardless of current state.
---@param windowName string The window name
---@param panelId string The panel identifier
---@return boolean|nil wasOpen The saved open state, or nil if not found
function splitter.getSavedToggle(windowName, panelId)
    return core.getSavedPanelState(windowName, panelId)
end

--- Set toggle animation enabled/disabled
---@param id string Toggle identifier
---@param enabled boolean Whether animation is enabled
function splitter.setToggleAnimate(id, enabled)
    local state = toggleStates[id]
    if state then state.animate = enabled end
end

--- Query toggle animation state
---@param id string Toggle identifier
---@return boolean|nil animate Whether animation is enabled, or nil if not found
function splitter.getToggleAnimate(id)
    local state = toggleStates[id]
    return state and state.animate or nil
end

--- Get the cached minimum size (in pixels) for a splitter's primary direction.
--- Returns the minimum content-region size needed so all panels fit at their minimums.
--- Use this value (+ window padding) for SetNextWindowSizeConstraints.
---@param id string Splitter identifier
---@return number|nil minSize Minimum pixels, or nil if splitter hasn't rendered yet
function splitter.getMinSize(id)
    return splitterMinSizes[id]
end

--- Get the current animated constraint value for an expand-mode toggle.
--- Call before ImGui.Begin() to feed into SetNextWindowSizeConstraintsPercent.
--- Returns nil if the toggle hasn't rendered yet or isn't in expand mode.
---@param id string Toggle identifier (same id passed to splitter.toggle with expand=true)
---@return number|nil constraintPct Current animated constraint value (display %), or nil
function splitter.getExpandConstraint(id)
    local state = toggleStates[id]
    if not state or not state.expandId then return nil end
    return expand.getConstraint(state.expandId, state.isOpen)
end

-- Aliases for brevity
splitter.h = splitter.horizontal
splitter.v = splitter.vertical
splitter.m = splitter.multi
splitter.t = splitter.toggle

return splitter
