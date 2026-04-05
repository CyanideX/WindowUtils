------------------------------------------------------
-- WindowUtils - Core
-- Window state management, grid snapping, animations
------------------------------------------------------

local settings = require("core/settings")
local discovery = require("core/discovery")
local utils = require("modules/utils")
local registry = require("core/registry")
local styles = require("modules/styles")

---@class WindowUtilsUpdateOptions
---@field gridEnabled? boolean Override grid snapping
---@field animationEnabled? boolean Override animations
---@field animationDuration? number Override animation duration
---@field treatAllDragsAsWindowDrag? boolean Treat all drags as window drags (for settings windows with live preview)

---@class WindowUtilsWindowBounds
---@field x number X position
---@field y number Y position
---@field width number Width
---@field height number Height

---@class WindowUtilsCore
local core = {}

local windowStates = {}

local constraintAnimations = {}
local constraintAnimByWindow = {}   -- windowName -> { property = true }, O(1) lookup
local snapPendingByWindow = {}      -- completed animations awaiting grid snap

local externalWindowStates = {}

local windowCachePath = "data/window_cache.json"
local windowCache = {}

local deferredSnapOperations = {}   -- reused across frames
local deferredSnapCount = 0

local function addDeferredSnap(windowName, targetPosX, targetPosY, targetSizeX, targetSizeY)
    deferredSnapCount = deferredSnapCount + 1
    local op = deferredSnapOperations[deferredSnapCount]
    if not op then
        op = {}
        deferredSnapOperations[deferredSnapCount] = op
    end
    op.windowName = windowName
    op.targetPosX = targetPosX
    op.targetPosY = targetPosY
    op.targetSizeX = targetSizeX
    op.targetSizeY = targetSizeY
end

local draggingWindowBounds = { x = 0, y = 0, width = 0, height = 0 }
local draggingWindowBoundsValid = false
local draggingWindowName = nil

local axisLock = {
    active = false,
    axis = nil,          -- "x" or "y"
    threshold = 10
}

local dragStartPos = { x = 0, y = 0 }

local gridSizeCache = {}

local blockedReprobeTimer = 0
local activeReprobeTimer = 0
local activeReprobeIndex = 0
local lastFrameTime = 0

-- Windows at 9000+ are hidden by other mods
local OFFSCREEN_THRESHOLD = 9000

-- CET/ImGui internal windows that should never be managed
local coreExcludedWindows = {
    ["Debug##Default"] = true,
}

--------------------------------------------------------------------------------
-- Drag Helper Functions
--------------------------------------------------------------------------------

local function applyAxisLock(windowName, currentPosX, currentPosY, shiftHeld)
    if shiftHeld then
        axisLock.active = true

        local deltaX = math.abs(currentPosX - dragStartPos.x)
        local deltaY = math.abs(currentPosY - dragStartPos.y)
        if deltaX >= axisLock.threshold or deltaY >= axisLock.threshold then
            axisLock.axis = deltaX > deltaY and "x" or "y"
        end

        if axisLock.axis == "x" then
            ImGui.SetWindowPos(windowName, currentPosX, dragStartPos.y)
            currentPosY = dragStartPos.y
        elseif axisLock.axis == "y" then
            ImGui.SetWindowPos(windowName, dragStartPos.x, currentPosY)
            currentPosX = dragStartPos.x
        end
    else
        axisLock.active = false
        axisLock.axis = nil
    end

    return currentPosX, currentPosY
end

local function updateDraggingBounds(windowName, posX, posY, sizeX, sizeY)
    draggingWindowBounds.x = posX
    draggingWindowBounds.y = posY
    draggingWindowBounds.width = sizeX
    draggingWindowBounds.height = sizeY
    draggingWindowBoundsValid = true
    draggingWindowName = windowName
end

--------------------------------------------------------------------------------
-- Grid Size Caching
--------------------------------------------------------------------------------

local function getGridSize(windowName)
    local cacheKey = windowName or "__master__"

    if not gridSizeCache[cacheKey] then
        local gridUnits
        if windowName then
            gridUnits = settings.getConfig(windowName, "gridUnits")
        else
            gridUnits = settings.master.gridUnits
        end
        -- Prevent division by zero
        if not gridUnits or gridUnits <= 0 then
            gridUnits = settings.defaults.gridUnits
        end
        gridSizeCache[cacheKey] = gridUnits * settings.GRID_UNIT_SIZE
    end

    return gridSizeCache[cacheKey]
end

--- Invalidate grid size cache (call when settings change).
function core.invalidateGridCache(windowName)
    if windowName then
        gridSizeCache[windowName] = nil
    else
        gridSizeCache = {}
    end
end

--------------------------------------------------------------------------------
-- Easing Functions
--------------------------------------------------------------------------------

