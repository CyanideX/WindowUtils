------------------------------------------------------
-- WindowUtils - Core Module
-- Window state management, grid snapping, and animations
------------------------------------------------------

local settings = require("modules/settings")
local discovery = require("modules/discovery")
local utils = require("modules/utils")

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

-- Window state tracking
local windowStates = {}

-- Constraint animations
local constraintAnimations = {}
-- Reverse indices: windowName -> { property = true } for O(1) lookup
local constraintAnimByWindow = {}   -- active constraint animations by window
local snapPendingByWindow = {}      -- completed animations awaiting grid snap

-- External window state tracking (for Override All Windows feature)
local externalWindowStates = {}

-- Persistent cache for external window expanded sizes (survives game restart)
local windowCachePath = "data/window_cache.json"
local windowCache = {}

-- Deferred snap operations (executed at end of draw, table reused across frames)
local deferredSnapOperations = {}
local deferredSnapCount = 0

-- Currently dragging window bounds (reused table, updated in place)
local draggingWindowBounds = { x = 0, y = 0, width = 0, height = 0 }
local draggingWindowBoundsValid = false

-- Currently dragging window name (for dynamic grid visualization)
local draggingWindowName = nil

-- Axis lock state (for Shift+drag constraint)
local axisLock = {
    active = false,      -- Whether axis locking is currently active
    axis = nil,          -- "x" or "y" - which axis is locked (movement constrained to this axis)
    threshold = 10       -- Minimum movement before locking to an axis
}

-- Drag start position (recorded when drag begins, used for axis locking)
local dragStartPos = {
    x = 0,
    y = 0
}

-- Grid size cache (avoids recalculating every frame)
local gridSizeCache = {}

-- Exclusion set (hash table for fast lookup, rebuilt from settings.master.excludedWindows)
local excludedWindowSet = {}

-- Re-probe state
local blockedReprobeTimer = 0  -- Timer for batch BLOCKED re-probe
local activeReprobeTimer = 0   -- Timer for batch ACTIVE re-probe (auto-removal)
local activeReprobeIndex = 0   -- Round-robin index for sequential auto-remove
local lastFrameTime = 0

-- Offscreen position threshold (windows at 9000+ are hidden by other mods)
local OFFSCREEN_THRESHOLD = 9000
core.OFFSCREEN_THRESHOLD = OFFSCREEN_THRESHOLD

-- Core exclusion list: known CET/ImGui internal windows that should never be managed
local coreExcludedWindows = {
    ["Debug##Default"] = true,
}

--------------------------------------------------------------------------------
-- Drag Helper Functions
--------------------------------------------------------------------------------

-- Apply axis lock constraint during Shift+drag.
local function applyAxisLock(windowName, currentPosX, currentPosY, shiftHeld)
    if shiftHeld then
        axisLock.active = true

        -- Dynamically determine axis based on which direction has more movement
        local deltaX = math.abs(currentPosX - dragStartPos.x)
        local deltaY = math.abs(currentPosY - dragStartPos.y)
        if deltaX >= axisLock.threshold or deltaY >= axisLock.threshold then
            axisLock.axis = deltaX > deltaY and "x" or "y"
        end

        -- Apply axis constraint
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

-- Update dragging window bounds for grid visualization.
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

-- Get the effective grid size for a window (cached).
local function getGridSize(windowName)
    -- Use special key for nil/master
    local cacheKey = windowName or "__master__"

    if not gridSizeCache[cacheKey] then
        local gridUnits
        if windowName then
            gridUnits = settings.getConfig(windowName, "gridUnits")
        else
            gridUnits = settings.master.gridUnits
        end
        -- Validate gridUnits to prevent division by zero
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

