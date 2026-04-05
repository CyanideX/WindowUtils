------------------------------------------------------
-- WindowUtils - Effects
-- Blur, dim background, and grid visualization
------------------------------------------------------

local settings = require("core/settings")
local core = require("core/core")
local controls = require("modules/controls")

local effects = {}

effects.state = {
    previewActive = false
}

-- Single source of truth for overlay open/closed state (set once in onInit)
local runtimeData = nil

function effects.setRuntimeData(rd)
    runtimeData = rd
end

local function isOverlayOpen()
    return runtimeData and runtimeData.cetOpen or false
end

function effects.isOverlayOpen()
    return isOverlayOpen()
end

effects.blur = {
    isActive = false,
    service = nil,
    originalEnabled = nil,
    originalRadius = 0.0,
    isAnimating = false,
    animationType = "none", -- "fade_in" or "fade_out"
    isOverlayClose = false,
    startTime = 0,
    currentRadius = 0.0,
    targetRadius = 0.0,
    wasDragging = false
}

-- Shares fade durations with blur
local dimFade = {
    opacity = 0,
    wasDragging = false,
    lastFrameTime = nil,
    overlayCloseFadeOut = false  -- true when fading out due to overlay close
}

local function getBlurService()
    if effects.blur.service then return effects.blur.service end

    local success, result = pcall(function()
        local container = Game.GetScriptableServiceContainer()
        if container then
            return container:GetService("CyanideX.BlurUtils.BlurUtils")
        end
        return nil
    end)

    if success and result then
        effects.blur.service = result
        return result
    end
    return nil
end

local easeInOut = core.easeInOut

--- Compute eased fade progress from a start time and duration.
--- Returns a raw 0-1 progress and its eased value. Shared by blur and
--- any other animation that needs timing + easing without state tracking.
---@param startTime number os.clock() timestamp when the animation began
---@param duration number seconds for the full transition
---@return number progress raw linear progress clamped to [0, 1]
---@return number easedProgress easeInOut-transformed progress
local function computeFadeProgress(startTime, duration)
    local elapsed = os.clock() - startTime
    local progress = math.min(elapsed / duration, 1.0)
    return progress, easeInOut(progress)
end

--- Compute fade opacity for a boolean active/inactive transition.
--- Tracks transition edges via fadeState and returns opacity in [0, 1].
---@param isActive boolean current active state
---@param fadeState table must have `wasActive` (boolean) and `startTime` (number) fields
---@param fadeInDuration number seconds for 0->1 fade
---@param fadeOutDuration number seconds for 1->0 fade
---@return number opacity in [0, 1]
local function computeFadeOpacity(isActive, fadeState, fadeInDuration, fadeOutDuration)
    local now = os.clock()
    if isActive and not fadeState.wasActive then
        fadeState.startTime = now
    elseif not isActive and fadeState.wasActive then
        fadeState.startTime = now
    end
    fadeState.wasActive = isActive

    local elapsed = now - fadeState.startTime
    if isActive then
        return math.min(1, elapsed / fadeInDuration)
    else
        return math.max(0, 1 - (elapsed / fadeOutDuration))
    end
end

--------------------------------------------------------------------------------
-- Blur Control
--------------------------------------------------------------------------------

--- Activate background blur with a fade-in animation.
function effects.enableBlur()
    if effects.blur.isActive and not effects.blur.isAnimating then return end

    local service = getBlurService()
    if not service then return end

    if not effects.blur.isActive then
        effects.blur.originalEnabled = service:GetEnable()
        effects.blur.originalRadius = service:GetBlurAreaCircularBlurRadius()
    end

    service:SetEnable(true)

    effects.blur.isAnimating = true
    effects.blur.animationType = "fade_in"
    effects.blur.startTime = os.clock()
    effects.blur.targetRadius = settings.master.blurIntensity
    -- Start from current radius for smooth transition if already animating
    if not effects.blur.isActive then
        effects.blur.currentRadius = 0.0
    end

    effects.blur.isActive = true
end

--- Start a fade-out animation and deactivate background blur on completion.
---@param isOverlayClose? boolean True when triggered by overlay close (uses quickExit timing)
function effects.disableBlur(isOverlayClose)
    if not effects.blur.isActive then return end

    -- If already fading out, just update the overlay-close flag (for quickExit timing)
    -- without restarting the animation from the beginning
    if effects.blur.isAnimating and effects.blur.animationType == "fade_out" then
        if isOverlayClose then
            effects.blur.isOverlayClose = true
        end
        return
    end

    effects.blur.isAnimating = true
    effects.blur.animationType = "fade_out"
    effects.blur.isOverlayClose = isOverlayClose or false
    effects.blur.startTime = os.clock()