local easeFunctions = {
    linear = function(t) return t end,
    easeIn = function(t) return t * t end,
    easeOut = function(t) return 1 - (1 - t) * (1 - t) end,
    easeInOut = function(t) return t * t * (3 - 2 * t) end,
    bounce = function(t)
        local n1 = 7.5625
        local d1 = 2.75
        if t < 1 / d1 then
            return n1 * t * t
        elseif t < 2 / d1 then
            t = t - 1.5 / d1
            return n1 * t * t + 0.75
        elseif t < 2.5 / d1 then
            t = t - 2.25 / d1
            return n1 * t * t + 0.9375
        else
            t = t - 2.625 / d1
            return n1 * t * t + 0.984375
        end
    end
}

-- Expose easeInOut for modules that need smooth interpolation
core.easeInOut = easeFunctions.easeInOut

local isShiftHeld = utils.isShiftHeld

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

---Snap a position to the nearest grid point.
---@param position number Position to snap
---@param windowName? string Window name for config lookup
---@return number snappedPosition
function core.snapToGrid(position, windowName)
    local gridSize = getGridSize(windowName)
    return math.floor(position / gridSize + 0.5) * gridSize
end

---Align a minimum constraint so snapToGrid always rounds into the valid range.
---@param value number Raw minimum constraint in pixels
---@param windowName? string Window name for grid config lookup
---@return number alignedMin
function core.gridAlignMin(value, windowName)
    local gridSize = getGridSize(windowName)
    local halfGrid = math.floor(gridSize / 2)
    return math.ceil(value / gridSize) * gridSize - halfGrid + 1
end

---Align a maximum constraint so snapToGrid always rounds into the valid range.
---@param value number Raw maximum constraint in pixels
---@param windowName? string Window name for grid config lookup
---@return number alignedMax
function core.gridAlignMax(value, windowName)
    local gridSize = getGridSize(windowName)
    local halfGrid = math.floor(gridSize / 2)
    return math.floor(value / gridSize) * gridSize + halfGrid - 1
end

---Grid-align all four constraints and apply them via ImGui.SetNextWindowSizeConstraints.
---@param minW number Raw minimum width in pixels
---@param minH number Raw minimum height in pixels
---@param maxW number Raw maximum width in pixels
---@param maxH number Raw maximum height in pixels
---@param windowName? string Window name for grid config lookup
function core.setNextWindowSizeConstraints(minW, minH, maxW, maxH, windowName)
    -- Bypass grid alignment during constraint animation for smooth interpolation
    if windowName and core.isConstraintAnimatingForWindow(windowName) then
        ImGui.SetNextWindowSizeConstraints(minW, minH, maxW, maxH)
    else
        ImGui.SetNextWindowSizeConstraints(
            core.gridAlignMin(minW, windowName),
            core.gridAlignMin(minH, windowName),
            core.gridAlignMax(maxW, windowName),
            core.gridAlignMax(maxH, windowName)
        )
    end
end

---Set grid-aligned window size constraints using display-percentage values.
---Converts percentages to pixels via GetDisplayResolution(), then grid-aligns.
---@param minWPct number Minimum width as display percentage (0-100)
---@param minHPct number Minimum height as display percentage (0-100)
---@param maxWPct number Maximum width as display percentage (0-100)
---@param maxHPct number Maximum height as display percentage (0-100)
---@param windowName? string Window name for grid config lookup
function core.setNextWindowSizeConstraintsPercent(minWPct, minHPct, maxWPct, maxHPct, windowName)
    local dw, dh = GetDisplayResolution()
    core.setNextWindowSizeConstraints(
        (dw / 100) * minWPct, (dh / 100) * minHPct,
        (dw / 100) * maxWPct, (dh / 100) * maxHPct,
        windowName
    )
end

---Linear interpolation between two values.
---@param a number Start value
---@param b number End value
---@param t number Interpolation factor (0-1)
---@return number interpolatedValue
function core.lerp(a, b, t)
    return a + (b - a) * t
end

---Apply easing function to interpolation factor.
---@param t number Interpolation factor (0-1)
---@param windowName? string Window name for config lookup
---@return number easedValue
function core.applyEasing(t, windowName)
    local funcName = settings.getConfig(windowName, "easeFunction")
    local func = easeFunctions[funcName] or easeFunctions.easeInOut
    return func(t)
end

---Apply easing function by name.
---@param t number Interpolation factor (0-1)
---@param name? string Easing function name (default: "easeInOut")
---@return number easedValue
function core.applyEasingByName(t, name)
    local func = easeFunctions[name] or easeFunctions.easeInOut
    return func(t)
end

--------------------------------------------------------------------------------
-- Internal State Management
--------------------------------------------------------------------------------