function core.getEasingFunctions()
    return settings.easingKeys
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
        -- Collapsed window: snap the remembered expanded size for when it's restored
        state.startSizeX = state.expandedSizeX or sizeX
        state.startSizeY = state.expandedSizeY or sizeY
        state.targetSizeX = core.snapToGrid(state.startSizeX, windowName)
        state.targetSizeY = core.snapToGrid(state.startSizeY, windowName)
        -- Update expanded size to snapped values so restore uses grid-aligned size
        state.expandedSizeX = state.targetSizeX
        state.expandedSizeY = state.targetSizeY
    end

    -- Immediate snap if animation is disabled
    if not settings.getConfig(windowName, "animationEnabled") then
        ImGui.SetWindowPos(windowName, state.targetPosX, state.targetPosY)
        if not skipSize then
            ImGui.SetWindowSize(windowName, state.targetSizeX, state.targetSizeY)
        end
    end
end

-- Calculate interpolated animation values for the current frame.
-- Returns progress (0-1), new position, and optionally new size (nil for collapsed).
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

-- Shared drag detection state machine for internal and external windows.
-- Returns updatedPosX, updatedPosY, and an action string:
--   nil           = no state change (during drag or idle)
--   "changed"     = mouse released AND window pos/size changed from baseline
--   "unchanged"   = mouse released but pos/size didn't change (child element drag)
--   "focus_lost"  = focus was lost mid-drag
local function handleDragDetection(state, windowName, currentPosX, currentPosY, currentSizeX, currentSizeY, isFocused, isDragging, isReleased, shiftHeld, treatAllDrags)
    if isFocused and isDragging then
        -- Record baseline position/size when any drag starts in focused window
        if not state.pendingDragCheck then
            state.pendingDragCheck = true
            state.dragCheckPosX = currentPosX
            state.dragCheckPosY = currentPosY
            state.dragCheckSizeX = currentSizeX
            state.dragCheckSizeY = currentSizeY
            dragStartPos.x = currentPosX
            dragStartPos.y = currentPosY
        end

        -- Check if window is actually moving/resizing (not a child element drag)
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
        -- Focus lost mid-drag — reset drag state to prevent getting stuck
        state.pendingDragCheck = false
        state.isDragging = false
        axisLock.active = false
        axisLock.axis = nil

        return currentPosX, currentPosY, "focus_lost"
    end

    return currentPosX, currentPosY, nil
end

--------------------------------------------------------------------------------
-- Main API
--------------------------------------------------------------------------------

---Update window state (call once per frame inside window).
---@param windowName string Window title
---@param options? WindowUtilsUpdateOptions Override options
function core.update(windowName, options)
    options = options or {}

    -- Auto-disable grid and animation during constraint animation to prevent conflicts
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
    local treatAllDragsAsWindowDrag = options.treatAllDragsAsWindowDrag or false

    local state = getWindowState(windowName)
    local isCollapsed = ImGui.IsWindowCollapsed()

    local currentPosX, currentPosY = ImGui.GetWindowPos()
    local currentSizeX, currentSizeY = ImGui.GetWindowSize()

    -- Track expanded size when not collapsed
    if not isCollapsed then
        state.expandedSizeX = currentSizeX
        state.expandedSizeY = currentSizeY
        if not windowCache[windowName]
            or windowCache[windowName].width ~= currentSizeX
            or windowCache[windowName].height ~= currentSizeY
        then
            windowCache[windowName] = { width = currentSizeX, height = currentSizeY }
        end
    end

    -- Restore size when expanding from collapsed state
    if state.wasCollapsed and not isCollapsed then
        if state.expandedSizeX and state.expandedSizeY then
            ImGui.SetWindowSize(windowName, state.expandedSizeX, state.expandedSizeY)
        end
        -- Reset drag baseline so the next drag captures the new expanded size
        state.pendingDragCheck = false
    end
    state.wasCollapsed = isCollapsed

    -- Check if collapsed window snapping is enabled
    local snapCollapsed = settings.getConfig(windowName, "snapCollapsed")

    -- Skip grid snapping for collapsed windows if snapCollapsed is disabled
    if isCollapsed and not snapCollapsed then
        useGrid = false
    end

    if useGrid then
        -- Use RootAndChildWindows flag to detect focus even when child windows were last interacted with
        -- This ensures grid snapping works after interacting with child elements (splitters, panels, etc.)
        local isFocused = ImGui.IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)
        local isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
        local isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
        local shiftHeld = isShiftHeld()

        local action
        currentPosX, currentPosY, action = handleDragDetection(
            state, windowName, currentPosX, currentPosY, currentSizeX, currentSizeY,
            isFocused, isDragging, isReleased, shiftHeld, treatAllDragsAsWindowDrag
        )

        if action == "changed" then
            -- Was a window drag - trigger snap
            local sizeX = isCollapsed and (state.expandedSizeX or currentSizeX) or currentSizeX
            local sizeY = isCollapsed and (state.expandedSizeY or currentSizeY) or currentSizeY
            handleSnap(state, currentPosX, currentPosY, sizeX, sizeY, windowName, isCollapsed)

            if useAnimation then
                state.animating = true
                state.animationStartTime = os.clock()
            end
        end
        -- "unchanged": child element drag - do nothing
        -- "focus_lost": no additional cleanup needed for internal windows
    end

    -- After constraint animation completes, trigger a one-time grid snap
    -- so the window lands precisely on a grid line (O(1) lookup via reverse index)
    if not constraintAnimActive then
        local pending = snapPendingByWindow[windowName]
        if pending then
            for property in pairs(pending) do
                local cAnim = constraintAnimations[property]
                if cAnim and cAnim.snapPending then
                    cAnim.snapPending = false
                    if useGrid then
                        local sizeX = isCollapsed and (state.expandedSizeX or currentSizeX) or currentSizeX
                        local sizeY = isCollapsed and (state.expandedSizeY or currentSizeY) or currentSizeY
                        handleSnap(state, currentPosX, currentPosY, sizeX, sizeY, windowName, isCollapsed)
                        if useAnimation then
                            state.animating = true
                            state.animationStartTime = os.clock()
                        end
                    end
                end
            end
            snapPendingByWindow[windowName] = nil
        end
    end

    if useAnimation and state.animating then
        animate(state, windowName, duration, isCollapsed)
    end
