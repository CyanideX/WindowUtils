------------------------------------------------------
-- WindowUtils - Core Module
-- Window state management, grid snapping, and animations
------------------------------------------------------

local settings = require("modules/settings")
local discovery = require("modules/discovery")

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

-- External window state tracking (for Override All Windows feature)
local externalWindowStates = {}

-- Deferred snap operations (executed at end of draw)
local deferredSnapOperations = {}

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

--------------------------------------------------------------------------------
-- Grid Size Caching
--------------------------------------------------------------------------------

--- Get the effective grid size for a window (cached).
-- @param windowName string|nil: Window name (nil uses master settings)
-- @return number: Grid size in pixels
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
        gridSizeCache[cacheKey] = gridUnits * settings.GRID_UNIT_SIZE
    end

    return gridSizeCache[cacheKey]
end

--- Invalidate grid size cache (call when settings change).
-- @param windowName string|nil: Window to invalidate, or nil to clear all
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

--- Check if Shift key is held.
local function isShiftHeld()
    return ImGui.IsKeyDown(ImGuiKey.LeftShift) or ImGui.IsKeyDown(ImGuiKey.RightShift)
end

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

--- Get available easing function names.
function core.getEasingFunctions()
    return settings.easingNames
end

--------------------------------------------------------------------------------
-- Internal State Management
--------------------------------------------------------------------------------

local function getWindowState(windowName)
    if not windowStates[windowName] then
        windowStates[windowName] = {
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
            expandedSizeX = nil,
            expandedSizeY = nil,
            wasCollapsed = false,
            -- Pending drag check (detects child element drags vs window drags)
            pendingDragCheck = false,
            dragCheckPosX = 0,
            dragCheckPosY = 0,
            dragCheckSizeX = 0,
            dragCheckSizeY = 0
        }
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
        state.startSizeX = state.expandedSizeX or sizeX
        state.startSizeY = state.expandedSizeY or sizeY
        state.targetSizeX = state.startSizeX
        state.targetSizeY = state.startSizeY
    end

    -- Immediate snap if animation is disabled
    if not settings.getConfig(windowName, "animationEnabled") then
        ImGui.SetWindowPos(windowName, state.targetPosX, state.targetPosY)
        if not skipSize then
            ImGui.SetWindowSize(windowName, state.targetSizeX, state.targetSizeY)
        end
    end
end

local function animate(state, windowName, duration, isCollapsed)
    local elapsedTime = os.clock() - state.animationStartTime
    local t = math.min(elapsedTime / duration, 1)
    t = core.applyEasing(t, windowName)

    local newPosX = core.lerp(state.startPosX, state.targetPosX, t)
    local newPosY = core.lerp(state.startPosY, state.targetPosY, t)

    ImGui.SetWindowPos(windowName, newPosX, newPosY)

    if not isCollapsed then
        local newSizeX = core.lerp(state.startSizeX, state.targetSizeX, t)
        local newSizeY = core.lerp(state.startSizeY, state.targetSizeY, t)
        ImGui.SetWindowSize(windowName, newSizeX, newSizeY)
    end

    if t >= 1 then
        state.animating = false
    end
end

--------------------------------------------------------------------------------
-- Main API
--------------------------------------------------------------------------------