local function createBaseWindowState(windowName)
    return {
        animating = false,
        animationStartTime = 0,
        startPosX = 0,
        startPosY = 0,
        startSizeX = 0,
        startSizeY = 0,
        targetPosX = 0,
        targetPosY = 0,
        targetSizeX = 0,
        targetSizeY = 0,
        isDragging = false,
        expandedSizeX = windowCache[windowName] and windowCache[windowName].width or nil,
        expandedSizeY = windowCache[windowName] and windowCache[windowName].height or nil,
        wasCollapsed = false,
        pendingDragCheck = false,
        dragCheckPosX = 0,
        dragCheckPosY = 0,
        dragCheckSizeX = 0,
        dragCheckSizeY = 0,
    }
end

local function getWindowState(windowName)
    if not windowStates[windowName] then
        windowStates[windowName] = createBaseWindowState(windowName)
    end
    return windowStates[windowName]
end

local function handleSnap(state, currentPosX, currentPosY, sizeX, sizeY, windowName, skipSize)
    state.animating = false
    state.startPosX, state.startPosY = currentPosX, currentPosY
    state.targetPosX = core.snapToGrid(currentPosX, windowName)
    state.targetPosY = core.snapToGrid(currentPosY, windowName)

    if not skipSize then
        state.startSizeX, state.startSizeY = sizeX, sizeY
        state.targetSizeX = core.snapToGrid(sizeX, windowName)
        state.targetSizeY = core.snapToGrid(sizeY, windowName)
    else
        -- Collapsed: snap remembered expanded size so restore uses grid-aligned values
        state.startSizeX = state.expandedSizeX or sizeX
        state.startSizeY = state.expandedSizeY or sizeY
        state.targetSizeX = core.snapToGrid(state.startSizeX, windowName)
        state.targetSizeY = core.snapToGrid(state.startSizeY, windowName)
        state.expandedSizeX = state.targetSizeX
        state.expandedSizeY = state.targetSizeY
    end

    if not settings.getConfig(windowName, "animationEnabled") then
        ImGui.SetWindowPos(windowName, state.targetPosX, state.targetPosY)
        if not skipSize then
            ImGui.SetWindowSize(windowName, state.targetSizeX, state.targetSizeY)
        end
    end
end

local function calculateAnimationFrame(state, windowName, duration)
    local elapsedTime = os.clock() - state.animationStartTime
    local t = math.min(elapsedTime / duration, 1)
    t = core.applyEasing(t, windowName)

    local newPosX = core.lerp(state.startPosX, state.targetPosX, t)
    local newPosY = core.lerp(state.startPosY, state.targetPosY, t)

    local newSizeX, newSizeY
    if state.startSizeX and state.targetSizeX then
        newSizeX = core.lerp(state.startSizeX, state.targetSizeX, t)
        newSizeY = core.lerp(state.startSizeY, state.targetSizeY, t)
    end

    return t, newPosX, newPosY, newSizeX, newSizeY
end

local function animate(state, windowName, duration, isCollapsed)
    local t, newPosX, newPosY, newSizeX, newSizeY = calculateAnimationFrame(state, windowName, duration)

    ImGui.SetWindowPos(windowName, newPosX, newPosY)

    if not isCollapsed and newSizeX then
        ImGui.SetWindowSize(windowName, newSizeX, newSizeY)
    end

    if t >= 1 then
        state.animating = false
    end
end

--------------------------------------------------------------------------------
-- Shared Drag Detection
--------------------------------------------------------------------------------

-- Returns updatedPosX, updatedPosY, and action: nil | "changed" | "unchanged" | "focus_lost"
local function handleDragDetection(state, windowName, currentPosX, currentPosY, currentSizeX, currentSizeY, isFocused, isDragging, isReleased, shiftHeld, treatAllDrags)
    if isFocused and isDragging then
        -- Record baseline when any drag starts in focused window
        if not state.pendingDragCheck then
            state.pendingDragCheck = true
            state.dragCheckPosX = currentPosX
            state.dragCheckPosY = currentPosY
            state.dragCheckSizeX = currentSizeX
            state.dragCheckSizeY = currentSizeY
            dragStartPos.x = currentPosX
            dragStartPos.y = currentPosY
        end

        -- Check if window actually moved/resized (not a child element drag)
        local posChanged = currentPosX ~= state.dragCheckPosX or currentPosY ~= state.dragCheckPosY
        local sizeChanged = currentSizeX ~= state.dragCheckSizeX or currentSizeY ~= state.dragCheckSizeY

        if treatAllDrags or posChanged or sizeChanged then
            state.isDragging = true
            state.animating = false
            currentPosX, currentPosY = applyAxisLock(windowName, currentPosX, currentPosY, shiftHeld)
            updateDraggingBounds(windowName, currentPosX, currentPosY, currentSizeX, currentSizeY)
        end

        return currentPosX, currentPosY, nil

    elseif state.pendingDragCheck and isReleased then
        local posChanged = currentPosX ~= state.dragCheckPosX or currentPosY ~= state.dragCheckPosY
        local sizeChanged = currentSizeX ~= state.dragCheckSizeX or currentSizeY ~= state.dragCheckSizeY

        state.pendingDragCheck = false
        state.isDragging = false
        axisLock.active = false
        axisLock.axis = nil

        if posChanged or sizeChanged then
            return currentPosX, currentPosY, "changed"
        else
            return currentPosX, currentPosY, "unchanged"
        end

    elseif state.pendingDragCheck and not isFocused then
        -- Focus lost mid-drag - reset to prevent stuck state
        state.pendingDragCheck = false
        state.isDragging = false
        axisLock.active = false
        axisLock.axis = nil

        return currentPosX, currentPosY, "focus_lost"
    end

    return currentPosX, currentPosY, nil
