------------------------------------------------------
-- WindowUtils.lua
-- This module provides quality of life features and tools for managing
-- window snapping and animation in GUI applications using ImGui.
--
-- Copyright (c) 2024 CyanideX
-- https://next.nexusmods.com/profile/theCyanideX/mods
------------------------------------------------------



local WindowUtils = {}

-- Hardcoded settings
local gridSize = 20  -- Size of the grid for snapping (60 is best for 4K resolution)

-- Tables to store the state of window animations and dragging
local animatingWindows = {}
local draggingWindows = {}

-- Initialize the animation state for a window
-- @param windowName - The name of the window
local function initializeWindowAnimation(windowName)
    animatingWindows[windowName] = {
        animating = false,
        animationStartTime = 0,
        startPosX = 0,
        startPosY = 0,
        startSizeX = 0,
        startSizeY = 0,
        targetPosX = 0,
        targetPosY = 0,
        targetSizeX = 0,
        targetSizeY = 0
    }
    draggingWindows[windowName] = false
end

-- Get the animation state of a window
-- @param windowName - The name of the window
-- @return The animation state of the window
local function getWindowAnimationState(windowName)
    if not animatingWindows[windowName] then
        initializeWindowAnimation(windowName)
    end
    return animatingWindows[windowName]
end

-- Get the dragging state of a window
-- @param windowName - The name of the window
-- @return The dragging state of the window
local function getDraggingState(windowName)
    if draggingWindows[windowName] == nil then
        initializeWindowAnimation(windowName)
    end
    return draggingWindows[windowName]
end

-- Snap a position to the nearest grid
-- @param position - The position to snap
-- @return The snapped position
function WindowUtils.SnapToGrid(position)
    return math.floor(position / gridSize + 0.5) * gridSize
end

-- Ease in-out function for smooth animation
-- @param t - The interpolation factor (0 to 1)
-- @return The eased value
function WindowUtils.EaseInOut(t)
    return t * t * (3 - 2 * t)
end

-- Linear interpolation function
-- @param a - The start value
-- @param b - The end value
-- @param t - The interpolation factor (0 to 1)
-- @return The interpolated value
function WindowUtils.Lerp(a, b, t)
    return a + (b - a) * t
end

-- Handle snapping a window to the grid
-- @param currentPosX - The current X position of the window
-- @param currentPosY - The current Y position of the window
-- @param currentSizeX - The current width of the window
-- @param currentSizeY - The current height of the window
-- @param windowName - The name of the window
function WindowUtils.HandleSnap(currentPosX, currentPosY, currentSizeX, currentSizeY, windowName)
    local animationState = getWindowAnimationState(windowName)
    
    animationState.animating = false
    animationState.startPosX, animationState.startPosY = currentPosX, currentPosY
    animationState.startSizeX, animationState.startSizeY = currentSizeX, currentSizeY
    animationState.targetPosX = WindowUtils.SnapToGrid(currentPosX)
    animationState.targetPosY = WindowUtils.SnapToGrid(currentPosY)
    animationState.targetSizeX = WindowUtils.SnapToGrid(currentSizeX)
    animationState.targetSizeY = WindowUtils.SnapToGrid(currentSizeY)

    ImGui.SetWindowPos(windowName, animationState.targetPosX, animationState.targetPosY)
    ImGui.SetWindowSize(windowName, animationState.targetSizeX, animationState.targetSizeY)
end

-- Animate a window to its target position and size
-- @param windowName - The name of the window
-- @param animationDuration - The duration of the animation in seconds
function WindowUtils.Animate(windowName, animationDuration)
    local animationState = getWindowAnimationState(windowName)
    
    local elapsedTime = os.clock() - animationState.animationStartTime
    local t = math.min(elapsedTime / animationDuration, 1)
    t = WindowUtils.EaseInOut(t)

    local newPosX = WindowUtils.Lerp(animationState.startPosX, animationState.targetPosX, t)
    local newPosY = WindowUtils.Lerp(animationState.startPosY, animationState.targetPosY, t)
    local newSizeX = WindowUtils.Lerp(animationState.startSizeX, animationState.targetSizeX, t)
    local newSizeY = WindowUtils.Lerp(animationState.startSizeY, animationState.targetSizeY, t)

    ImGui.SetWindowPos(windowName, newPosX, newPosY)
    ImGui.SetWindowSize(windowName, newSizeX, newSizeY)

    if t >= 1 then
        animationState.animating = false
    end
end

-- Update the state of a window
-- @param windowName - The name of the window
-- @param gridEnabled - Whether grid snapping is enabled
-- @param animationEnabled - Whether animation is enabled
-- @param animationDuration - The duration of the animation in seconds
function WindowUtils.UpdateWindow(windowName, gridEnabled, animationEnabled, animationDuration)
    local currentPosX, currentPosY = ImGui.GetWindowPos()
    local currentSizeX, currentSizeY = ImGui.GetWindowSize()

    if gridEnabled then
        local isFocused = ImGui.IsWindowFocused()
        local isDragging = ImGui.IsMouseDragging(ImGuiMouseButton.Left)
        local isReleased = ImGui.IsMouseReleased(ImGuiMouseButton.Left)
        local draggingState = getDraggingState(windowName)

        if isFocused and isDragging then
            draggingWindows[windowName] = true
        elseif draggingWindows[windowName] and isReleased then
            draggingWindows[windowName] = false
            WindowUtils.HandleSnap(currentPosX, currentPosY, currentSizeX, currentSizeY, windowName)
            if animationEnabled then
                local animationState = getWindowAnimationState(windowName)
                animationState.animating = true
                animationState.animationStartTime = os.clock()
            end
        end
    end

    if animationEnabled then
        local animationState = getWindowAnimationState(windowName)
        if animationState.animating then
            WindowUtils.Animate(windowName, animationDuration)
        end
    end
end

return WindowUtils
