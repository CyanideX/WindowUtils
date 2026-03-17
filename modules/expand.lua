--------------------------------------------------------------------------------
-- expand.lua — Window Expansion Manager
--
-- Manages window resizing for expand-mode toggle panels. Owns all SetWindowSize/
-- SetWindowPos logic, base-size caching, and constraint animation integration.
-- Keeps splitter.lua free of window-sizing concerns.
--
-- Two-phase design:
--   1. Content-level calls (init, cacheBase, afterRender) work inside any child
--      window — they only store state, never call SetWindowSize/SetWindowPos.
--   2. Window-level call (applyWindowSize) must be called at the main window
--      scope (after EndChild, inside Begin/End) where GetWindowSize() returns
--      the actual window dimensions, not a child's.
--------------------------------------------------------------------------------

local core = require("modules/core")

local expand = {}
local LOG_FLEX = true   -- set false to silence flex debug logging

--- Per-panel expansion state
local expandStates = {}

--- Per-window base dimensions (shared by all panels on a window).
--- Represents the "naked" window size with no expand panels open.
local windowBases = {}

local function getWindowBase(windowName)
    if not windowBases[windowName] then
        windowBases[windowName] = { w = nil, h = nil }
    end
    return windowBases[windowName]
end

--------------------------------------------------------------------------------
-- Public API — Content level (safe inside children)
--------------------------------------------------------------------------------

--- Register/update expand panel config (idempotent, safe to call every frame).
--- Only creates state on first call; subsequent calls update panelSizePx and display dim.
---@param id string Panel identifier (same id used with splitter.toggle)
---@param opts table { windowName, side, size, normalConstraintPct, expandDuration, expandEasing }
function expand.init(id, opts)
    local isVert = (opts.side == "top" or opts.side == "bottom")
    local dw, dh = GetDisplayResolution()

    if not expandStates[id] then
        expandStates[id] = {
            windowName       = opts.windowName,
            side             = opts.side or "right",
            isVert           = isVert,
            panelSizePx      = opts.size or 200,
            baseAvail        = nil,
            pendingCapture   = false,
            settled          = true,
            anchorEdge       = nil,
            -- Per-frame state (set by afterRender, consumed by applyWindowSize)
            currentPanelSize = 0,
            currentAnimating = false,
            currentDragging  = false,
            -- Drag support
            dragSize         = nil,     -- flex mode: panel size set by drag (overrides panelSizePx)
            dragOffset       = nil,     -- fixed mode: additive offset to baseW/baseH during drag
            panelDragStart   = nil,     -- flex mode: panel size at drag start
            sizeMode         = opts.sizeMode or "fixed",
            flexRatio        = nil,     -- panel / totalWindow ratio (flex mode)
            measuredSize     = nil,     -- auto mode: content extent measured after rendering
            -- Flex settling support
            flexClosePending = false,   -- true after flex close toggle, cleared on close settling
            flexDragSettled  = false,   -- 1-frame flag: skip Phase 6 ratio maintenance on settling
            flexWasDragging  = false,   -- true when unsettled state is from drag (vs animation)
            -- Constraint animation fields
            constraintProp   = id .. (isVert and "_maxH" or "_maxW"),
            normalPct        = opts.normalConstraintPct,
            expandDuration   = opts.expandDuration or 0.3,
            expandEasing     = opts.expandEasing or "easeOut",
            cachedDisplayDim = isVert and dh or dw,
        }
    else
        -- Update per-frame values that may change (e.g. resolved size, display dim)
        local s = expandStates[id]
        s.panelSizePx = opts.size or s.panelSizePx
        s.cachedDisplayDim = isVert and dh or dw
        -- Reset stale state on mode switch
        if opts.sizeMode and opts.sizeMode ~= s.sizeMode then
            s.sizeMode = opts.sizeMode
            s.dragSize = nil
            s.dragOffset = nil
            s.flexRatio = nil
            s.baseAvail = nil
            s.settled = false
            s.flexClosePending = false
            s.flexDragSettled = false
            s.flexWasDragging = false
        elseif opts.sizeMode then
            s.sizeMode = opts.sizeMode
        end
    end