end

--------------------------------------------------------------------------------
-- Shared Window Frame Processing
--------------------------------------------------------------------------------

--- Unified frame processing for internal windows, external windows, and
--- collapsed-window drag paths. Handles expanded size tracking, collapsed
--- restore, drag detection, snap calculation, animation setup, and cache
--- updates.
---
--- The canSetWindowPos/canSetWindowSize flags control whether ImGui calls
--- are made directly (internal windows inside their own scope) or deferred
--- via addDeferredSnap (external windows outside their Begin/End scope).
---
---@param p table Parameter table with fields:
---   windowName (string), state (table), currentPosX/Y (number),
---   currentSizeX/Y (number), isCollapsed (boolean), isFocused (boolean),
---   isDragging (boolean), isReleased (boolean), shiftHeld (boolean),
---   treatAllDrags (boolean), useGrid (boolean), useAnimation (boolean),
---   duration (number), snapCollapsed (boolean),
---   canSetWindowPos (boolean), canSetWindowSize (boolean)
---@return string|nil action Result: "snap_animated", "snap_immediate", "deferred_snap", "idle", or nil
local function processWindowFrame(p)
    local windowName = p.windowName
    local state = p.state
    local currentPosX = p.currentPosX
    local currentPosY = p.currentPosY
    local currentSizeX = p.currentSizeX
    local currentSizeY = p.currentSizeY
    local isCollapsed = p.isCollapsed
    local useGrid = p.useGrid
    local useAnimation = p.useAnimation
    local canSetWindowPos = p.canSetWindowPos
    local canSetWindowSize = p.canSetWindowSize

    -- 1. Track expanded size when not collapsed
    if not isCollapsed then
        state.expandedSizeX = currentSizeX
        state.expandedSizeY = currentSizeY
        local cached = windowCache[windowName]
        if not cached then
            windowCache[windowName] = { width = currentSizeX, height = currentSizeY }
        elseif cached.width ~= currentSizeX or cached.height ~= currentSizeY then
            cached.width = currentSizeX
            cached.height = currentSizeY
        end
    end

    -- 2. Restore size when expanding from collapsed
    if state.wasCollapsed and not isCollapsed then
        if state.expandedSizeX and state.expandedSizeY then
            if canSetWindowSize then
                ImGui.SetWindowSize(windowName, state.expandedSizeX, state.expandedSizeY)
            else
                addDeferredSnap(windowName, nil, nil, state.expandedSizeX, state.expandedSizeY)
            end
        end
        state.pendingDragCheck = false
    end
    state.wasCollapsed = isCollapsed

    -- Disable grid for collapsed windows when snapCollapsed is off
    if isCollapsed and not p.snapCollapsed then
        useGrid = false
    end

    -- 3. Run drag detection
    local action
    currentPosX, currentPosY, action = handleDragDetection(
        state, windowName, currentPosX, currentPosY, currentSizeX, currentSizeY,
        p.isFocused, p.isDragging, p.isReleased, p.shiftHeld, p.treatAllDrags
    )

    -- Early exit when idle (no drag action and no ongoing animation)
    if not action and not state.animating then
        return nil
    end

    -- Signal ongoing animation to caller even when no new drag action occurred
    if not action and state.animating then
        return "animating"
    end

    -- 4. On drag release with grid enabled: compute snap targets
    if action == "changed" and useGrid then
        -- Use expanded size for collapsed windows
        local sizeX = isCollapsed and (state.expandedSizeX or currentSizeX) or currentSizeX
        local sizeY = isCollapsed and (state.expandedSizeY or currentSizeY) or currentSizeY

        -- Compute snap targets for position
        local targetPosX = core.snapToGrid(currentPosX, windowName)
        local targetPosY = core.snapToGrid(currentPosY, windowName)

        -- Compute snap targets for size
        local targetSizeX, targetSizeY
        if not isCollapsed then
            targetSizeX = core.snapToGrid(sizeX, windowName)
            targetSizeY = core.snapToGrid(sizeY, windowName)
        else
            -- Collapsed: snap the remembered expanded size for correct restore
            targetSizeX = core.snapToGrid(state.expandedSizeX or sizeX, windowName)
            targetSizeY = core.snapToGrid(state.expandedSizeY or sizeY, windowName)
            state.expandedSizeX = targetSizeX
            state.expandedSizeY = targetSizeY
            local cached = windowCache[windowName]
            if cached then
                cached.width = targetSizeX
                cached.height = targetSizeY
            else
                windowCache[windowName] = { width = targetSizeX, height = targetSizeY }
            end
        end

        local snapPosChanged = targetPosX ~= currentPosX or targetPosY ~= currentPosY
        local snapSizeChanged = not isCollapsed and (targetSizeX ~= currentSizeX or targetSizeY ~= currentSizeY)

        if not snapPosChanged and not snapSizeChanged then
            return "idle"
        end

        -- 5. Set up animation or apply immediately
        if useAnimation then
            state.animating = true
            state.animationStartTime = os.clock()
            state.startPosX = currentPosX
            state.startPosY = currentPosY
            state.targetPosX = targetPosX
            state.targetPosY = targetPosY
            if not isCollapsed then
                state.startSizeX = currentSizeX
                state.startSizeY = currentSizeY
                state.targetSizeX = targetSizeX
                state.targetSizeY = targetSizeY
            else
                state.startSizeX = nil
                state.startSizeY = nil
                state.targetSizeX = nil
                state.targetSizeY = nil
            end
            return "snap_animated"
        else
            -- Apply immediately via direct calls or deferred snap
            if canSetWindowPos then
                ImGui.SetWindowPos(windowName, targetPosX, targetPosY)
            end
            if canSetWindowSize and not isCollapsed then
                ImGui.SetWindowSize(windowName, targetSizeX, targetSizeY)
            end
            if not canSetWindowPos or (not canSetWindowSize and not isCollapsed) then
                local deferPosX = not canSetWindowPos and targetPosX or nil
                local deferPosY = not canSetWindowPos and targetPosY or nil
                local deferSizeX = (not canSetWindowSize and not isCollapsed) and targetSizeX or nil
                local deferSizeY = (not canSetWindowSize and not isCollapsed) and targetSizeY or nil
                addDeferredSnap(windowName, deferPosX, deferPosY, deferSizeX, deferSizeY)
                return "deferred_snap"
            end
            return "snap_immediate"
        end
    end

    return action == "changed" and "idle" or nil
