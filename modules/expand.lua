-- expand.lua - Window Expansion Manager
-- Manages window resizing for expand-mode toggle panels. See docs/expand.md for architecture.

local core = require("modules/core")
local controls = require("modules/controls")

local expand = {}

--- Per-panel expansion state
local expandStates = {}

--- Per-window panel index: windowName → { id1, id2, ... }
local windowPanels = {}

--- Per-window base dimensions (shared by all panels on a window).
--- Represents the "naked" window size with no expand panels open.
local windowBases = {}

local function getWindowBase(windowName)
    if not windowBases[windowName] then
        windowBases[windowName] = { w = nil, h = nil, resizeCooldown = 0 }
    end
    return windowBases[windowName]
end

--------------------------------------------------------------------------------
-- Public API - Content level (safe inside children)
--------------------------------------------------------------------------------

--- Register/update expand panel config (idempotent, safe to call every frame).
--- Only creates state on first call; subsequent calls update panelSizePx and display dim.
---@param id string Panel identifier (same id used with splitter.toggle)
---@param opts table { windowName, side, size, normalConstraintPct, expandDuration, expandEasing }
function expand.init(id, opts)
    local isVert = (opts.side == "top" or opts.side == "bottom")
    local fc = controls.getFrameCache()

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
            cachedDisplayDim = isVert and fc.displayHeight or fc.displayWidth,
        }
        -- Register in per-window panel index
        local wn = opts.windowName
        if not windowPanels[wn] then windowPanels[wn] = {} end
        windowPanels[wn][#windowPanels[wn] + 1] = id
    else
        -- Update per-frame values that may change (e.g. resolved size, display dim)
        local s = expandStates[id]
        s.panelSizePx = opts.size or s.panelSizePx
        s.cachedDisplayDim = isVert and fc.displayHeight or fc.displayWidth
        -- Reset stale state on mode switch
        if opts.sizeMode and opts.sizeMode ~= s.sizeMode then
            s.sizeMode = opts.sizeMode
            s.dragSize = nil
            s.dragOffset = nil
            s.flexRatio = nil
            -- baseAvail intentionally NOT cleared: it represents the base content
            -- region size (window-level property), independent of panel mode.
            s.settled = false
            s.flexClosePending = false
            s.flexDragSettled = false
            s.flexWasDragging = false
            s.lastCachePanelSize = nil
            s.panelDragStart = nil
            s.measuredSize = nil
        else
            s.sizeMode = opts.sizeMode or s.sizeMode
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

    -- Mark unsettled so Phase 4 fires on the next applyWindowSize() call.
    -- Critical for no-animation mode where isAnimating is never true.
    s.settled = false

    -- Capture base window size on the next applyWindowSize() call (click-to-open frame)
    if isOpen then
        s.pendingCapture = true
        s.flexClosePending = false
    elseif s.sizeMode == "flex" then
        s.flexClosePending = true
    end

    -- Trigger constraint animation if normalPct is configured
    if s.normalPct then
        local dim = s.cachedDisplayDim
        local effectiveSize = s.sizeMode == "auto"
            and s.measuredSize
            or (s.dragSize or s.panelSizePx)
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
--- Only updates baseAvail when the panel has been closed for 2+ consecutive frames,
--- ensuring SetWindowSize has caught up from any prior close (1-frame lag). Without
--- this guard, no-animation close captures the stale expanded totalAvail on the first
--- closed frame, causing flexSize to grow on subsequent open cycles.
---@param id string Panel identifier
---@param totalAvail number Current content region available (from GetContentRegionAvail)
---@param panelSize number Current animated panel size (0 when closed)
function expand.cacheBase(id, totalAvail, panelSize)
    local s = expandStates[id]
    if not s then return end

    if s.baseAvail == nil then
        -- First capture or after mode-switch reset.
        -- If panel is open, totalAvail includes panel contribution - subtract it.
        s.baseAvail = panelSize > 0 and (totalAvail - panelSize) or totalAvail
    elseif panelSize <= 0 and (s.lastCachePanelSize or 0) <= 0 then
        -- Panel closed for 2+ consecutive frames: safe to update (SetWindowSize lag resolved)
        s.baseAvail = totalAvail
    end
    s.lastCachePanelSize = panelSize
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
        if not s.panelDragStart then
            s.panelDragStart = s.dragSize or s.panelSizePx
        end
        s.dragSize = math.max(0, s.panelDragStart + (-dirMul) * delta)
    else
        s.dragOffset = dirMul * delta
    end
end

--- Finalize drag state. Fixed mode commits offset to base; flex mode clears
--- drag start and lets Phase 6 reconcile base on the settling frame.
---@param id string Panel identifier
function expand.commitDrag(id)
    local s = expandStates[id]
    if not s then return end

    if s.sizeMode == "flex" then
        s.panelDragStart = nil
    else
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
--- Safe inside children - does NOT call SetWindowSize/SetWindowPos.
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
-- Phase helpers for applyWindowSize (called in order, Phase 1 through Phase 7)
--------------------------------------------------------------------------------

--- Phase 1: Collect panels and sum contributions per axis.
---@param windowName string The ImGui window name
---@return table panels Array of panel state tables
---@return number totalPanelW Total horizontal panel contribution in pixels
---@return number totalPanelH Total vertical panel contribution in pixels
local function collectPanelContributions(windowName)
    local ids = windowPanels[windowName]
    if not ids or #ids == 0 then return {}, 0, 0 end
    local panels = {}
    local totalPanelW, totalPanelH = 0, 0
    for _, pid in ipairs(ids) do
        local s = expandStates[pid]
        if s then
            panels[#panels + 1] = s
            local ps = s.currentPanelSize or 0
            if s.isVert then
                totalPanelH = totalPanelH + ps
            else
                totalPanelW = totalPanelW + ps
            end
        end
    end
    return panels, totalPanelW, totalPanelH
end

--- Phase 2: Capture base window dimensions (naked = curSize minus settled panels).
--- Panels with pendingCapture just opened, so their currentPanelSize is already set
--- by afterRender but curW/curH hasn't grown to include them yet (no SetWindowSize
--- fired). Exclude their contribution to avoid underestimating the base.
---@param base table Window base dimensions { w, h, resizeCooldown }
---@param panels table Array of panel state tables
---@param curW number Current window width from GetWindowSize
---@param curH number Current window height from GetWindowSize
---@param totalPanelW number Total horizontal panel contribution
---@param totalPanelH number Total vertical panel contribution
local function captureBase(base, panels, curW, curH, totalPanelW, totalPanelH)
    local needsCapture = false
    local excludeW, excludeH = 0, 0
    for _, s in ipairs(panels) do
        if s.pendingCapture then
            needsCapture = true
            s.pendingCapture = false
            local ps = s.currentPanelSize or 0
            if s.isVert then
                excludeH = excludeH + ps
            else
                excludeW = excludeW + ps
            end
        end
    end
    if needsCapture or base.w == nil then
        base.w = curW - (totalPanelW - excludeW)
        base.h = curH - (totalPanelH - excludeH)
    end
end

--- Phase 3: Compute effective base with fixed-mode drag offsets from all panels.
---@param base table Window base dimensions { w, h, resizeCooldown }
---@param panels table Array of panel state tables
---@return number effW Effective base width (clamped >= 1)
---@return number effH Effective base height (clamped >= 1)
local function computeEffectiveBase(base, panels)
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
    return math.max(1, effW), math.max(1, effH)
end

--- Phase 4: Check if any panel needs a resize. Updates settled/flex flags as side effects.
---@param panels table Array of panel state tables
---@return boolean shouldResize True if SetWindowSize should be called this frame
local function determineResize(panels)
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
                shouldResize = true
                s.flexClosePending = false
            elseif s.sizeMode == "flex" and s.flexWasDragging then
                s.flexDragSettled = true
                s.flexWasDragging = false
            elseif s.sizeMode == "flex" then
                shouldResize = true
            elseif s.sizeMode ~= "flex" then
                shouldResize = true
            end
            s.settled = true
        end
    end
    return shouldResize
end

--- Phase 5: Single SetWindowSize with combined dimensions from all panels.
--- Returns target dimensions for use by Phase 6.
---@param windowName string The ImGui window name
---@param effW number Effective base width
---@param effH number Effective base height
---@param totalPanelW number Total horizontal panel contribution
---@param totalPanelH number Total vertical panel contribution
---@param base table Window base dimensions { w, h, resizeCooldown }
---@param shouldResize boolean Whether SetWindowSize should fire
---@return number targetW Target window width
---@return number targetH Target window height
local function applyResize(windowName, effW, effH, totalPanelW, totalPanelH, base, shouldResize)
    local targetW = effW + totalPanelW
    local targetH = effH + totalPanelH
    if shouldResize then
        ImGui.SetWindowSize(windowName, targetW, targetH)
        -- Suppress Phase 6 for 2 frames so the 1-frame GetWindowSize lag
        -- doesn't corrupt base.w
        base.resizeCooldown = 2
    end
    return targetW, targetH
end

--- Phase 6: Manual resize detection. Updates base dimensions, baseAvail, and
--- flexRatio when the user resizes the window by dragging its edges.
--- Skipped during flex drag (mismatch is intentional) and while SetWindowSize
--- is catching up (1-frame lag would corrupt base.w).
---@param base table Window base dimensions { w, h, resizeCooldown }
---@param panels table Array of panel state tables
---@param curW number Current window width from GetWindowSize
---@param curH number Current window height from GetWindowSize
---@param targetW number Expected target width from Phase 5
---@param targetH number Expected target height from Phase 5
---@param totalPanelW number Total horizontal panel contribution
---@param totalPanelH number Total vertical panel contribution
---@param shouldResize boolean Whether Phase 5 fired SetWindowSize
local function detectManualResize(base, panels, curW, curH, targetW, targetH,
                                   totalPanelW, totalPanelH, shouldResize)
    local anyFlexDrag = false
    for _, s in ipairs(panels) do
        if (s.currentDragging or false) and s.sizeMode == "flex" then
            anyFlexDrag = true
            break
        end
    end
    local resizePending = base.resizeCooldown > 0
    if resizePending then
        base.resizeCooldown = base.resizeCooldown - 1
    end
    if not shouldResize and not anyFlexDrag and not resizePending
            and (totalPanelW + totalPanelH) > 0 then
        if math.abs(curW - targetW) > 1 or math.abs(curH - targetH) > 1 then
            local newBaseW = curW - totalPanelW
            local newBaseH = curH - totalPanelH
            for _, s in ipairs(panels) do
                local oldBase = s.isVert and base.h or base.w
                local newBase = s.isVert and newBaseH or newBaseW
                if s.baseAvail then
                    s.baseAvail = s.baseAvail + (newBase - oldBase)
                end
                if s.sizeMode == "flex" and (s.currentPanelSize or 0) > 0 then
                    -- Maintain panel/window ratio on manual resize.
                    -- Skip on settling frame to protect dragSize from snap-back.
                    if s.flexRatio and not s.flexDragSettled then
                        local axisDim = s.isVert and curH or curW
                        s.dragSize = math.floor(axisDim * s.flexRatio)
                    end
                    -- Update ratio from current state
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
end

--- Phase 7: Position anchoring for left/top panels + flexDragSettled flag cleanup.
---@param windowName string The ImGui window name
---@param panels table Array of panel state tables
---@param curW number Current window width from GetWindowSize
---@param curH number Current window height from GetWindowSize
local function anchorPositions(windowName, panels, curW, curH)
    for _, s in ipairs(panels) do
        s.flexDragSettled = false
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
-- Public API - Window level (must be called at main window scope)
--------------------------------------------------------------------------------

--- Drive window size and position anchoring for all expand panels on a window.
--- MUST be called inside Begin()/End() of the target window, OUTSIDE any children,
--- so that GetWindowSize() returns the main window's dimensions.
---@param windowName string The ImGui window name
function expand.applyWindowSize(windowName)
    local curW, curH = ImGui.GetWindowSize()
    local base = getWindowBase(windowName)
    local panels, totalPanelW, totalPanelH = collectPanelContributions(windowName)
    if #panels == 0 then return end

    captureBase(base, panels, curW, curH, totalPanelW, totalPanelH)
    local effW, effH = computeEffectiveBase(base, panels)
    local shouldResize = determineResize(panels)
    local targetW, targetH = applyResize(windowName, effW, effH, totalPanelW, totalPanelH, base, shouldResize)
    detectManualResize(base, panels, curW, curH, targetW, targetH, totalPanelW, totalPanelH, shouldResize)
    anchorPositions(windowName, panels, curW, curH)
end

--------------------------------------------------------------------------------
-- Public API - Constraint queries (callable anywhere)
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