end

--- Signal a toggle event. Called by splitter click handler or programmatically.
--- Triggers constraint animation via core.startConstraintAnimation().
---@param id string Panel identifier
---@param isOpen boolean New open state (AFTER the toggle)
function expand.onToggle(id, isOpen)
    local s = expandStates[id]
    if not s then return end

    -- Capture base window size on the next applyWindowSize() call (click-to-open frame)
    if isOpen then
        s.pendingCapture = true
        s.flexClosePending = false    -- cancel any pending close restore on reopen
    elseif s.sizeMode == "flex" then
        s.flexClosePending = true     -- arm close restore for Phase 4 settling
    end

    if LOG_FLEX and s.sizeMode == "flex" then
        print(("[FLEX] onToggle id=%s isOpen=%s dragSize=%s panelSizePx=%s flexClosePending=%s")
            :format(id, tostring(isOpen), tostring(s.dragSize), tostring(s.panelSizePx),
                    tostring(s.flexClosePending)))
    end

    -- Trigger constraint animation if normalPct is configured
    if s.normalPct then
        local dim = s.cachedDisplayDim
        local effectiveSize = s.dragSize or s.panelSizePx
        if dim and dim > 0 and effectiveSize then
            local deltaPct = (effectiveSize / dim) * 100
            local targetPct = isOpen
                and (s.normalPct + deltaPct)
                or s.normalPct
            core.startConstraintAnimation(s.windowName, s.constraintProp, targetPct, {
                duration = s.expandDuration,
                easing = s.expandEasing,
            })
        end
    end
end

--- Cache the content-region available space.
--- Updates baseAvail when panel is fully closed (panelSize <= 0) or on first frame.
--- Safe inside children — baseAvail feeds flex sizing only, not SetWindowSize.
---@param id string Panel identifier
---@param totalAvail number Current content region available (from GetContentRegionAvail)
---@param panelSize number Current animated panel size (0 when closed)
function expand.cacheBase(id, totalAvail, panelSize)
    local s = expandStates[id]
    if not s then return end

    if s.baseAvail == nil or panelSize <= 0 then
        s.baseAvail = totalAvail
    end
end

--- Get the cached base content-region available space (stable flex sizing).
---@param id string Panel identifier
---@return number|nil baseAvail Cached value, or nil if not yet captured
function expand.getBaseAvail(id)
    local s = expandStates[id]
    if not s then return nil end
    return s.baseAvail
end

--- Get the effective target size (auto measured, dragSize, or panelSizePx from init).
---@param id string Panel identifier
---@return number|nil targetSize Effective panel target size in pixels
function expand.getTargetSize(id)
    local s = expandStates[id]
    if not s then return nil end
    if s.sizeMode == "auto" and s.measuredSize then
        return s.measuredSize
    end
    return s.dragSize or s.panelSizePx
end

--- Store measured content size (called from splitter after rendering content).
---@param id string Panel identifier
---@param size number Measured content extent in pixels
function expand.setMeasuredSize(id, size)
    local s = expandStates[id]
    if not s then return end
    s.measuredSize = size
end

--- Apply drag delta. Dispatches to fixed (adjusts window via dragOffset) or
--- flex (adjusts panel size via dragSize, window stays same).
---@param id string Panel identifier
---@param delta number Cumulative drag delta in pixels (from GetMouseDragDelta)
---@param dirMul number Direction multiplier: +1 for right/bottom, -1 for left/top
function expand.applyDrag(id, delta, dirMul)
    local s = expandStates[id]
    if not s then return end

    if s.sizeMode == "flex" then
        -- Flex mode: redistribute content/panel within same window size.
        if not s.panelDragStart then
            s.panelDragStart = s.dragSize or s.panelSizePx
        end
        s.dragSize = math.max(0, s.panelDragStart + (-dirMul) * delta)
    else
        -- Fixed mode: panel stays same, content (base) changes via offset.
        -- Window size changes with content.
        s.dragOffset = dirMul * delta
    end
end