end

--------------------------------------------------------------------------------
-- Main API
--------------------------------------------------------------------------------

-- Reusable params table for core.update() to avoid per-frame allocation
local updateFrameParams = {
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
    canSetWindowPos = true,
    canSetWindowSize = true,
}

---Update window state (call once per frame inside window).
---@param windowName string Window title
---@param options? WindowUtilsUpdateOptions Override options
function core.update(windowName, options)
    options = options or {}

    -- Resolve settings with constraint animation bypass
    local constraintAnimActive = core.isConstraintAnimatingForWindow(windowName)

    local useGrid = options.gridEnabled
    if useGrid == nil then
        useGrid = settings.getConfig(windowName, "gridEnabled")
    end
    if constraintAnimActive then
        useGrid = false
    end

    local useAnimation = options.animationEnabled
    if useAnimation == nil then
        useAnimation = settings.getConfig(windowName, "animationEnabled")
    end
    if constraintAnimActive then
        useAnimation = false
    end

    local duration = options.animationDuration or settings.getConfig(windowName, "animationDuration")

    -- Build params from ImGui state
    local state = getWindowState(windowName)
    local isCollapsed = ImGui.IsWindowCollapsed()
    local currentPosX, currentPosY = ImGui.GetWindowPos()
    local currentSizeX, currentSizeY = ImGui.GetWindowSize()

    local p = updateFrameParams
    p.windowName = windowName
    p.state = state
    p.currentPosX = currentPosX
    p.currentPosY = currentPosY
    p.currentSizeX = currentSizeX
    p.currentSizeY = currentSizeY
    p.isCollapsed = isCollapsed
    p.isFocused = ImGui.IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)
    p.isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
    p.isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
    p.shiftHeld = isShiftHeld()
    p.treatAllDrags = options.treatAllDragsAsWindowDrag or false
    p.useGrid = useGrid
    p.useAnimation = useAnimation
    p.duration = duration
    p.snapCollapsed = settings.getConfig(windowName, "snapCollapsed")
    p.canSetWindowPos = true
    p.canSetWindowSize = true

    -- Delegate expanded tracking, collapsed restore, drag detection, snap, animation setup
    local result = processWindowFrame(p)

    -- Early exit: nothing to do if frame processing found no action,
    -- no constraint animation pending, and no snap-after-constraint pending
    if not result and not constraintAnimActive and not snapPendingByWindow[windowName] then
        return
    end

    -- After constraint animation completes, trigger grid snap (O(1) lookup via reverse index)
    if not constraintAnimActive then
        local pending = snapPendingByWindow[windowName]
        if pending then
            -- Re-resolve useGrid without constraint bypass for snap-after-constraint
            local snapGrid = options.gridEnabled
            if snapGrid == nil then
                snapGrid = settings.getConfig(windowName, "gridEnabled")
            end
            if isCollapsed and not p.snapCollapsed then
                snapGrid = false
            end

            for property in pairs(pending) do
                local cAnim = constraintAnimations[property]
                if cAnim and cAnim.snapPending then
                    cAnim.snapPending = false
                    if snapGrid then
                        local sizeX = isCollapsed and (state.expandedSizeX or currentSizeX) or currentSizeX
                        local sizeY = isCollapsed and (state.expandedSizeY or currentSizeY) or currentSizeY
                        handleSnap(state, currentPosX, currentPosY, sizeX, sizeY, windowName, isCollapsed)

                        local snapAnim = options.animationEnabled
                        if snapAnim == nil then
                            snapAnim = settings.getConfig(windowName, "animationEnabled")
                        end
                        if snapAnim then
                            state.animating = true
                            state.animationStartTime = os.clock()
                        end
                    end
                end
            end
            snapPendingByWindow[windowName] = nil
        end
    end

    if state.animating and not constraintAnimActive then
        local animEnabled = options.animationEnabled
        if animEnabled == nil then
            animEnabled = settings.getConfig(windowName, "animationEnabled")
        end
        if animEnabled then
            animate(state, windowName, duration, isCollapsed)
        end
    end