end

--- Advance the blur fade-in/fade-out animation by one tick. Call every frame.
function effects.updateBlurAnimation()
    if not effects.blur.isAnimating then return end

    local service = getBlurService()
    if not service then return end

    local duration
    if effects.blur.animationType == "fade_in" then
        duration = settings.master.fadeInDuration
    elseif effects.blur.isOverlayClose and settings.master.quickExit then
        duration = 0.05
    else
        duration = settings.master.fadeOutDuration
    end

    local progress, easedProgress = computeFadeProgress(effects.blur.startTime, duration)

    if effects.blur.animationType == "fade_in" then
        effects.blur.currentRadius = easedProgress * effects.blur.targetRadius
    else -- fade_out
        effects.blur.currentRadius = effects.blur.targetRadius * (1.0 - easedProgress)
    end

    service:SetBlurAreaCircularBlurRadius(effects.blur.currentRadius)

    if progress >= 1.0 then
        effects.blur.isAnimating = false

        if effects.blur.animationType == "fade_out" then
            effects.blur.currentRadius = 0.0
            effects.blur.animationType = "none"
            service:SetBlurAreaCircularBlurRadius(0.0)
            service:SetEnable(false)
            effects.blur.isActive = false
            effects.blur.service = nil
        end
    end
end

--- Update the blur target radius, applying immediately when not animating.
---@param intensity number New blur radius value
function effects.updateBlurIntensity(intensity)
    if not effects.blur.isActive then return end

    effects.blur.targetRadius = intensity

    if not effects.blur.isAnimating then
        effects.blur.currentRadius = intensity
        local service = getBlurService()
        if service then
            service:SetBlurAreaCircularBlurRadius(intensity)
        end
    end
end

--- Check whether the BlurUtils service is installed and reachable.
---@return boolean
function effects.isBlurAvailable()
    return getBlurService() ~= nil
end

--- Enable/disable blur in response to drag state changes (drag-only mode). Call every frame.
function effects.updateBlurDragState()
    if not settings.master.blurOnOverlayOpen then return end
    if not settings.master.blurOnDragOnly then return end
    if not isOverlayOpen() then return end

    local isDragging = core.isAnyWindowDragging() or core.isAnyExternalWindowDragging()

    if isDragging and not effects.blur.wasDragging then
        effects.enableBlur()
    elseif not isDragging and effects.blur.wasDragging then
        effects.disableBlur()
    end

    effects.blur.wasDragging = isDragging
end

--------------------------------------------------------------------------------
-- Dim Control
--------------------------------------------------------------------------------

--- Signal that the overlay has closed. If quickExit is enabled, the fade-out
--- switches to the 0.05s hardcoded duration, overriding any in-progress drain.
function effects.disableDim()
    dimFade.overlayCloseFadeOut = true
    dimFade.wasDragging = false
end

--- Advance the dim fade-out after overlay closes. Call every frame.
--- Continues draining from the current opacity (no restart).
function effects.updateDimAnimation()
    if isOverlayOpen() then return end
    if dimFade.opacity <= 0 then return end

    local now = os.clock()
    local dt = dimFade.lastFrameTime and (now - dimFade.lastFrameTime) or 0
    dimFade.lastFrameTime = now
    if dt <= 0 then return end

    local fadeOutDuration = (dimFade.overlayCloseFadeOut and settings.master.quickExit)
        and 0.05 or settings.master.fadeOutDuration
    local maxOpacity = settings.master.gridDimBackgroundOpacity
    if fadeOutDuration <= 0 or maxOpacity <= 0 then
        dimFade.opacity = 0
        return
    end

    local step = maxOpacity * (dt / fadeOutDuration)
    dimFade.opacity = math.max(0, dimFade.opacity - step)

    if dimFade.opacity > 0.001 then
        local fc = controls.getFrameCache()
        local displayWidth, displayHeight = fc.displayWidth, fc.displayHeight
        local drawList = ImGui.GetBackgroundDrawList()
        local bgColor = ImGui.GetColorU32(0, 0, 0, dimFade.opacity)
        ImGui.ImDrawListAddRectFilled(drawList, 0, 0, displayWidth, displayHeight, bgColor)
    else
        dimFade.opacity = 0
    end
end

--------------------------------------------------------------------------------
-- Grid Visualization
--------------------------------------------------------------------------------

