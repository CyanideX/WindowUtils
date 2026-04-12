------------------------------------------------------
-- WindowUtils - External Window Management
-- Probe state machine, external window state,
-- drag detection, re-probe timers, collapsed pOpen
------------------------------------------------------

local core = require("core/core")
local settings = require("core/settings")
local discovery = require("core/discovery")
local registry = require("core/registry")
local frameContext = require("core/frameContext")

---@class WindowUtilsExternal
local external = {}

local externalDraggingCount = 0

local pushExternalWindowFn = nil
local popExternalWindowFn = nil

--- Inject style push/pop callbacks to avoid requiring modules/styles from core.
---@param pushFn function styles.PushExternalWindow
---@param popFn function styles.PopExternalWindow
function external.setStyleCallbacks(pushFn, popFn)
    pushExternalWindowFn = pushFn
    popExternalWindowFn = popFn
end

local externalWindowStates = {}

local blockedReprobeTimer = 0
local activeReprobeTimer = 0
local activeReprobeIndex = 0

-- Windows at 9000+ are hidden by other mods
local OFFSCREEN_THRESHOLD = 9000

-- CET/ImGui internal windows that should never be managed
local coreExcludedWindows = {
    ["Debug##Default"] = true,
}

local function isShiftHeld()
    return ImGui.IsKeyDown(ImGuiKey.LeftShift) or ImGui.IsKeyDown(ImGuiKey.RightShift)
end

--- Increment externalDraggingCount when an external window starts dragging.
local function incrementExternalDragging()
    externalDraggingCount = externalDraggingCount + 1
end

--- Decrement externalDraggingCount when an external window stops dragging.
local function decrementExternalDragging()
    externalDraggingCount = externalDraggingCount - 1
    if externalDraggingCount < 0 then
        settings.debugPrint("externalDraggingCount went negative")
        externalDraggingCount = 0
    end
end

--------------------------------------------------------------------------------
-- Probe Constants
--------------------------------------------------------------------------------

-- Probe system: detects windows not actively rendered by any mod.
-- Windows toggled off still exist in ImGui's layout data; calling Begin() creates empty frames.
-- SKIP: don't call Begin (lets window go inactive if no mod renders it)
-- CHECK: invisible probe (Alpha=0) - test IsWindowAppearing()
-- ACTIVE: confirmed active - manage normally
-- BLOCKED: confirmed inactive - don't call Begin
local PROBE_SKIP = 0
local PROBE_CHECK = 1
local PROBE_ACTIVE = 2
local PROBE_BLOCKED = 3

-- Probe flags: prevent invisible probe from stealing focus or input
local PROBE_FLAGS = ImGuiWindowFlags.NoFocusOnAppearing
    + ImGuiWindowFlags.NoBringToFrontOnFocus
    + ImGuiWindowFlags.NoInputs
    + ImGuiWindowFlags.NoNav

--------------------------------------------------------------------------------
-- External Window State
--------------------------------------------------------------------------------

local function getExternalWindowState(windowName)
    if not externalWindowStates[windowName] then
        local state = core.createBaseWindowState(windowName)
        state.probePhase = PROBE_SKIP
        state.skipFrames = 0
        state.blockedPosX = 0
        state.blockedPosY = 0
        state.blockedSizeX = 0
        state.blockedSizeY = 0
        state.wasActive = false
        state.wasFocused = false
        state.autoRemoved = false
        externalWindowStates[windowName] = state
    end
    return externalWindowStates[windowName]
end

local function shouldManageWindow(windowName)
    if coreExcludedWindows[windowName] then
        return false
    end
    local windowStates = core.getWindowStates()
    if windowStates[windowName] then
        return false
    end
    if settings.isWindowIgnored(windowName) then
        return false
    end
    if type(CETWM) == "table" and type(CETWM.windows) == "table" then
        local wmState = CETWM.windows[windowName]
        if wmState then
            if not wmState.visible then return false end
            if wmState.locked then return false end
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- Probe and Close Button Resolution
--------------------------------------------------------------------------------