end

--------------------------------------------------------------------------------
-- State Query API
--------------------------------------------------------------------------------

---Check if a window is currently animating.
---@param windowName string Window title
---@return boolean isAnimating
function core.isAnimating(windowName)
    local state = windowStates[windowName]
    return state and state.animating or false
end

---Get the expanded (non-collapsed) size of a window.
---@param windowName string Window title
---@return number|nil width, number|nil height
function core.getExpandedSize(windowName)
    local state = windowStates[windowName]
    if state and state.expandedSizeX and state.expandedSizeY then
        return state.expandedSizeX, state.expandedSizeY
    end
    return nil, nil
end

---Immediately complete a window's animation.
---@param windowName string Window title
function core.completeAnimation(windowName)
    local state = windowStates[windowName]
    if state and state.animating then
        state.animating = false
        ImGui.SetWindowPos(windowName, state.targetPosX, state.targetPosY)
        if not ImGui.IsWindowCollapsed() then
            ImGui.SetWindowSize(windowName, state.targetSizeX, state.targetSizeY)
        end
    end
end

---Reset window state (clears tracking data).
---@param windowName string Window title
function core.resetWindow(windowName)
    windowStates[windowName] = nil
end

---Check if a specific window is being dragged.
---@param windowName string Window title
---@return boolean isDragging
function core.isWindowDragging(windowName)
    local state = windowStates[windowName]
    return state and state.isDragging or false
end

---Check if any tracked window is being dragged.
---@return boolean anyDragging
function core.isAnyWindowDragging()
    for _, state in pairs(windowStates) do
        if state.isDragging then
            return true
        end
    end
    return false
end

---Get the bounds of the currently dragging window.
---@return WindowUtilsWindowBounds|nil bounds
function core.getDraggingWindowBounds()
    if draggingWindowBoundsValid then
        return draggingWindowBounds
    end
    return nil
end

---Clear dragging window bounds (call when no window is dragging).
function core.clearDraggingWindowBounds()
    draggingWindowBoundsValid = false
    draggingWindowName = nil
end

---Get the name of the currently dragging window.
---@return string|nil windowName
function core.getDraggingWindowName()
    return draggingWindowName
end

---Get the effective grid size for the currently dragging window.
---@return number gridSize Grid size in pixels
function core.getDraggingWindowGridSize()
    return getGridSize(draggingWindowName)
end

---Check if axis lock is currently active (shift+drag).
---@return boolean active Whether axis lock is active
---@return string|nil axis The locked axis ("x" or "y") or nil
function core.isAxisLockActive()
    return axisLock.active, axisLock.axis
end


--------------------------------------------------------------------------------
-- Constraint Animation System
--------------------------------------------------------------------------------

local function getConstraintAnimation(property)
    if not constraintAnimations[property] then
        constraintAnimations[property] = {
            active = false,
            current = nil,
            target = nil,
            windowName = nil,
            startTime = nil,
            startValue = nil,
            duration = nil,
            easing = nil
        }
    end
    return constraintAnimations[property]
end