end

function core.updateWindow(windowName, gridEnabled, animationEnabled, animationDuration)
    core.update(windowName, {
        gridEnabled = gridEnabled,
        animationEnabled = animationEnabled,
        animationDuration = animationDuration
    })
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

---Remove tracking for windows not in the active list.
---@param activeWindowNames string[] List of active window names
function core.cleanupUnusedWindows(activeWindowNames)
    local activeSet = {}
    for _, name in ipairs(activeWindowNames) do
        activeSet[name] = true
    end

    for windowName in pairs(windowStates) do
        if not activeSet[windowName] then
            windowStates[windowName] = nil
            settings.windowConfigs[windowName] = nil
        end
    end
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

    -- Auto-snap target to nearest grid line when target is a display percentage.
    -- Convention: property suffix "H" = height %, "W" = width %.
    local suffix = property:sub(-1):upper()
    if (suffix == "H" or suffix == "W") and settings.getConfig(windowName, "gridEnabled") then
        local dw, dh = GetDisplayResolution()
        local dim = (suffix == "H") and dh or dw
        local targetPx = (dim / 100) * targetValue
        targetValue = (core.snapToGrid(targetPx, windowName) / dim) * 100
    end

    -- Use current animated value or explicit initialValue as starting point
    if options.initialValue then
        anim.current = options.initialValue
    elseif anim.current == nil then
        anim.current = targetValue
    end

    -- Update reverse index: clean up old window entry if property is switching windows
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

    -- Add to reverse index
    if not constraintAnimByWindow[windowName] then
        constraintAnimByWindow[windowName] = {}
    end
    constraintAnimByWindow[windowName][property] = true

    -- Complete any running grid snap animation to prevent conflicts
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

        -- Remove from active reverse index, add to snapPending reverse index
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