---Update window state (call once per frame inside window).
---@param windowName string Window title
---@param options? WindowUtilsUpdateOptions Override options
function core.update(windowName, options)
    options = options or {}

    local useGrid = options.gridEnabled
    if useGrid == nil then
        useGrid = settings.getConfig(windowName, "gridEnabled")
    end

    local useAnimation = options.animationEnabled
    if useAnimation == nil then
        useAnimation = settings.getConfig(windowName, "animationEnabled")
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
    end

    -- Restore size when expanding from collapsed state
    if state.wasCollapsed and not isCollapsed then
        if state.expandedSizeX and state.expandedSizeY then
            ImGui.SetWindowSize(windowName, state.expandedSizeX, state.expandedSizeY)
        end
    end
    state.wasCollapsed = isCollapsed

    if useGrid then
        -- Use RootAndChildWindows flag to detect focus even when child windows were last interacted with
        -- This ensures grid snapping works after interacting with child elements (splitters, panels, etc.)
        local isFocused = ImGui.IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)
        local isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
        local isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
        local shiftHeld = isShiftHeld()

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
            -- treatAllDragsAsWindowDrag bypasses this check (for settings windows with live grid preview)
            local posChanged = currentPosX ~= state.dragCheckPosX or currentPosY ~= state.dragCheckPosY
            local sizeChanged = currentSizeX ~= state.dragCheckSizeX or currentSizeY ~= state.dragCheckSizeY

            if treatAllDragsAsWindowDrag or posChanged or sizeChanged then
                state.isDragging = true
                state.animating = false  -- Cancel any running animation

                -- Handle Shift+drag axis locking (uses original drag start position)
                if shiftHeld then
                    axisLock.active = true

                    -- Dynamically determine axis based on which direction has more movement
                    local deltaX = math.abs(currentPosX - dragStartPos.x)
                    local deltaY = math.abs(currentPosY - dragStartPos.y)
                    if deltaX >= axisLock.threshold or deltaY >= axisLock.threshold then
                        -- Continuously update axis based on dominant movement direction
                        axisLock.axis = deltaX > deltaY and "x" or "y"
                    end

                    -- Apply axis constraint (use explicit window name for reliability)
                    if axisLock.axis == "x" then
                        -- Lock Y to drag start position (allow only horizontal movement)
                        ImGui.SetWindowPos(windowName, currentPosX, dragStartPos.y)
                        currentPosY = dragStartPos.y
                    elseif axisLock.axis == "y" then
                        -- Lock X to drag start position (allow only vertical movement)
                        ImGui.SetWindowPos(windowName, dragStartPos.x, currentPosY)
                        currentPosX = dragStartPos.x
                    end
                else
                    -- Shift released - clear axis lock
                    axisLock.active = false
                    axisLock.axis = nil
                end

                -- Update live bounds in place for grid feathering
                draggingWindowBounds.x = currentPosX
                draggingWindowBounds.y = currentPosY
                draggingWindowBounds.width = currentSizeX
                draggingWindowBounds.height = currentSizeY
                draggingWindowBoundsValid = true
                draggingWindowName = windowName
            end
        elseif state.pendingDragCheck and isReleased then
            -- Mouse released - check if window position/size changed from baseline
            local posChanged = currentPosX ~= state.dragCheckPosX or currentPosY ~= state.dragCheckPosY
            local sizeChanged = currentSizeX ~= state.dragCheckSizeX or currentSizeY ~= state.dragCheckSizeY

            state.pendingDragCheck = false
            state.isDragging = false
            axisLock.active = false
            axisLock.axis = nil

            if posChanged or sizeChanged then
                -- Was a window drag - trigger snap
                local sizeX = isCollapsed and (state.expandedSizeX or currentSizeX) or currentSizeX
                local sizeY = isCollapsed and (state.expandedSizeY or currentSizeY) or currentSizeY
                handleSnap(state, currentPosX, currentPosY, sizeX, sizeY, windowName, isCollapsed)

                if useAnimation then
                    state.animating = true
                    state.animationStartTime = os.clock()
                end
            end
            -- else: was a child element drag (splitter, etc.) - do nothing
        end
    end

    if useAnimation and state.animating then
        animate(state, windowName, duration, isCollapsed)
    end
end

--- Legacy API for backward compatibility.
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
            lastTime = nil
        }
    end
    return constraintAnimations[property]
end

function core.startConstraintAnimation(property, targetValue, initialValue)
    local anim = getConstraintAnimation(property)
    anim.active = true
    anim.target = targetValue
    if anim.current == nil then
        anim.current = initialValue
    end
    anim.lastTime = os.clock()
end