--- Finalize drag state. Fixed mode commits offset to base; flex mode clears
--- drag start and lets Phase 5 reconcile base on the settling frame.
---@param id string Panel identifier
function expand.commitDrag(id)
    local s = expandStates[id]
    if not s then return end

    if s.sizeMode == "flex" then
        -- Don't adjust base — Phase 6 will reconcile on settling.
        -- Phase 4 close-settle forces resize to remove residual panel size.
        if LOG_FLEX then
            print(("[FLEX] commitDrag id=%s dragSize=%s panelDragStart=%s")
                :format(id, tostring(s.dragSize), tostring(s.panelDragStart)))
        end
        s.panelDragStart = nil
    else
        -- Fixed mode: commit offset permanently to base
        local base = getWindowBase(s.windowName)
        if not base.w then return end
        if s.dragOffset then
            if s.baseAvail then
                s.baseAvail = s.baseAvail + s.dragOffset
            end
            if s.isVert then
                base.h = math.max(1, base.h + s.dragOffset)
            else
                base.w = math.max(1, base.w + s.dragOffset)
            end
            s.dragOffset = nil
        end
    end
end

--- Store per-frame panel state for applyWindowSize to consume.
--- Safe inside children — does NOT call SetWindowSize/SetWindowPos.
---@param id string Panel identifier
---@param panelSize number Current animated panel size
---@param isAnimating boolean Whether the splitter animation is in progress
---@param isDragging boolean Whether the user is currently dragging the expand bar
function expand.afterRender(id, panelSize, isAnimating, isDragging)
    local s = expandStates[id]
    if not s then return end
    s.currentPanelSize = panelSize
    s.currentAnimating = isAnimating
    s.currentDragging = isDragging or false
end

--------------------------------------------------------------------------------
-- Public API — Window level (must be called at main window scope)
--------------------------------------------------------------------------------