--- Resolve effective hasCloseButton for a window.
--- Priority: user override > registry > default(false)
--- Hidden windows are still managed but don't get pOpen overrides.
---@param windowName string
---@return boolean
local function resolveHasCloseButton(windowName)
    if settings.isWindowHidden(windowName) then return false end
    local override = settings.windows.overrides[windowName]
    if override ~= nil then return override end
    local entry = registry.lookup(windowName)
    if entry then return entry.hasCloseButton end
    return false
end

--- Resolve effective hasCloseButton for a window (public wrapper).
---@param windowName string
---@return boolean
function external.resolveHasCloseButton(windowName)
    return resolveHasCloseButton(windowName)
end

-- Invisible probe: Alpha=0 Begin, check IsWindowAppearing().
-- Always uses 3-arg form so PROBE_FLAGS are applied as window flags.
-- (CET has no 2-arg Begin(name, flags) overload; 2-arg is Begin(name, pOpen).)
local function probeWindowActivity(windowName)
    ImGui.PushStyleVar(ImGuiStyleVar.Alpha, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    ImGui.Begin(windowName, true, PROBE_FLAGS)
    local active = not ImGui.IsWindowAppearing()
    ImGui.End()
    ImGui.PopStyleVar(2)
    return active
end

--------------------------------------------------------------------------------
-- External Window Animation
--------------------------------------------------------------------------------

-- Advance snap animation for an external window (called after manageExternalWindow).
-- Uses deferred operations to avoid an extra Begin/End scope that could conflict
-- with the owning mod's window flags.
local function animateExternalWindow(windowName, state)
    if not state.animating then return end

    if not settings.master.gridEnabled or not settings.master.animationEnabled then
        state.animating = false
        return
    end

    local duration = settings.master.animationDuration
    local t, newPosX, newPosY, newSizeX, newSizeY = core.calculateAnimationFrame(state, windowName, duration)

    core.addDeferredSnap(windowName, newPosX, newPosY, newSizeX, newSizeY)

    if t >= 1 then
        state.animating = false
    end
end

--------------------------------------------------------------------------------
-- Reusable Param Tables
--------------------------------------------------------------------------------

-- Reusable params table for collapsed-window drag snap in updateExternalWindows
local collapsedFrameParams = {
    windowName = "",
    state = nil,
    currentPosX = 0,
    currentPosY = 0,
    currentSizeX = 0,
    currentSizeY = 0,
    isCollapsed = true,
    isFocused = false,
    isDragging = false,
    isReleased = true,
    shiftHeld = false,
    treatAllDrags = false,
    useGrid = true,
    useAnimation = false,
    duration = 0.2,
    snapCollapsed = true,
    canSetWindowPos = false,
    canSetWindowSize = false,
}

-- Reusable params table for manageExternalWindow to avoid per-frame allocation
local externalFrameParams = {
    windowName = "",
    state = nil,
    currentPosX = 0,
    currentPosY = 0,
    currentSizeX = 0,
    currentSizeY = 0,
    isCollapsed = false,
    isFocused = false,
    isDragging = false,
    isReleased = false,
    shiftHeld = false,
    treatAllDrags = false,
    useGrid = false,
    useAnimation = false,
    duration = 0.2,
    snapCollapsed = true,
    canSetWindowPos = false,
    canSetWindowSize = false,
}

--------------------------------------------------------------------------------
-- Manage External Window
--------------------------------------------------------------------------------

--- Manage an external window: drag detection, snap, animation.
--- Uses Begin/End for real-time position and focus queries.
--- Delegates frame processing to processWindowFrame with deferred snap path.
---@param windowName string
---@param state table External window state
---@param windowInfo table Discovery data (used for collapsed check only)
local function manageExternalWindow(windowName, state, windowInfo)
    local visible = ImGui.Begin(windowName)

    local isCollapsed = not visible
    local currentPosX, currentPosY = ImGui.GetWindowPos()

    -- Skip offscreen windows (likely hidden by another mod)
    if currentPosX >= OFFSCREEN_THRESHOLD or currentPosY >= OFFSCREEN_THRESHOLD then
        if state.isDragging then
            decrementExternalDragging()
            core.clearDraggingState(state)
        end
        state.animating = false
        ImGui.End()
        return
    end

    local currentSizeX, currentSizeY = ImGui.GetWindowSize()

    -- On first management frame, restore cached size if available.
    -- Prevents the owning mod's default/min size from overwriting the cache.
    if not state.initialized then
        state.initialized = true
        if not isCollapsed and state.expandedSizeX and state.expandedSizeY then
            core.addDeferredSnap(windowName, nil, nil, state.expandedSizeX, state.expandedSizeY)
            currentSizeX = state.expandedSizeX
            currentSizeY = state.expandedSizeY
        end
    end

    local isFocused = ImGui.IsWindowFocused()
    local wasDragging = state.isDragging or state.pendingDragCheck
    local wasDraggingExact = state.isDragging

    -- Delegate expanded tracking, collapsed restore, drag detection, snap, animation
    local p = externalFrameParams
    p.windowName = windowName
    p.state = state
    p.currentPosX = currentPosX
    p.currentPosY = currentPosY
    p.currentSizeX = currentSizeX
    p.currentSizeY = currentSizeY
    p.isCollapsed = isCollapsed
    p.isFocused = isFocused
    p.isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
    p.isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
    p.shiftHeld = isShiftHeld()
    p.treatAllDrags = false
    p.useGrid = settings.master.gridEnabled
    p.useAnimation = settings.master.animationEnabled
    p.duration = settings.master.animationDuration
    p.snapCollapsed = settings.master.snapCollapsed
    p.canSetWindowPos = false
    p.canSetWindowSize = false

    local result = core.processWindowFrame(p)

    -- Track isDragging transitions that happened inside processWindowFrame
    if not wasDraggingExact and state.isDragging then
        incrementExternalDragging()
    elseif wasDraggingExact and not state.isDragging then
        decrementExternalDragging()
    end

    -- Clear dragging bounds when drag ended without a snap animation
    if wasDragging and not state.isDragging and not state.pendingDragCheck and not state.animating then
        core.clearDraggingState(state)
    end

    -- Click-to-clean: focus triggers re-probe to detect empty shells
    local hasCloseButton = resolveHasCloseButton(windowName)
    if isFocused and not state.wasFocused and not hasCloseButton then
        state.probePhase = PROBE_SKIP
        state.skipFrames = 1
        state.wasActive = true
        state.autoRemoved = false
        state.pendingDragCheck = false
    end
    state.wasFocused = isFocused

    ImGui.End()
end

--------------------------------------------------------------------------------
-- Update External Windows (main per-frame entry point)
--------------------------------------------------------------------------------

---Process all external windows: probe state machine, drag detection, snap, animation.
---Called once per frame from init.lua when the overlay is open.
function external.updateExternalWindows()
    -- Only process when master override is enabled
    if not settings.master.enabled or not settings.master.overrideAllWindows then
        return
    end

    if not discovery.isAvailable() then
        return
    end

    discovery.invalidateCache()
    local windows = discovery.getActiveWindows()

    local extVars, extColors = 0, 0
    if pushExternalWindowFn then
        extVars, extColors = pushExternalWindowFn(
            settings.master.overrideStyling,
            settings.master.disableScrollbar
        )
    end

    for _, windowInfo in ipairs(windows) do
        local windowName = windowInfo.name

        if shouldManageWindow(windowName)
            and windowInfo.posX < OFFSCREEN_THRESHOLD
            and windowInfo.posY < OFFSCREEN_THRESHOLD
        then
            local state = getExternalWindowState(windowName)

            -- hasCloseButton windows bypass the probe state machine.
            -- They have a proper close mechanism (pOpen), so empty-shell detection
            -- is unnecessary. manageExternalWindow sets BLOCKED when pOpen=false.
            -- Respect BLOCKED state; only discovery data changes can wake them.
            if resolveHasCloseButton(windowName) then
                if state.probePhase == PROBE_BLOCKED then
                    local posChanged = windowInfo.posX ~= state.blockedPosX or windowInfo.posY ~= state.blockedPosY
                    local sizeChanged = windowInfo.sizeX ~= state.blockedSizeX or windowInfo.sizeY ~= state.blockedSizeY
                    if posChanged or sizeChanged then
                        state.probePhase = PROBE_ACTIVE
                    end
                else
                    state.probePhase = PROBE_ACTIVE
                    manageExternalWindow(windowName, state, windowInfo)
                    animateExternalWindow(windowName, state)
                end
            elseif state.probePhase == PROBE_SKIP then
                state.skipFrames = (state.skipFrames or 0) + 1
                -- wasActive needs only 1 skip frame (owning mod handles rendering).
                -- Previously-blocked needs 2 for reliable IsWindowAppearing().
                local threshold = state.wasActive and 1 or 2
                if state.skipFrames >= threshold then
                    state.probePhase = PROBE_CHECK
                end

            elseif state.probePhase == PROBE_CHECK then
                -- Always use invisible probe to avoid 1-frame flash for empty shells
                local active = probeWindowActivity(windowName)
                state.wasActive = false

                if active then
                    state.probePhase = PROBE_ACTIVE
                    state.autoRemoved = false
                else
                    state.probePhase = PROBE_BLOCKED
                    state.animating = false
                    state.blockedPosX = windowInfo.posX
                    state.blockedPosY = windowInfo.posY
                    state.blockedSizeX = windowInfo.sizeX
                    state.blockedSizeY = windowInfo.sizeY

                    -- Clean up drag state
                    if state.isDragging then
                        decrementExternalDragging()
                        core.clearDraggingState(state)
                    end
                    state.pendingDragCheck = false
                end

            elseif state.probePhase == PROBE_ACTIVE then
                manageExternalWindow(windowName, state, windowInfo)
                animateExternalWindow(windowName, state)

            elseif state.probePhase == PROBE_BLOCKED then
                local posChanged = windowInfo.posX ~= state.blockedPosX or windowInfo.posY ~= state.blockedPosY
                local sizeChanged = windowInfo.sizeX ~= state.blockedSizeX or windowInfo.sizeY ~= state.blockedSizeY
                if posChanged or sizeChanged then
                    state.probePhase = PROBE_SKIP
                    state.skipFrames = 0
                    state.autoRemoved = false
                end

            end
        else
            -- Clean up stale external state
            local staleState = externalWindowStates[windowName]
            if staleState then
                if staleState.isDragging then
                    decrementExternalDragging()
                    core.clearDraggingState(staleState)
                end
                externalWindowStates[windowName] = nil
            end
        end
    end

    if popExternalWindowFn then
        popExternalWindowFn(extVars, extColors)
    end

    -- Collapsed pOpen windows: core.update() can't detect drags for collapsed
    -- windows (CET's ImGui returns stale position and unfocused state).
    -- Use discovery data for real position and mouse state for drag detection.
    if settings.master.enabled and settings.master.gridEnabled
        and settings.master.snapCollapsed and discovery.isAvailable()
    then
        -- Build name-keyed lookup to avoid O(collapsed x total) linear scan
        local windowsByName = {}
        for _, w in ipairs(windows) do
            windowsByName[w.name] = w
        end

        local windowStates = core.getWindowStates()
        for windowName, state in pairs(windowStates) do
            if state.wasCollapsed then
                local w = windowsByName[windowName]
                local realPosX = w and w.posX
                local realPosY = w and w.posY

                if realPosX then
                    local currentSizeX = state.expandedSizeX or 200
                    local currentSizeY = state.expandedSizeY or 200
                    local isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
                    local isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
                    local shiftHeld = isShiftHeld()

                    -- Detect drag via position change (no focus available)
                    if isDragging then
                        if not state.collapsedTrackPosX then
                            state.collapsedTrackPosX = realPosX
                            state.collapsedTrackPosY = realPosY
                        end
                        local posChanged = realPosX ~= state.collapsedTrackPosX
                            or realPosY ~= state.collapsedTrackPosY
                        if posChanged then
                            state.isDragging = true
                            state.animating = false
                            core.updateDraggingBounds(windowName, realPosX, realPosY,
                                currentSizeX, currentSizeY)
                        end
                        state.collapsedTrackPosX = realPosX
                        state.collapsedTrackPosY = realPosY

                    elseif isReleased and state.isDragging then
                        state.isDragging = false
                        state.collapsedTrackPosX = nil
                        state.collapsedTrackPosY = nil

                        -- Delegate snap calculation and animation setup to
                        -- processWindowFrame. Set pendingDragCheck so that
                        -- handleDragDetection returns "changed" on this frame.
                        -- dragCheckPosX/Y are set to values that guarantee
                        -- posChanged=true (the drag already moved the window).
                        state.pendingDragCheck = true
                        state.dragCheckPosX = realPosX + 1
                        state.dragCheckPosY = realPosY + 1

                        local p = collapsedFrameParams
                        p.windowName = windowName
                        p.state = state
                        p.currentPosX = realPosX
                        p.currentPosY = realPosY
                        p.currentSizeX = currentSizeX
                        p.currentSizeY = currentSizeY
                        p.isCollapsed = true
                        p.isReleased = true
                        p.isDragging = false
                        p.isFocused = false
                        p.shiftHeld = shiftHeld
                        p.useGrid = true
                        p.useAnimation = settings.master.animationEnabled
                        p.duration = settings.master.animationDuration
                        p.snapCollapsed = true
                        p.canSetWindowPos = false
                        p.canSetWindowSize = false

                        core.processWindowFrame(p)

                    elseif not isDragging then
                        state.collapsedTrackPosX = nil
                        state.collapsedTrackPosY = nil
                        if state.isDragging then
                            core.clearDraggingState(state)
                        end
                    end

                    -- Animate collapsed snap (position only, uses named API)
                    if state.animating and state.wasCollapsed then
                        if not settings.master.animationEnabled then
                            state.animating = false
                        else
                            local duration = settings.master.animationDuration or settings.defaults.animationDuration
                            local t, newPosX, newPosY = core.calculateAnimationFrame(state, windowName, duration)

                            core.addDeferredSnap(windowName, newPosX, newPosY, nil, nil)

                            if t >= 1 then
                                state.animating = false
                            end
                        end
                    end
                end
            end
        end
    end

    -- Timekeeping
    local fc = frameContext.get()
    local deltaTime = fc.deltaTime

    local interval = settings.master.probeInterval or 0.5

    -- Re-probe BLOCKED windows that haven't been auto-removed.
    -- Auto-removed windows stay blocked until discovery data changes or overlay reopens.
    blockedReprobeTimer = blockedReprobeTimer + deltaTime
    if blockedReprobeTimer >= interval then
        blockedReprobeTimer = blockedReprobeTimer - interval
        for _, state in pairs(externalWindowStates) do
            if state.probePhase == PROBE_BLOCKED and not state.autoRemoved then
                state.probePhase = PROBE_SKIP
                state.skipFrames = 0
            end
        end
    end

    -- Re-probe idle ACTIVE windows to detect empty shells (skip busy windows)
    if settings.master.autoRemoveEmptyWindows then
        local autoRemoveInterval = settings.master.autoRemoveInterval or 0.5
        activeReprobeTimer = activeReprobeTimer + deltaTime
        if activeReprobeTimer >= autoRemoveInterval then
            activeReprobeTimer = activeReprobeTimer - autoRemoveInterval

            if settings.master.batchAutoRemove ~= false then
                -- Batch: check all idle windows at once
                for windowName, state in pairs(externalWindowStates) do
                    if state.probePhase == PROBE_ACTIVE
                        and not state.isDragging
                        and not state.animating
                        and not state.pendingDragCheck
                        and not resolveHasCloseButton(windowName)
                    then
                        state.probePhase = PROBE_SKIP
                        state.skipFrames = 1
                        state.wasActive = true
                        state.autoRemoved = true
                        state.pendingDragCheck = false
                    end
                end
            else
                -- Sequential: check one idle window per interval (round-robin)
                local candidates = {}
                for windowName, state in pairs(externalWindowStates) do
                    if state.probePhase == PROBE_ACTIVE
                        and not state.isDragging
                        and not state.animating
                        and not state.pendingDragCheck
                        and not resolveHasCloseButton(windowName)
                    then
                        candidates[#candidates + 1] = state
                    end
                end
                if #candidates > 0 then
                    activeReprobeIndex = (activeReprobeIndex % #candidates) + 1
                    local state = candidates[activeReprobeIndex]
                    state.probePhase = PROBE_SKIP
                    state.skipFrames = 1
                    state.wasActive = true
                    state.autoRemoved = true
                    state.pendingDragCheck = false
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Reset and Query
--------------------------------------------------------------------------------

--- Reset all external probes (called on overlay open).
--- ACTIVE uses wasActive (flicker-free), BLOCKED uses standard probe.
function external.resetExternalProbes()
    for windowName, state in pairs(externalWindowStates) do
        if state.probePhase == PROBE_ACTIVE then
            -- hasCloseButton windows don't need re-probing (they have a proper close mechanism)
            if not resolveHasCloseButton(windowName) then
                state.probePhase = PROBE_SKIP
                state.skipFrames = 1
                state.wasActive = true
                state.pendingDragCheck = false
            end
        elseif state.probePhase == PROBE_BLOCKED then
            state.probePhase = PROBE_SKIP
            state.skipFrames = 0
            state.autoRemoved = false
            state.wasActive = false
        end
    end
    blockedReprobeTimer = 0
    activeReprobeTimer = 0
    activeReprobeIndex = 0
end

--- Check if any external window is being dragged.
---@return boolean
function external.isAnyExternalWindowDragging()
    return externalDraggingCount > 0
end

--------------------------------------------------------------------------------
-- Snap All Windows
--------------------------------------------------------------------------------

--- Re-snap all active windows to the current grid.
function external.snapAllWindows()
    if not settings.master.overrideAllWindows then return end
    if not discovery.isAvailable() then return end

    local windows = discovery.getActiveWindows()
    local windowStates = core.getWindowStates()
    for _, windowInfo in ipairs(windows) do
        local name = windowInfo.name
        if not coreExcludedWindows[name]
            and windowInfo.posX < OFFSCREEN_THRESHOLD
            and windowInfo.posY < OFFSCREEN_THRESHOLD
            and not windowInfo.collapsed
        then
            local extState = externalWindowStates[name]
            local intState = windowStates[name]
            if (extState and extState.probePhase == PROBE_ACTIVE) or intState then
                local targetX = core.snapToGrid(windowInfo.posX)
                local targetY = core.snapToGrid(windowInfo.posY)
                local targetW = core.snapToGrid(windowInfo.sizeX)
                local targetH = core.snapToGrid(windowInfo.sizeY)

                local state = extState or intState
                if settings.master.animationEnabled then
                    state.animating = true
                    state.animationStartTime = frameContext.get().clock
                    state.startPosX = windowInfo.posX
                    state.startPosY = windowInfo.posY
                    state.targetPosX = targetX
                    state.targetPosY = targetY
                    state.startSizeX = windowInfo.sizeX
                    state.startSizeY = windowInfo.sizeY
                    state.targetSizeX = targetW
                    state.targetSizeY = targetH
                else
                    core.addDeferredSnap(name, targetX, targetY, targetW, targetH)
                end
            end
        end
    end
end

return external