function core.updateConstraintAnimation(property, normalValue, expandedValue, isExpanded, speed)
    speed = speed or 8.0
    local anim = getConstraintAnimation(property)

    if anim.current == nil then
        anim.current = isExpanded and expandedValue or normalValue
        anim.target = anim.current
    end

    if not anim.active then
        return anim.current
    end

    local now = os.clock()
    if anim.lastTime == nil then
        anim.lastTime = now
    end
    local delta = now - anim.lastTime
    anim.lastTime = now

    if anim.current ~= anim.target then
        local diff = anim.target - anim.current
        anim.current = anim.current + diff * speed * delta
        if math.abs(diff) < 0.1 then
            anim.current = anim.target
            anim.active = false
        end
    else
        anim.active = false
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

--------------------------------------------------------------------------------
-- External Window Management (Override All Windows)
--------------------------------------------------------------------------------

-- Windows to skip (managed internally or system windows)
local skipWindows = {
    ["WindowUtils Settings"] = true,
    ["Dear ImGui Demo"] = true,
    ["Dear ImGui Metrics/Debugger"] = true,
    ["About Dear ImGui"] = true,
    ["Dear ImGui Style Editor"] = true,
    ["Dear ImGui Debug Log"] = true,
    ["Dear ImGui ID Stack Tool"] = true,
    ["Settings"] = true,
    ["TweakDB Editor"] = true,
    ["Bindings"] = true,
    ["Game Log"] = true,
    ["Console"] = true,
    ["Crosshair"] = true
}

--- Get or create external window state.
local function getExternalWindowState(windowName)
    if not externalWindowStates[windowName] then
        externalWindowStates[windowName] = {
            isDragging = false,
            animating = false,
            animationStartTime = 0,
            startPosX = 0,
            startPosY = 0,
            targetPosX = 0,
            targetPosY = 0,
            startSizeX = 0,
            startSizeY = 0,
            targetSizeX = 0,
            targetSizeY = 0
        }
    end
    return externalWindowStates[windowName]
end

--- Check if a window should be managed externally.
local function shouldManageWindow(windowName)
    -- Skip windows with ## (ImGui hidden/ID windows)
    if windowName:find("##", 1, true) then
        return false
    end
    -- Skip our own windows and system windows
    if skipWindows[windowName] then
        return false
    end
    -- Skip windows already managed internally
    if windowStates[windowName] then
        return false
    end
    return true
end