-- Probe system for detecting windows not actively rendered by any mod.
-- Windows toggled off by their parent mod still exist in ImGui's layout data.
-- Calling ImGui.Begin() on them creates empty window frames.
--
-- Detection method: skip 1 frame (don't call Begin), then probe with Alpha=0
-- and check IsWindowAppearing(). If the window was NOT rendered by any mod
-- during the skip frame, IsWindowAppearing() returns true on the probe frame.
--
--   SKIP (0):    don't call Begin — lets window go inactive if no mod renders it
--   CHECK (1):   invisible probe (Alpha=0) — test IsWindowAppearing()
--   ACTIVE (2):  confirmed active — manage normally (drag/snap/animate)
--   BLOCKED (3): confirmed inactive — don't call Begin
local PROBE_SKIP = 0
local PROBE_CHECK = 1
local PROBE_ACTIVE = 2
local PROBE_BLOCKED = 3

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
        externalWindowStates[windowName] = state
    end
    return externalWindowStates[windowName]
end

function core.rebuildExclusionSet()
    excludedWindowSet = {}
    if settings.master.excludedWindows then
        for _, name in ipairs(settings.master.excludedWindows) do
            excludedWindowSet[name] = true
        end
    end
end

local function shouldManageWindow(windowName)
    -- Skip known CET/ImGui internal windows
    if coreExcludedWindows[windowName] then
        return false
    end
    -- Skip windows on the user exclusion list
    if excludedWindowSet[windowName] then
        return false
    end
    -- Skip windows already managed internally
    if windowStates[windowName] then
        return false
    end
    -- Respect WindowManager's hidden/locked state (CETWM is a global set by Window Manager)
    if type(CETWM) == "table" and type(CETWM.windows) == "table" then
        local wmState = CETWM.windows[windowName]
        if wmState then
            if not wmState.visible then return false end
            if wmState.locked then return false end
        end
    end
    return true
end

-- Probe flags: prevent invisible probe from stealing focus, Z-order, or input
local PROBE_FLAGS = ImGuiWindowFlags.NoFocusOnAppearing
    + ImGuiWindowFlags.NoBringToFrontOnFocus
    + ImGuiWindowFlags.NoInputs
    + ImGuiWindowFlags.NoNav

-- Invisible probe: Alpha=0 Begin, check IsWindowAppearing().
-- Returns true if active (another mod rendered it), false if inactive.
local function probeWindowActivity(windowName)
    ImGui.PushStyleVar(ImGuiStyleVar.Alpha, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    ImGui.Begin(windowName, true, PROBE_FLAGS)
    local active = not ImGui.IsWindowAppearing()
    ImGui.End()
    ImGui.PopStyleVar(2)
    return active
end

-- Manage a confirmed-active external window: drag detection, snap, animation.
local function manageExternalWindow(windowName, state)
    local usePOpen = settings.master.windowPOpen and settings.master.windowPOpen[windowName]
    local visible
    if usePOpen then
        local open
        visible, open = ImGui.Begin(windowName, true)
        if not open then
            -- User closed via X button — transition to blocked
            ImGui.End()
            state.probePhase = PROBE_BLOCKED
            state.blockedPosX = 0
            state.blockedPosY = 0
            state.blockedSizeX = 0
            state.blockedSizeY = 0
            state.isDragging = false
            state.pendingDragCheck = false

            return
        end
    else
        visible = ImGui.Begin(windowName)
    end
    -- NOTE: Don't return early when not visible (collapsed windows) — we still
    -- need drag detection, grid snapping, collapse tracking, and size restoration.
    -- All ImGui state queries work inside Begin/End regardless of collapse state.

    local isCollapsed = not visible
    local currentPosX, currentPosY = ImGui.GetWindowPos()

    -- Skip windows at extreme offscreen positions (likely hidden by another mod)
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

    -- Handle drag and snap (works for both collapsed and expanded windows)
    local currentSizeX, currentSizeY = ImGui.GetWindowSize()

    -- Restore size when expanding from collapsed state (before tracking, so we
    -- don't overwrite the stored expanded size with the current frame's value)
    if state.wasCollapsed and not isCollapsed then
        if state.expandedSizeX and state.expandedSizeY then
            ImGui.SetWindowSize(windowName, state.expandedSizeX, state.expandedSizeY)
            currentSizeX = state.expandedSizeX
            currentSizeY = state.expandedSizeY
        end
        -- Reset drag baseline so the next drag captures the new expanded size
        state.pendingDragCheck = false
    end
    state.wasCollapsed = isCollapsed

    -- Track expanded size when not collapsed
    if not isCollapsed then
        state.expandedSizeX = currentSizeX
        state.expandedSizeY = currentSizeY
        -- Update in-memory cache (saved to disk on overlay close)
        if not windowCache[windowName]
            or windowCache[windowName].width ~= currentSizeX
            or windowCache[windowName].height ~= currentSizeY
        then
            windowCache[windowName] = { width = currentSizeX, height = currentSizeY }
        end
    end

    local isFocused = ImGui.IsWindowFocused()
    local isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
    local isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
    local shiftHeld = isShiftHeld()

    local action
    currentPosX, currentPosY, action = handleDragDetection(
        state, windowName, currentPosX, currentPosY, currentSizeX, currentSizeY,
        isFocused, isDragging, isReleased, shiftHeld, false
    )

    if action == "unchanged" then
        -- Child element drag (slider, color picker, etc.) - clean up and return
        draggingWindowBoundsValid = false
        draggingWindowName = nil
        ImGui.End()
        return
    elseif action == "changed" then
        local gridEnabled = settings.master.gridEnabled
        local allowSnapCollapsed = settings.master.snapCollapsed

        if not gridEnabled or (isCollapsed and not allowSnapCollapsed) then
            draggingWindowBoundsValid = false
            draggingWindowName = nil
        else
            local targetX = core.snapToGrid(currentPosX, windowName)
            local targetY = core.snapToGrid(currentPosY, windowName)

            -- Only snap size for expanded windows (collapsed size is fixed to title bar)
            local targetSizeX = currentSizeX
            local targetSizeY = currentSizeY
            if not isCollapsed then
                targetSizeX = core.snapToGrid(currentSizeX, windowName)
                targetSizeY = core.snapToGrid(currentSizeY, windowName)
            end

            local snapPosChanged = targetX ~= currentPosX or targetY ~= currentPosY
            local snapSizeChanged = targetSizeX ~= currentSizeX or targetSizeY ~= currentSizeY

            if snapPosChanged or snapSizeChanged then
                if settings.master.animationEnabled then
                    state.animating = true
                    state.animationStartTime = os.clock()
                    state.startPosX = currentPosX
                    state.startPosY = currentPosY
                    state.targetPosX = targetX
                    state.targetPosY = targetY
                    -- Skip size targets for collapsed windows to preserve expanded size
                    state.startSizeX = isCollapsed and nil or currentSizeX
                    state.startSizeY = isCollapsed and nil or currentSizeY
                    state.targetSizeX = isCollapsed and nil or targetSizeX
                    state.targetSizeY = isCollapsed and nil or targetSizeY
                else
                    local op = {
                        windowName = windowName,
                        targetPosX = targetX,
                        targetPosY = targetY,
                    }
                    -- Skip size for collapsed windows to preserve expanded size
                    if not isCollapsed then
                        op.targetSizeX = targetSizeX
                        op.targetSizeY = targetSizeY
                    end
                    deferredSnapCount = deferredSnapCount + 1
                    deferredSnapOperations[deferredSnapCount] = op
                end
            end
        end
    elseif action == "focus_lost" then
        draggingWindowBoundsValid = false
        draggingWindowName = nil
    end

    -- Click-to-clean: when user focuses a window, trigger immediate re-probe
    -- to detect empty shells. Real windows seamlessly return to ACTIVE.
    if isFocused and not state.wasFocused then
        state.probePhase = PROBE_SKIP
        state.skipFrames = 1
        state.wasActive = true
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

    -- Check if discovery is available
    if not discovery.isAvailable() then
        return
    end

    -- Invalidate discovery cache so this frame gets fresh data
    discovery.invalidateCache()

    -- Get all active windows
    local windows = discovery.getActiveWindows()

    for _, windowInfo in ipairs(windows) do
        local windowName = windowInfo.name

        -- Skip offscreen and unmanageable windows
        if shouldManageWindow(windowName)
            and windowInfo.posX < OFFSCREEN_THRESHOLD
            and windowInfo.posY < OFFSCREEN_THRESHOLD
        then
            local state = getExternalWindowState(windowName)

            if state.probePhase == PROBE_SKIP then
                -- Don't call Begin — let window go inactive if no mod renders it.
                -- Wait 2 frames before probing for more reliable IsWindowAppearing().
                state.skipFrames = (state.skipFrames or 0) + 1
                if state.skipFrames >= 2 then
                    state.probePhase = PROBE_CHECK
                end

            elseif state.probePhase == PROBE_CHECK then
                -- Probe: check if another mod rendered last frame
                local active
                if state.wasActive then
                    -- Visible probe for previously-active windows (avoids Alpha=0 flicker)
                    ImGui.Begin(windowName)
                    active = not ImGui.IsWindowAppearing()
                    ImGui.End()
                    state.wasActive = false
                else
                    -- Invisible probe for previously-blocked (avoids ghost windows)
                    active = probeWindowActivity(windowName)
                end

                if active then
                    state.probePhase = PROBE_ACTIVE
                else
                    state.probePhase = PROBE_BLOCKED
                    state.animating = false
                    -- Store discovery snapshot for change tracking
                    state.blockedPosX = windowInfo.posX
                    state.blockedPosY = windowInfo.posY
                    state.blockedSizeX = windowInfo.sizeX
                    state.blockedSizeY = windowInfo.sizeY

                    -- Clean up drag state for blocked windows
                    if state.isDragging then
                        state.isDragging = false
                        draggingWindowBoundsValid = false
                        draggingWindowName = nil
                    end
                    state.pendingDragCheck = false
                    settings.debugPrint("Window no longer active: " .. windowName)
                end

            elseif state.probePhase == PROBE_ACTIVE then
                -- Confirmed active — manage normally
                manageExternalWindow(windowName, state)

                -- Handle animation (outside Begin/End)
                if state.animating then
                    if not settings.master.gridEnabled or not settings.master.animationEnabled then
                        state.animating = false
                    else
                        local duration = settings.master.animationDuration
                        local t, newPosX, newPosY, newSizeX, newSizeY = calculateAnimationFrame(state, windowName, duration)

                        local op = {
                            windowName = windowName,
                            targetPosX = newPosX,
                            targetPosY = newPosY,
                        }
                        if newSizeX then
                            op.targetSizeX = newSizeX
                            op.targetSizeY = newSizeY
                        end
                        deferredSnapCount = deferredSnapCount + 1
                        deferredSnapOperations[deferredSnapCount] = op

                        if t >= 1 then
                            state.animating = false
                        end
                    end
                end

            elseif state.probePhase == PROBE_BLOCKED then
                -- Discovery change tracking: detect if a mod started drawing this window
                -- by comparing current discovery data to the snapshot taken when blocked.
                local posChanged = windowInfo.posX ~= state.blockedPosX or windowInfo.posY ~= state.blockedPosY
                local sizeChanged = windowInfo.sizeX ~= state.blockedSizeX or windowInfo.sizeY ~= state.blockedSizeY
                if posChanged or sizeChanged then
                    state.probePhase = PROBE_SKIP
                    state.skipFrames = 0
                end

            end
        else
            -- Clean up stale external state for windows we're no longer managing
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

    -- Timekeeping (shared by re-probe timers below)
    local now = os.clock()
    local deltaTime = lastFrameTime > 0 and (now - lastFrameTime) or 0
    lastFrameTime = now

    local interval = settings.master.probeInterval or 0.5

    -- Batch re-probe of ALL BLOCKED windows every probeInterval.
    -- Safe: BLOCKED windows aren't rendered (no Begin() calls), so resetting
    -- them causes zero visual disruption. Detects newly-drawn windows within
    -- probeInterval + 3 frames regardless of blocked window count.
    blockedReprobeTimer = blockedReprobeTimer + deltaTime
    if blockedReprobeTimer >= interval then
        blockedReprobeTimer = blockedReprobeTimer - interval
        for _, state in pairs(externalWindowStates) do
            if state.probePhase == PROBE_BLOCKED then
                state.probePhase = PROBE_SKIP
                state.skipFrames = 0
            end
        end
    end

    -- Re-probe idle ACTIVE windows to detect empty shells.
    -- Busy windows (dragging, animating) are skipped.
    -- Batch mode checks all at once; sequential checks one per interval.
    if settings.master.autoRemoveEmptyWindows then
        local autoRemoveInterval = settings.master.autoRemoveInterval or 0.5
        activeReprobeTimer = activeReprobeTimer + deltaTime
        if activeReprobeTimer >= autoRemoveInterval then
            activeReprobeTimer = activeReprobeTimer - autoRemoveInterval

            if settings.master.batchAutoRemove ~= false then
                -- Batch: reset ALL idle ACTIVE windows at once
                for _, state in pairs(externalWindowStates) do
                    if state.probePhase == PROBE_ACTIVE
                        and not state.isDragging
                        and not state.animating
                        and not state.pendingDragCheck
                    then
                        state.probePhase = PROBE_SKIP
                        state.skipFrames = 1
                        state.wasActive = true
                        state.pendingDragCheck = false
                    end
                end
            else
                -- Sequential: reset one idle ACTIVE window per interval (round-robin)
                local candidates = {}
                for _, state in pairs(externalWindowStates) do
                    if state.probePhase == PROBE_ACTIVE
                        and not state.isDragging
                        and not state.animating
                        and not state.pendingDragCheck
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
                    state.pendingDragCheck = false
                end
            end
        end
    end
end

function core.processDeferred()
    for i = 1, deferredSnapCount do
        local op = deferredSnapOperations[i]
        ImGui.SetWindowPos(op.windowName, op.targetPosX, op.targetPosY)
        if op.targetSizeX and op.targetSizeY then
            ImGui.SetWindowSize(op.windowName, op.targetSizeX, op.targetSizeY)
        end
        deferredSnapOperations[i] = nil
    end
    deferredSnapCount = 0
end

function core.isDiscoveryAvailable()
    return discovery.isAvailable()
end

-- Reset all external probes (called on overlay open).
-- ACTIVE windows use wasActive (flicker-free), BLOCKED use standard probe.
-- Preserves drag state so grid visualization continues mid-drag.
function core.resetExternalProbes()
    for _, state in pairs(externalWindowStates) do
        if state.probePhase == PROBE_ACTIVE then
            state.probePhase = PROBE_SKIP
            state.skipFrames = 1   -- only 1 skip frame needed (was active last frame)
            state.wasActive = true
            -- Preserve isDragging and bounds across the probe cycle so grid
            -- visualization doesn't fall back to mouse position mid-drag.
            -- Only reset pendingDragCheck so a fresh baseline is recorded on resume.
            state.pendingDragCheck = false
        elseif state.probePhase == PROBE_BLOCKED then
            state.probePhase = PROBE_SKIP
            state.skipFrames = 0   -- 2 skip frames (standard)
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
-- Probe Constants & Browser API
--------------------------------------------------------------------------------

-- Expose probe phase constants for external modules (browser, API)
core.PROBE_SKIP = PROBE_SKIP
core.PROBE_CHECK = PROBE_CHECK
core.PROBE_ACTIVE = PROBE_ACTIVE
core.PROBE_BLOCKED = PROBE_BLOCKED

function core.getExternalWindowStates()
    local result = {}
    for name, state in pairs(externalWindowStates) do
        result[name] = {
            probePhase = state.probePhase,
            isDragging = state.isDragging,
            animating = state.animating,
        }
    end
    return result
end

function core.addExclusion(windowName)
    if not settings.master.excludedWindows then
        settings.master.excludedWindows = {}
    end
    for _, name in ipairs(settings.master.excludedWindows) do
        if name == windowName then return end
    end
    settings.master.excludedWindows[#settings.master.excludedWindows + 1] = windowName
    core.rebuildExclusionSet()
    settings.save()
end

function core.removeExclusion(windowName)
    if not settings.master.excludedWindows then return end
    for i, name in ipairs(settings.master.excludedWindows) do
        if name == windowName then
            table.remove(settings.master.excludedWindows, i)
            core.rebuildExclusionSet()
            settings.save()
            return
        end
    end
end

function core.setPOpen(windowName, value)
    if not settings.master.windowPOpen then
        settings.master.windowPOpen = {}
    end
    settings.master.windowPOpen[windowName] = value or nil
    settings.save()
end

return core