--- Drive window size and position anchoring for all expand panels on a window.
--- MUST be called inside Begin()/End() of the target window, OUTSIDE any children,
--- so that GetWindowSize() returns the main window's dimensions.
---@param windowName string The ImGui window name
function expand.applyWindowSize(windowName)
    local curW, curH = ImGui.GetWindowSize()
    local base = getWindowBase(windowName)

    -- Phase 1: Collect panels and sum contributions per axis
    local panels = {}
    local totalPanelW, totalPanelH = 0, 0
    for _, s in pairs(expandStates) do
        if s.windowName == windowName then
            panels[#panels + 1] = s
            local ps = s.currentPanelSize or 0
            if s.isVert then
                totalPanelH = totalPanelH + ps
            else
                totalPanelW = totalPanelW + ps
            end
        end
    end
    if #panels == 0 then return end

    -- Phase 2: Base capture (naked window = curSize minus all panel contributions)
    local needsCapture = false
    for _, s in ipairs(panels) do
        if s.pendingCapture then
            needsCapture = true
            s.pendingCapture = false
        end
    end
    if needsCapture or base.w == nil then
        base.w = curW - totalPanelW
        base.h = curH - totalPanelH
        if LOG_FLEX then
            print(("[FLEX] Phase2 CAPTURE curW=%.1f curH=%.1f totalPanelW=%.1f totalPanelH=%.1f => base.w=%.1f base.h=%.1f")
                :format(curW, curH, totalPanelW, totalPanelH, base.w, base.h))
        end
    end

    -- Flex frame summary (log once per frame when any flex panel is animating or unsettled)
    if LOG_FLEX then
        for _, s in ipairs(panels) do
            if s.sizeMode == "flex" and ((s.currentAnimating or false) or not s.settled) then
                print(("[FLEX] --- FRAME side=%s curW=%.1f curH=%.1f base.w=%.1f base.h=%.1f panelSize=%.1f anim=%s drag=%s settled=%s dragSize=%s closePending=%s")
                    :format(s.side, curW, curH, base.w, base.h,
                            s.currentPanelSize or 0, tostring(s.currentAnimating),
                            tostring(s.currentDragging), tostring(s.settled),
                            tostring(s.dragSize), tostring(s.flexClosePending)))
            end
        end
    end

    -- Phase 3: Effective base (apply fixed-mode drag offsets from all panels)
    local effW = base.w
    local effH = base.h
    for _, s in ipairs(panels) do
        if s.dragOffset and s.sizeMode ~= "flex" then
            if s.isVert then
                effH = effH + s.dragOffset
            else
                effW = effW + s.dragOffset
            end
        end
    end
    effW = math.max(1, effW)
    effH = math.max(1, effH)

    -- Phase 4: Determine if any panel needs a resize
    local shouldResize = false
    for _, s in ipairs(panels) do
        local isDragging = s.currentDragging or false
        local isAnimating = s.currentAnimating or false
        local isFixedDrag = isDragging and s.sizeMode ~= "flex"
        if isAnimating or isFixedDrag then
            shouldResize = true
            s.settled = false
            if s.sizeMode == "flex" then s.flexWasDragging = false end
        elseif isDragging and s.sizeMode == "flex" then
            -- Flex drag: window stays same size, no SetWindowSize needed
            s.settled = false
            s.flexWasDragging = true
        elseif s.sizeMode == "auto" and s.measuredSize
                and (s.currentPanelSize or 0) > 0
                and math.abs(s.currentPanelSize - s.measuredSize) > 2 then
            shouldResize = true
            s.settled = false
        elseif not s.settled then
            if s.sizeMode == "flex" and s.flexClosePending
                    and (s.currentPanelSize or 0) <= 0 then
                -- Flex close settling: force resize to shrink window to base
                -- (removes residual panel size from last animation frame)
                shouldResize = true
                s.flexClosePending = false
                if LOG_FLEX then
                    print(("[FLEX] Phase4 CLOSE-SETTLE side=%s base.w=%.1f base.h=%.1f")
                        :format(s.side, base.w, base.h))
                end
            elseif s.sizeMode == "flex" and s.flexWasDragging then
                -- Flex drag settling: protect dragSize from Phase 6 ratio snap-back
                -- Phase 6 will correctly adjust base.w for the new panel size
                s.flexDragSettled = true
                s.flexWasDragging = false
                if LOG_FLEX then
                    print(("[FLEX] Phase4 DRAG-SETTLE side=%s panelSize=%.1f dragSize=%s")
                        :format(s.side, s.currentPanelSize or 0, tostring(s.dragSize)))
                end
            elseif s.sizeMode == "flex" then
                -- Flex open settling: finalize window size (last anim frame may
                -- have been 1 step short; Phase 5 SetWindowSize closes the gap)
                shouldResize = true
                if LOG_FLEX then
                    print(("[FLEX] Phase4 OPEN-SETTLE side=%s panelSize=%.1f dragSize=%s")
                        :format(s.side, s.currentPanelSize or 0, tostring(s.dragSize)))
                end
            elseif s.sizeMode ~= "flex" then
                shouldResize = true
            end
            s.settled = true
        end
    end

    -- Phase 5: Single SetWindowSize (combined dimensions from all panels)
    local targetW = effW + totalPanelW
    local targetH = effH + totalPanelH
    if shouldResize then
        if LOG_FLEX then
            print(("[FLEX] Phase5 SetWindowSize curW=%.1f curH=%.1f => targetW=%.1f targetH=%.1f (base.w=%.1f base.h=%.1f effW=%.1f effH=%.1f panelW=%.1f panelH=%.1f)")
                :format(curW, curH, targetW, targetH, base.w, base.h, effW, effH, totalPanelW, totalPanelH))
        end
        ImGui.SetWindowSize(windowName, targetW, targetH)
        -- Suppress Phase 6 for 2 frames after SetWindowSize so the 1-frame
        -- GetWindowSize lag doesn't corrupt base.w
        base.resizeCooldown = 2
    end

    -- Phase 6: Manual resize detection (shared across all panels)
    -- Skip during flex drag — the mismatch is intentional (panel redistributes within same window)
    local anyFlexDrag = false
    for _, s in ipairs(panels) do
        if (s.currentDragging or false) and s.sizeMode == "flex" then
            anyFlexDrag = true
            break
        end
    end
    -- Skip while SetWindowSize is catching up (1-frame lag would corrupt base.w)
    local resizePending = false
    if base.resizeCooldown and base.resizeCooldown > 0 then
        base.resizeCooldown = base.resizeCooldown - 1
        resizePending = true
    end
    if not shouldResize and not anyFlexDrag and not resizePending
            and (totalPanelW + totalPanelH) > 0 then
        if math.abs(curW - targetW) > 1 or math.abs(curH - targetH) > 1 then
            local newBaseW = curW - totalPanelW
            local newBaseH = curH - totalPanelH
            if LOG_FLEX then
                print(("[FLEX] Phase6 RESIZE DETECTED curW=%.1f targetW=%.1f curH=%.1f targetH=%.1f | base.w %.1f=>%.1f base.h %.1f=>%.1f")
                    :format(curW, targetW, curH, targetH, base.w, newBaseW, base.h, newBaseH))
            end
            for _, s in ipairs(panels) do
                local oldBase = s.isVert and base.h or base.w
                local newBase = s.isVert and newBaseH or newBaseW
                if s.baseAvail then
                    s.baseAvail = s.baseAvail + (newBase - oldBase)
                end
                -- Flex mode: maintain panel/window ratio on manual resize
                -- Skip on settling frame — stale ratio would snap dragSize back to pre-drag value
                if s.sizeMode == "flex" and s.flexRatio and (s.currentPanelSize or 0) > 0
                        and not s.flexDragSettled then
                    local axisDim = s.isVert and curH or curW
                    local newPanelSize = math.floor(axisDim * s.flexRatio)
                    s.dragSize = newPanelSize
                end
                -- Flex mode: compute/update ratio from current panel state
                if s.sizeMode == "flex" and (s.currentPanelSize or 0) > 0 then
                    local axisDim = s.isVert and curH or curW
                    local panelForRatio = s.dragSize or s.currentPanelSize
                    if axisDim > 0 and panelForRatio > 0 then
                        s.flexRatio = panelForRatio / axisDim
                    end
                end
            end
            base.w = newBaseW
            base.h = newBaseH
        end
    end
    -- Clear 1-frame flex settling flag unconditionally
    for _, s in ipairs(panels) do
        s.flexDragSettled = false
    end

    -- Phase 7: Position anchoring for left/top panels
    for _, s in ipairs(panels) do
        if s.side == "left" or s.side == "top" then
            local isDragging = s.currentDragging or false
            local isAnimating = s.currentAnimating or false
            local curPosX, curPosY = ImGui.GetWindowPos()
            if (isAnimating or isDragging) and s.anchorEdge then
                if s.side == "left" then
                    ImGui.SetWindowPos(windowName, s.anchorEdge - curW, curPosY)
                else
                    ImGui.SetWindowPos(windowName, curPosX, s.anchorEdge - curH)
                end
            elseif not isAnimating and not isDragging then
                s.anchorEdge = (s.side == "left") and (curPosX + curW) or (curPosY + curH)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Public API — Constraint queries (callable anywhere)
--------------------------------------------------------------------------------

--- Get animated constraint value for pre-Begin() setup.
--- Returns nil if the panel hasn't been initialized yet or normalPct isn't configured.
---@param id string Panel identifier
---@param isOpen boolean Current open state
---@return number|nil constraintPct Animated constraint % for SetNextWindowSizeConstraintsPercent
function expand.getConstraint(id, isOpen)
    local s = expandStates[id]
    if not s or not s.constraintProp or not s.normalPct then return nil end

    -- During drag, skip constraint to allow free sizing
    if s.currentDragging then return nil end

    local dim = s.cachedDisplayDim
    if not dim or dim <= 0 then return nil end

    local effectiveSize = s.dragSize or s.panelSizePx
    if not effectiveSize then return nil end

    local deltaPct = (effectiveSize / dim) * 100
    return core.updateConstraintAnimation(
        s.constraintProp,
        s.normalPct,
        s.normalPct + deltaPct,
        isOpen
    )
end

--- Programmatic open/close (mirror of splitter.setToggle for expand concerns).
---@param id string Panel identifier
---@param isOpen boolean Desired state
function expand.setOpen(id, isOpen)
    expand.onToggle(id, isOpen)
end

return expand