local gridFade = {
    opacity = 0,
    wasDragging = false,
    wasActive = false,    -- for computeFadeOpacity() transition tracking
    startTime = 0,
    fadeStartTime = 0,
    wasFeathering = false,
    lastBounds = nil,
    lastGridSize = nil,
    lastWindowName = nil
}

-- Hardcoded fade durations
local GRID_FADE_IN_DURATION = 0.15
local GRID_FADE_OUT_DURATION = 0.25

-- Distance from point to rectangle (0 if inside/within padding).
local function distanceToRect(px, py, rx, ry, rw, rh, padding)
    padding = padding or 0
    local left = rx - padding
    local right = rx + rw + padding
    local top = ry - padding
    local bottom = ry + rh + padding

    if px >= left and px <= right and py >= top and py <= bottom then
        return 0
    end

    local dx = 0
    local dy = 0

    if px < left then
        dx = left - px
    elseif px > right then
        dx = px - right
    end

    if py < top then
        dy = top - py
    elseif py > bottom then
        dy = py - bottom
    end

    return math.sqrt(dx * dx + dy * dy)
end

--- Draw grid lines along one axis with optional feathering.
---@param drawList userdata ImGui draw list
---@param isVert boolean true = vertical lines (iterate X, segments along Y)
---@param primaryEnd number extent of primary axis (displayWidth or displayHeight)
---@param secondaryEnd number extent of secondary axis
---@param gridSize number spacing between lines
---@param useFeather boolean whether feathering is active
---@param wb table|nil windowBounds {x,y,width,height}
---@param featherPadding number feather padding
---@param featherRadius number feather radius
---@param featherCurve number feather curve exponent
---@param gridAlpha number base line alpha
---@param color table {r,g,b} color components
---@param thickness number line thickness
local function drawGridLines(drawList, isVert, primaryEnd, secondaryEnd, gridSize, useFeather, wb, featherPadding, featherRadius, featherCurve, gridAlpha, color, thickness)
    local pos = gridSize
    while pos < primaryEnd do
        if useFeather and wb then
            local seg = 0
            while seg < secondaryEnd do
                local segEnd = math.min(seg + gridSize, secondaryEnd)
                local px1, py1, px2, py2
                if isVert then
                    px1, py1, px2, py2 = pos, seg, pos, segEnd
                else
                    px1, py1, px2, py2 = seg, pos, segEnd, pos
                end
                local dist1 = distanceToRect(px1, py1, wb.x, wb.y, wb.width, wb.height, featherPadding)
                local dist2 = distanceToRect(px2, py2, wb.x, wb.y, wb.width, wb.height, featherPadding)
                local dist = math.min(dist1, dist2)
                local linearAlpha = math.max(0, 1 - (dist / featherRadius))
                local featherAlpha = math.pow(linearAlpha, featherCurve)
                local lineAlpha = gridAlpha * featherAlpha

                if lineAlpha > 0.001 then
                    local lineColor = ImGui.GetColorU32(color[1], color[2], color[3], lineAlpha)
                    ImGui.ImDrawListAddLine(drawList, px1, py1, px2, py2, lineColor, thickness)
                end
                seg = segEnd
            end
        else
            local lineColor = ImGui.GetColorU32(color[1], color[2], color[3], gridAlpha)
            if isVert then
                ImGui.ImDrawListAddLine(drawList, pos, 0, pos, secondaryEnd, lineColor, thickness)
            else
                ImGui.ImDrawListAddLine(drawList, 0, pos, secondaryEnd, pos, lineColor, thickness)
            end
        end
        pos = pos + gridSize
    end
end

