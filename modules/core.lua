------------------------------------------------------
-- WindowUtils - Core Module
-- Window state management, grid snapping, and animations
------------------------------------------------------

local settings = require("modules/settings")

local core = {}

-- Window state tracking
local windowStates = {}

-- Constraint animations
local constraintAnimations = {}

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

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Snap a position to the nearest grid point.
function core.snapToGrid(position, windowName)
    local gridUnits = settings.getConfig(windowName, "gridUnits")
    local gridSize = gridUnits * settings.GRID_UNIT_SIZE
    return math.floor(position / gridSize + 0.5) * gridSize
end

--- Linear interpolation between two values.
function core.lerp(a, b, t)
    return a + (b - a) * t
end

--- Apply easing function to interpolation factor.
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
            wasCollapsed = false
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

--- Update window state (call once per frame inside window).
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
        local isFocused = ImGui.IsWindowFocused()
        local isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
        local isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)

        if isFocused and isDragging then
            state.isDragging = true
        elseif state.isDragging and isReleased then
            state.isDragging = false
            local sizeX = isCollapsed and (state.expandedSizeX or currentSizeX) or currentSizeX
            local sizeY = isCollapsed and (state.expandedSizeY or currentSizeY) or currentSizeY
            handleSnap(state, currentPosX, currentPosY, sizeX, sizeY, windowName, isCollapsed)

            if useAnimation then
                state.animating = true
                state.animationStartTime = os.clock()
            end
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

function core.isAnimating(windowName)
    local state = windowStates[windowName]
    return state and state.animating or false
end

function core.getExpandedSize(windowName)
    local state = windowStates[windowName]
    if state and state.expandedSizeX and state.expandedSizeY then
        return state.expandedSizeX, state.expandedSizeY
    end
    return nil, nil
end

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

function core.resetWindow(windowName)
    windowStates[windowName] = nil
end

function core.isWindowDragging(windowName)
    local state = windowStates[windowName]
    return state and state.isDragging or false
end

function core.isAnyWindowDragging()
    for _, state in pairs(windowStates) do
        if state.isDragging then
            return true
        end
    end
    return false
end

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

return core