---Start a smooth constraint animation with time-based easing.
---Automatically calls CompleteAnimation for the associated window.
---@param windowName string Window name (for CompleteAnimation + grid bypass coordination)
---@param property string Constraint property key (e.g. "maxH")
---@param targetValue number Target value to animate to
---@param options? {duration?: number, easing?: string, initialValue?: number}
function core.startConstraintAnimation(windowName, property, targetValue, options)
    options = options or {}
    local anim = getConstraintAnimation(property)

    -- Auto-snap target to nearest grid line (property suffix "H" = height %, "W" = width %)
    local suffix = property:sub(-1):upper()
    if (suffix == "H" or suffix == "W") and settings.getConfig(windowName, "gridEnabled") then
        local dw, dh = GetDisplayResolution()
        local dim = (suffix == "H") and dh or dw
        local targetPx = (dim / 100) * targetValue
        targetValue = (core.snapToGrid(targetPx, windowName) / dim) * 100
    end

    if options.initialValue then
        anim.current = options.initialValue
    elseif anim.current == nil then
        anim.current = targetValue
    end

    -- Clean up old window entry if property is switching windows
    local oldWindow = anim.windowName
    if oldWindow and oldWindow ~= windowName then
        local old = constraintAnimByWindow[oldWindow]
        if old then
            old[property] = nil
            if not next(old) then constraintAnimByWindow[oldWindow] = nil end
        end
    end

    anim.active = true
    anim.target = targetValue
    anim.windowName = windowName
    anim.startTime = os.clock()
    anim.startValue = anim.current
    anim.duration = options.duration or 0.3
    anim.easing = options.easing or "easeOut"

    if not constraintAnimByWindow[windowName] then
        constraintAnimByWindow[windowName] = {}
    end
    constraintAnimByWindow[windowName][property] = true

    if windowName then
        core.completeAnimation(windowName)
    end
end

---Update constraint animation each frame. Returns the current interpolated value.
---@param property string Constraint property key
---@param normalValue number Value when not expanded
---@param expandedValue number Value when expanded
---@param isExpanded boolean Current expanded state (used for initial value if no animation started)
---@return number currentValue
function core.updateConstraintAnimation(property, normalValue, expandedValue, isExpanded)
    local anim = getConstraintAnimation(property)

    if anim.current == nil then
        anim.current = isExpanded and expandedValue or normalValue
        anim.target = anim.current
        anim.startValue = anim.current
    end

    if not anim.active then
        return anim.current
    end

    local elapsed = os.clock() - anim.startTime
    local t = math.min(elapsed / anim.duration, 1)
    t = core.applyEasingByName(t, anim.easing)

    anim.current = anim.startValue + (anim.target - anim.startValue) * t

    if t >= 1 then
        anim.current = anim.target
        anim.active = false
        anim.snapPending = true

        -- Move from active to snapPending reverse index
        if anim.windowName then
            local byWindow = constraintAnimByWindow[anim.windowName]
            if byWindow then
                byWindow[property] = nil
                if not next(byWindow) then constraintAnimByWindow[anim.windowName] = nil end
            end
            if not snapPendingByWindow[anim.windowName] then
                snapPendingByWindow[anim.windowName] = {}
            end
            snapPendingByWindow[anim.windowName][property] = true
        end
    end

    return anim.current
end

function core.isConstraintAnimating(property)
    local anim = constraintAnimations[property]
    return anim and anim.active or false
end

function core.isAnyConstraintAnimating()
    for _, anim in pairs(constraintAnimations) do
        if anim.active then
            return true
        end
    end
    return false
end

---Check if any constraint animation is active for a specific window (O(1) lookup).
---@param windowName string Window name to check
---@return boolean
function core.isConstraintAnimatingForWindow(windowName)
    local byWindow = constraintAnimByWindow[windowName]
    return byWindow ~= nil and next(byWindow) ~= nil
end

--------------------------------------------------------------------------------
-- External Window Management (Override All Windows)
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
function core.resolveHasCloseButton(windowName)
    return resolveHasCloseButton(windowName)
end

local function getExternalWindowState(windowName)
    if not externalWindowStates[windowName] then
        local state = createBaseWindowState(windowName)
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

-- Probe flags: prevent invisible probe from stealing focus or input
local PROBE_FLAGS = ImGuiWindowFlags.NoFocusOnAppearing
    + ImGuiWindowFlags.NoBringToFrontOnFocus
    + ImGuiWindowFlags.NoInputs
    + ImGuiWindowFlags.NoNav

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
    local t, newPosX, newPosY, newSizeX, newSizeY = calculateAnimationFrame(state, windowName, duration)

    addDeferredSnap(windowName, newPosX, newPosY, newSizeX, newSizeY)

    if t >= 1 then
        state.animating = false
    end
end

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
            state.isDragging = false
            draggingWindowBoundsValid = false
            draggingWindowName = nil
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
            addDeferredSnap(windowName, nil, nil, state.expandedSizeX, state.expandedSizeY)
            currentSizeX = state.expandedSizeX
            currentSizeY = state.expandedSizeY
        end
    end

    local isFocused = ImGui.IsWindowFocused()
    local wasDragging = state.isDragging or state.pendingDragCheck

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

    local result = processWindowFrame(p)

    -- Clear dragging bounds when drag ended without a snap animation
    if wasDragging and not state.isDragging and not state.pendingDragCheck and not state.animating then
        draggingWindowBoundsValid = false
        draggingWindowName = nil
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