--- Render the dim background overlay with fade-in/fade-out.
--- Returns early when dim background is disabled in settings.
---@param displayWidth number screen width in pixels
---@param displayHeight number screen height in pixels
---@param anyDragging boolean true when any window is being dragged
local function updateDimOverlay(displayWidth, displayHeight, anyDragging)
    if not settings.master.gridDimBackground then
        dimFade.opacity = 0
        dimFade.wasDragging = false
        return
    end

    local shouldDim = not settings.master.gridDimBackgroundOnDragOnly or anyDragging
    local maxOpacity = settings.master.gridDimBackgroundOpacity

    -- Overlay is open, so clear the overlay-close flag and seed timing
    dimFade.overlayCloseFadeOut = false
    if not dimFade.lastFrameTime then
        dimFade.lastFrameTime = os.clock()
    end

    local now = os.clock()
    local dt = now - dimFade.lastFrameTime
    dimFade.lastFrameTime = now

    if dt > 0 and maxOpacity > 0 then
        if shouldDim then
            local fadeInDuration = settings.master.fadeInDuration
            if fadeInDuration <= 0 then
                dimFade.opacity = maxOpacity
            else
                local step = maxOpacity * (dt / fadeInDuration)
                dimFade.opacity = math.min(maxOpacity, dimFade.opacity + step)
            end
        else
            if dimFade.opacity > 0 then
                local fadeOutDuration = settings.master.fadeOutDuration
                if fadeOutDuration <= 0 then
                    dimFade.opacity = 0
                else
                    local step = maxOpacity * (dt / fadeOutDuration)
                    dimFade.opacity = math.max(0, dimFade.opacity - step)
                end
            end
        end
    end

    dimFade.wasDragging = shouldDim

    if dimFade.opacity > 0.001 then
        local drawList = ImGui.GetBackgroundDrawList()
        local bgColor = ImGui.GetColorU32(0, 0, 0, dimFade.opacity)
        ImGui.ImDrawListAddRectFilled(drawList, 0, 0, displayWidth, displayHeight, bgColor)
    end
end

--- Render grid lines, guides, feathering, and axis lock visualization.
--- Unifies the three grid fade branches (preview, drag-only, always-on) into
--- a single computeFadeOpacity() call.
---@param displayWidth number screen width in pixels
---@param displayHeight number screen height in pixels
---@param anyDragging boolean true when any window is being dragged
local function drawGrid(displayWidth, displayHeight, anyDragging)
    if not settings.master.gridVisualizationEnabled then
        gridFade.opacity = 0
        gridFade.wasDragging = false
        gridFade.wasActive = false
        gridFade.wasFeathering = false
        gridFade.lastBounds = nil
        gridFade.lastGridSize = nil
        gridFade.lastWindowName = nil
        core.clearDraggingWindowBounds()
        return
    end

    local featherEnabled = settings.master.gridFeatherEnabled
    local previewMode = not settings.master.gridEnabled

    -- Determine isActive based on mode
    local isActive
    if previewMode then
        isActive = effects.state.previewActive
    elseif settings.master.gridShowOnDragOnly then
        isActive = anyDragging
    else
        isActive = true
    end

    -- Capture fade-out state when drag-only mode transitions from dragging to not-dragging
    if settings.master.gridShowOnDragOnly and not previewMode then
        if anyDragging and not gridFade.wasDragging then
            gridFade.wasFeathering = featherEnabled
        elseif not anyDragging and gridFade.wasDragging then
            gridFade.lastGridSize = core.getDraggingWindowGridSize()
            gridFade.lastWindowName = core.getDraggingWindowName()
            if featherEnabled or (settings.master.gridShowOnDragOnly and settings.master.gridGuidesEnabled) then
                local bounds = core.getDraggingWindowBounds()
                if bounds then
                    gridFade.lastBounds = { x = bounds.x, y = bounds.y, width = bounds.width, height = bounds.height }
                end
                gridFade.wasFeathering = featherEnabled
            end
        end
        gridFade.wasDragging = anyDragging
    else
        gridFade.wasDragging = false
    end

    -- Unified fade calculation
    if isActive == true and not previewMode and not settings.master.gridShowOnDragOnly then
        -- Always-on mode: skip fade, full opacity
        gridFade.opacity = 1
        gridFade.wasActive = true
        gridFade.wasFeathering = false
        gridFade.lastBounds = nil
        gridFade.lastGridSize = nil
        gridFade.lastWindowName = nil
    else
        gridFade.opacity = computeFadeOpacity(
            isActive, gridFade,
            GRID_FADE_IN_DURATION, GRID_FADE_OUT_DURATION
        )
    end

    if gridFade.opacity <= 0 then
        gridFade.lastBounds = nil
        gridFade.lastGridSize = nil
        gridFade.lastWindowName = nil
        gridFade.wasFeathering = false
        core.clearDraggingWindowBounds()
        return
    end

    -- Preserve lastBounds for fade-out
    if not anyDragging then
        core.clearDraggingWindowBounds()
    end

    -- Grid size: dragging window's size, preserved size during fade-out, or master settings
    local gridSize = previewMode
        and (settings.master.gridUnits * settings.GRID_UNIT_SIZE)
        or (anyDragging and core.getDraggingWindowGridSize() or gridFade.lastGridSize or (settings.master.gridUnits * settings.GRID_UNIT_SIZE))
    local drawList = ImGui.GetBackgroundDrawList()
    local thickness = settings.master.gridLineThickness or settings.defaults.gridLineThickness
    local color = settings.master.gridLineColor or settings.defaults.gridLineColor
    if not color or not color[4] then return end
    local baseAlpha = color[4] * gridFade.opacity

    local featherRadius = settings.master.gridFeatherRadius
    local featherPadding = settings.master.gridFeatherPadding
    local featherCurve = settings.master.gridFeatherCurve

    local useFeather = featherEnabled and (
        previewMode
        or (settings.master.gridShowOnDragOnly and (anyDragging or gridFade.wasFeathering))
    )

    -- Guides: enabled in settings, or axis lock (shift+drag) is active
    local axisLockActive = core.isAxisLockActive()
    local guidesActive = (previewMode and settings.master.gridGuidesEnabled)
        or (not previewMode and ((settings.master.gridShowOnDragOnly and settings.master.gridGuidesEnabled) or axisLockActive))

    local needBounds = useFeather or guidesActive
    local windowBounds = nil
    if needBounds then
        windowBounds = anyDragging and core.getDraggingWindowBounds() or gridFade.lastBounds
    end

    -- Fall back to mouse position if no bounds available
    if needBounds and not windowBounds then
        local mx, my = ImGui.GetMousePos()
        windowBounds = { x = mx - 100, y = my - 50, width = 200, height = 100 }
    end

    -- Dim grid lines when guides are enabled
    local gridAlpha = baseAlpha
    if guidesActive then
        gridAlpha = baseAlpha * settings.master.gridGuidesDimming
    end

    drawGridLines(drawList, true, displayWidth, displayHeight, gridSize, useFeather, windowBounds, featherPadding, featherRadius, featherCurve, gridAlpha, color, thickness)
    drawGridLines(drawList, false, displayHeight, displayWidth, gridSize, useFeather, windowBounds, featherPadding, featherRadius, featherCurve, gridAlpha, color, thickness)

    -- Alignment guides at window edges
    if guidesActive and windowBounds then
        local guideColor = ImGui.GetColorU32(color[1], color[2], color[3], baseAlpha)

        -- Snap window bounds to grid for guide positions
        local windowName = anyDragging and core.getDraggingWindowName() or gridFade.lastWindowName
        local leftEdge = core.snapToGrid(windowBounds.x, windowName)
        local rightEdge = core.snapToGrid(windowBounds.x + windowBounds.width, windowName)
        local topEdge = core.snapToGrid(windowBounds.y, windowName)
        local bottomEdge = core.snapToGrid(windowBounds.y + windowBounds.height, windowName)

        ImGui.ImDrawListAddLine(drawList, leftEdge, 0, leftEdge, displayHeight, guideColor, thickness)
        ImGui.ImDrawListAddLine(drawList, rightEdge, 0, rightEdge, displayHeight, guideColor, thickness)

        ImGui.ImDrawListAddLine(drawList, 0, topEdge, displayWidth, topEdge, guideColor, thickness)
        ImGui.ImDrawListAddLine(drawList, 0, bottomEdge, displayWidth, bottomEdge, guideColor, thickness)
    end