--- Update all external windows (called every frame when override is enabled).
function core.updateExternalWindows()
    -- Only process when master override is enabled
    if not settings.master.enabled or not settings.master.overrideAllWindows then
        return
    end

    -- Check if discovery is available
    if not discovery.isAvailable() then
        return
    end

    -- Get all active windows
    local windows = discovery.getActiveWindows()

    for _, windowInfo in ipairs(windows) do
        local windowName = windowInfo.name

        -- Skip collapsed windows (they can't be dragged) and windows we shouldn't manage
        if not windowInfo.collapsed and shouldManageWindow(windowName) then
            local state = getExternalWindowState(windowName)

            -- Access the window to check its state
            if ImGui.Begin(windowName, true) then
                local currentPosX, currentPosY = ImGui.GetWindowPos()
                local currentSizeX, currentSizeY = ImGui.GetWindowSize()
                local isFocused = ImGui.IsWindowFocused()
                local isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
                local isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
                local shiftHeld = isShiftHeld()

                -- Track drag state
                if isFocused and isDragging then
                    -- Record drag start position when drag begins
                    if not state.isDragging then
                        dragStartPos.x = currentPosX
                        dragStartPos.y = currentPosY
                    end

                    state.isDragging = true
                    state.animating = false  -- Cancel any running animation

                    -- Handle Shift+drag axis locking (uses original drag start position)
                    if shiftHeld then
                        axisLock.active = true

                        -- Dynamically determine axis based on which direction has more movement
                        local deltaX = math.abs(currentPosX - dragStartPos.x)
                        local deltaY = math.abs(currentPosY - dragStartPos.y)
                        if deltaX >= axisLock.threshold or deltaY >= axisLock.threshold then
                            -- Continuously update axis based on dominant movement direction
                            axisLock.axis = deltaX > deltaY and "x" or "y"
                        end

                        -- Apply axis constraint (use explicit window name for reliability)
                        if axisLock.axis == "x" then
                            ImGui.SetWindowPos(windowName, currentPosX, dragStartPos.y)
                            currentPosY = dragStartPos.y
                        elseif axisLock.axis == "y" then
                            ImGui.SetWindowPos(windowName, dragStartPos.x, currentPosY)
                            currentPosX = dragStartPos.x
                        end
                    else
                        -- Shift released - clear axis lock
                        axisLock.active = false
                        axisLock.axis = nil
                    end

                    -- Update live bounds in place for grid feathering
                    draggingWindowBounds.x = currentPosX
                    draggingWindowBounds.y = currentPosY
                    draggingWindowBounds.width = currentSizeX
                    draggingWindowBounds.height = currentSizeY
                    draggingWindowBoundsValid = true
                    draggingWindowName = windowName
                elseif state.isDragging and isReleased then
                    state.isDragging = false
                    -- Clear axis lock on drag end
                    axisLock.active = false
                    axisLock.axis = nil

                    -- Queue snap operation for position and size
                    local targetX = core.snapToGrid(currentPosX, windowName)
                    local targetY = core.snapToGrid(currentPosY, windowName)
                    local targetSizeX = core.snapToGrid(currentSizeX, windowName)
                    local targetSizeY = core.snapToGrid(currentSizeY, windowName)

                    -- Check if position or size changed
                    local posChanged = targetX ~= currentPosX or targetY ~= currentPosY
                    local sizeChanged = targetSizeX ~= currentSizeX or targetSizeY ~= currentSizeY

                    if posChanged or sizeChanged then
                        if settings.master.animationEnabled then
                            state.animating = true
                            state.animationStartTime = os.clock()
                            state.startPosX = currentPosX
                            state.startPosY = currentPosY
                            state.targetPosX = targetX
                            state.targetPosY = targetY
                            state.startSizeX = currentSizeX
                            state.startSizeY = currentSizeY
                            state.targetSizeX = targetSizeX
                            state.targetSizeY = targetSizeY
                        else
                            -- Immediate snap
                            table.insert(deferredSnapOperations, {
                                windowName = windowName,
                                targetPosX = targetX,
                                targetPosY = targetY,
                                targetSizeX = targetSizeX,
                                targetSizeY = targetSizeY
                            })
                        end
                    end
                end

                ImGui.End()
            end

            -- Handle animation for this window
            if state.animating then
                local duration = settings.master.animationDuration
                local elapsedTime = os.clock() - state.animationStartTime
                local t = math.min(elapsedTime / duration, 1)
                t = core.applyEasing(t, windowName)

                local newPosX = core.lerp(state.startPosX, state.targetPosX, t)
                local newPosY = core.lerp(state.startPosY, state.targetPosY, t)
                local newSizeX = core.lerp(state.startSizeX, state.targetSizeX, t)
                local newSizeY = core.lerp(state.startSizeY, state.targetSizeY, t)

                -- Queue position and size update
                table.insert(deferredSnapOperations, {
                    windowName = windowName,
                    targetPosX = newPosX,
                    targetPosY = newPosY,
                    targetSizeX = newSizeX,
                    targetSizeY = newSizeY
                })

                if t >= 1 then
                    state.animating = false
                end
            end
        end
    end
end

--- Process deferred snap operations (called at end of draw loop).
function core.processDeferred()
    for _, op in ipairs(deferredSnapOperations) do
        if ImGui.Begin(op.windowName, true) then
            ImGui.SetWindowPos(op.targetPosX, op.targetPosY)
            if op.targetSizeX and op.targetSizeY then
                ImGui.SetWindowSize(op.targetSizeX, op.targetSizeY)
            end
            ImGui.End()
        end
    end

    -- Clear the queue
    deferredSnapOperations = {}
end

--- Check if discovery plugin is available.
function core.isDiscoveryAvailable()
    return discovery.isAvailable()
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

return core