function core.updateExternalWindows()
    -- Only process when master override is enabled
    if not settings.master.enabled or not settings.master.overrideAllWindows then
        return
    end

    if not discovery.isAvailable() then
        return
    end

    discovery.invalidateCache()
    local windows = discovery.getActiveWindows()

    local extVars, extColors = styles.PushExternalWindow(
        settings.master.overrideStyling,
        settings.master.disableScrollbar
    )

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
                        state.isDragging = false
                        draggingWindowBoundsValid = false
                        draggingWindowName = nil
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
                    draggingWindowBoundsValid = false
                    draggingWindowName = nil
                end
                externalWindowStates[windowName] = nil
            end
        end
    end

    styles.PopExternalWindow(extVars, extColors)

    -- Collapsed pOpen windows: core.update() can't detect drags for collapsed
    -- windows (CET's ImGui returns stale position and unfocused state).
    -- Use discovery data for real position and mouse state for drag detection.
    if settings.master.enabled and settings.master.gridEnabled
        and settings.master.snapCollapsed and discovery.isAvailable()
    then
        for windowName, state in pairs(windowStates) do
            if state.wasCollapsed then
                -- Look up real position from RedCetWM discovery
                local realPosX, realPosY
                for _, w in ipairs(windows) do
                    if w.name == windowName then
                        realPosX = w.posX
                        realPosY = w.posY
                        break
                    end
                end

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
                            updateDraggingBounds(windowName, realPosX, realPosY,
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

                        processWindowFrame(p)

                    elseif not isDragging then
                        state.collapsedTrackPosX = nil
                        state.collapsedTrackPosY = nil
                        if state.isDragging then
                            state.isDragging = false
                            draggingWindowBoundsValid = false
                            draggingWindowName = nil
                        end
                    end

                    -- Animate collapsed snap (position only, uses named API)
                    if state.animating and state.wasCollapsed then
                        if not settings.master.animationEnabled then
                            state.animating = false
                        else
                            local duration = settings.master.animationDuration or settings.defaults.animationDuration
                            local t, newPosX, newPosY = calculateAnimationFrame(state, windowName, duration)

                            addDeferredSnap(windowName, newPosX, newPosY, nil, nil)

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
    local now = os.clock()
    local deltaTime = lastFrameTime > 0 and (now - lastFrameTime) or 0
    lastFrameTime = now

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

function core.processDeferred()
    for i = 1, deferredSnapCount do
        local op = deferredSnapOperations[i]
        if op.targetPosX and op.targetPosY then
            ImGui.SetWindowPos(op.windowName, op.targetPosX, op.targetPosY)
        end
        if op.targetSizeX and op.targetSizeY then
            ImGui.SetWindowSize(op.windowName, op.targetSizeX, op.targetSizeY)
        end
    end
    deferredSnapCount = 0
end

function core.isDiscoveryAvailable()
    return discovery.isAvailable()
end

-- Reset all external probes (called on overlay open).
-- ACTIVE uses wasActive (flicker-free), BLOCKED uses standard probe.
function core.resetExternalProbes()
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
    lastFrameTime = 0
end

--- Check if any external window is being dragged.
function core.isAnyExternalWindowDragging()
    for _, state in pairs(externalWindowStates) do
        if state.isDragging then
            return true
        end
    end
    return false
end

--- Load cached external window expanded sizes from disk.
function core.loadWindowCache()
    local file = io.open(windowCachePath, "r")
    if not file then return end
    local content = file:read("*a")
    file:close()
    local success, data = pcall(json.decode, content)
    if success and data then
        windowCache = data
    end
end

function core.saveWindowCache()
    local success, content = pcall(json.encode, windowCache)
    if not success then return end
    local file = io.open(windowCachePath, "w")
    if not file then return end
    file:write(content)
    file:close()
end

--------------------------------------------------------------------------------
-- Snap All Windows
--------------------------------------------------------------------------------

--- Re-snap all active windows to the current grid.
function core.snapAllWindows()
    if not settings.master.overrideAllWindows then return end
    if not discovery.isAvailable() then return end

    local windows = discovery.getActiveWindows()
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
                    state.animationStartTime = os.clock()
                    state.startPosX = windowInfo.posX
                    state.startPosY = windowInfo.posY
                    state.targetPosX = targetX
                    state.targetPosY = targetY
                    state.startSizeX = windowInfo.sizeX
                    state.startSizeY = windowInfo.sizeY
                    state.targetSizeX = targetW
                    state.targetSizeY = targetH
                else
                    addDeferredSnap(name, targetX, targetY, targetW, targetH)
                end
            end
        end
    end
end

return core