end

--- Draw the grid overlay (full-screen background draw list). Call every frame when CET overlay is open.
function effects.drawGridOverlay()
    -- Early exit when both dim and grid are disabled
    if not settings.master.gridDimBackground and not settings.master.gridVisualizationEnabled then
        dimFade.opacity = 0
        dimFade.wasDragging = false
        dimFade.overlayCloseFadeOut = false
        gridFade.opacity = 0
        gridFade.wasDragging = false
        gridFade.wasActive = false
        gridFade.wasFeathering = false
        gridFade.lastBounds = nil
        gridFade.lastGridSize = nil
        gridFade.lastWindowName = nil
        core.clearDraggingWindowBounds()
        return
    end

    -- Compute shared state once
    local fc = controls.getFrameCache()
    local displayWidth, displayHeight = fc.displayWidth, fc.displayHeight

    local anyDragging = false
    if (settings.master.gridDimBackground and settings.master.gridDimBackgroundOnDragOnly)
        or (settings.master.gridVisualizationEnabled and settings.master.gridEnabled and settings.master.gridShowOnDragOnly) then
        anyDragging = core.isAnyWindowDragging() or core.isAnyExternalWindowDragging()
    end

    updateDimOverlay(displayWidth, displayHeight, anyDragging)
    drawGrid(displayWidth, displayHeight, anyDragging)
end

return effects
