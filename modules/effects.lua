------------------------------------------------------
-- WindowUtils - Effects Module
-- Blur, dim background, and grid visualization
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")

local effects = {}

-- Overlay state (set by init.lua event handlers)
effects.state = {
    isOverlayOpen = false,
    previewActive = false
}

-- Blur state management
effects.blur = {
    isActive = false,
    service = nil,
    originalEnabled = nil,
    originalRadius = 0.0,
    -- Animation state
    isAnimating = false,
    animationType = "none", -- "fade_in" or "fade_out"
    startTime = 0,
    currentRadius = 0.0,
    targetRadius = 0.0,
    -- Drag tracking
    wasDragging = false
}

-- Dim background fade state (shares fade durations with blur)
local dimFade = {
    opacity = 0,
    startTime = 0,
    wasDragging = false  -- tracks previous "should dim" state
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

--------------------------------------------------------------------------------
-- Blur Control
--------------------------------------------------------------------------------

--- Activate background blur with a fade-in animation.
function effects.enableBlur()
    if effects.blur.isActive and not effects.blur.isAnimating then return end

    local service = getBlurService()
    if not service then return end

    -- Store original settings (only if not already active)
    if not effects.blur.isActive then
        effects.blur.originalEnabled = service:GetEnable()
        effects.blur.originalRadius = service:GetBlurAreaCircularBlurRadius()
    end

    -- Enable service
    service:SetEnable(true)

    -- Start fade-in animation
    effects.blur.isAnimating = true
    effects.blur.animationType = "fade_in"
    effects.blur.startTime = os.clock()
    effects.blur.targetRadius = settings.master.blurIntensity
    -- Start from current radius (allows smooth transition if already animating)
    if not effects.blur.isActive then
        effects.blur.currentRadius = 0.0
    end

    effects.blur.isActive = true
end

--- Start a fade-out animation and deactivate background blur on completion.
function effects.disableBlur()
    if not effects.blur.isActive then return end

    -- Start fade-out animation
    effects.blur.isAnimating = true
    effects.blur.animationType = "fade_out"
    effects.blur.startTime = os.clock()
    -- targetRadius stays the same, we fade from currentRadius to 0
end

--- Advance the blur fade-in/fade-out animation by one tick. Call every frame.
function effects.updateBlurAnimation()
    if not effects.blur.isAnimating then return end

    local service = getBlurService()
    if not service then return end

    -- Use appropriate duration based on animation type
    local duration = effects.blur.animationType == "fade_in"
        and settings.master.blurFadeInDuration
        or settings.master.blurFadeOutDuration

    local elapsed = os.clock() - effects.blur.startTime
    local progress = math.min(elapsed / duration, 1.0)
    local easedProgress = easeInOut(progress)

    if effects.blur.animationType == "fade_in" then
        effects.blur.currentRadius = easedProgress * effects.blur.targetRadius
    else -- fade_out
        effects.blur.currentRadius = effects.blur.targetRadius * (1.0 - easedProgress)
    end

    -- Apply current blur radius
    service:SetBlurAreaCircularBlurRadius(effects.blur.currentRadius)

    -- Handle animation completion
    if progress >= 1.0 then
        effects.blur.isAnimating = false

        if effects.blur.animationType == "fade_out" then
            -- Cleanup after fade-out
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

    -- If not animating, apply immediately
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
    if not effects.state.isOverlayOpen then return end

    local isDragging = core.isAnyWindowDragging() or core.isAnyExternalWindowDragging()

    -- Detect drag state changes
    if isDragging and not effects.blur.wasDragging then
        -- Started dragging - enable blur
        effects.enableBlur()
    elseif not isDragging and effects.blur.wasDragging then
        -- Stopped dragging - disable blur
        effects.disableBlur()
    end

    effects.blur.wasDragging = isDragging
end

--------------------------------------------------------------------------------
-- Dim Control
--------------------------------------------------------------------------------

--- Reset the dim-background fade to fully transparent.
function effects.disableDim()
    dimFade.opacity = 0
    dimFade.wasDragging = false
    dimFade.startTime = 0
end

--------------------------------------------------------------------------------
-- Grid Visualization
--------------------------------------------------------------------------------

-- Grid fade state
local gridFade = {
    opacity = 0,           -- Current opacity multiplier (0 to 1)
    wasDragging = false,   -- Was dragging last frame
    fadeStartTime = 0,     -- When fade started
    wasFeathering = false, -- Was feathering active when drag ended
    lastBounds = nil,      -- Last window bounds (preserved for fade-out)
    lastGridSize = nil,    -- Last grid size (preserved for fade-out)
    lastWindowName = nil   -- Last window name (preserved for fade-out guides)
}

-- Hardcoded fade durations (in seconds)
local GRID_FADE_IN_DURATION = 0.15
local GRID_FADE_OUT_DURATION = 0.25

-- Distance from point to rectangle (0 if inside/within padding).
local function distanceToRect(px, py, rx, ry, rw, rh, padding)
    padding = padding or 0
    local left = rx - padding
    local right = rx + rw + padding
    local top = ry - padding
    local bottom = ry + rh + padding

    -- Check if point is inside padded rectangle
    if px >= left and px <= right and py >= top and py <= bottom then
        return 0
    end

    -- Calculate distance to nearest edge
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

local function drawGridVisualization()
    -- Early exit when both features are fully disabled
    if not settings.master.gridDimBackground and not settings.master.gridVisualizationEnabled then
        dimFade.opacity = 0
        dimFade.wasDragging = false
        gridFade.opacity = 0
        gridFade.wasDragging = false
        gridFade.wasFeathering = false
        gridFade.lastBounds = nil
        gridFade.lastGridSize = nil
        core.clearDraggingWindowBounds()
        return
    end

    local displayWidth, displayHeight = GetDisplayResolution()

    -- Only check drag state when a drag-only feature needs it (avoids O(n) window iteration)
    local anyDragging = false
    if (settings.master.gridDimBackground and settings.master.gridDimBackgroundOnDragOnly)
        or (settings.master.gridVisualizationEnabled and settings.master.gridEnabled and settings.master.gridShowOnDragOnly) then
        anyDragging = core.isAnyWindowDragging() or core.isAnyExternalWindowDragging()
    end
    local now = os.clock()

    -- Dim background (independent of grid viz)
    if settings.master.gridDimBackground then
        local shouldDim = not settings.master.gridDimBackgroundOnDragOnly or anyDragging

        -- Detect state changes for fade animation (including overlay open)
        if shouldDim and not dimFade.wasDragging then
            -- Start fade in (overlay just opened, or drag started in drag-only mode)
            dimFade.startTime = now
        elseif not shouldDim and dimFade.wasDragging then
            -- Start fade out (drag ended in drag-only mode)
            dimFade.startTime = now
        end
        dimFade.wasDragging = shouldDim

        -- Calculate current opacity with fade (using blur fade durations)
        local elapsed = now - dimFade.startTime
        if shouldDim then
            -- Fading in
            local fadeIn = settings.master.blurFadeInDuration
            local t = math.min(1, elapsed / fadeIn)
            dimFade.opacity = t * settings.master.gridDimBackgroundOpacity
        else
            -- Fading out
            local fadeOut = settings.master.blurFadeOutDuration
            local t = math.min(1, elapsed / fadeOut)
            dimFade.opacity = (1 - t) * settings.master.gridDimBackgroundOpacity
        end

        -- Draw if visible
        if dimFade.opacity > 0.001 then
            local drawList = ImGui.GetBackgroundDrawList()
            local bgColor = ImGui.GetColorU32(0, 0, 0, dimFade.opacity)
            ImGui.ImDrawListAddRectFilled(drawList, 0, 0, displayWidth, displayHeight, bgColor)
        end
    else
        -- Reset fade state when dim background is disabled
        dimFade.opacity = 0
        dimFade.wasDragging = false
    end

    -- Grid visualization works independently of master override
    if not settings.master.gridVisualizationEnabled then
        gridFade.opacity = 0
        gridFade.wasDragging = false
        gridFade.wasFeathering = false
        gridFade.lastBounds = nil
        gridFade.lastGridSize = nil
        core.clearDraggingWindowBounds()
        return
    end
    local featherEnabled = settings.master.gridFeatherEnabled
    local previewMode = not settings.master.gridEnabled

    -- Handle fade transitions
    if previewMode then
        -- Preview: fade based on slider interaction in Visuals tab
        local active = effects.state.previewActive
        if active and not gridFade.wasDragging then
            gridFade.fadeStartTime = now
        elseif not active and gridFade.wasDragging then
            gridFade.fadeStartTime = now
        end
        gridFade.wasDragging = active

        local elapsed = now - gridFade.fadeStartTime
        if active then
            gridFade.opacity = math.min(1, elapsed / GRID_FADE_IN_DURATION)
        else
            gridFade.opacity = math.max(0, 1 - (elapsed / GRID_FADE_OUT_DURATION))
        end

        if gridFade.opacity <= 0 then
            gridFade.lastBounds = nil
            gridFade.lastGridSize = nil
            gridFade.lastWindowName = nil
            gridFade.wasFeathering = false
            core.clearDraggingWindowBounds()
            return
        end
    elseif settings.master.gridShowOnDragOnly then
        -- Normal: fade based on window drag state
        if anyDragging and not gridFade.wasDragging then
            gridFade.fadeStartTime = now
            gridFade.wasFeathering = featherEnabled
        elseif not anyDragging and gridFade.wasDragging then
            gridFade.fadeStartTime = now
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

        local elapsed = now - gridFade.fadeStartTime
        if anyDragging then
            gridFade.opacity = math.min(1, elapsed / GRID_FADE_IN_DURATION)
        else
            gridFade.opacity = math.max(0, 1 - (elapsed / GRID_FADE_OUT_DURATION))
        end

        if gridFade.opacity <= 0 then
            gridFade.lastBounds = nil
            gridFade.lastGridSize = nil
            gridFade.lastWindowName = nil
            gridFade.wasFeathering = false
            core.clearDraggingWindowBounds()
            return
        end
    else
        -- Always fully visible
        gridFade.opacity = 1
        gridFade.wasDragging = false
        gridFade.wasFeathering = false
        gridFade.lastBounds = nil
        gridFade.lastGridSize = nil
        gridFade.lastWindowName = nil
    end

    -- Clear live bounds when not dragging (but preserve lastBounds for fade-out)
    if not anyDragging then
        core.clearDraggingWindowBounds()
    end

    -- Use dragging window's grid size, preserved size during fade-out, or master settings
    local gridSize = previewMode
        and (settings.master.gridUnits * settings.GRID_UNIT_SIZE)
        or (anyDragging and core.getDraggingWindowGridSize() or gridFade.lastGridSize or (settings.master.gridUnits * settings.GRID_UNIT_SIZE))
    local drawList = ImGui.GetBackgroundDrawList()
    local thickness = settings.master.gridLineThickness or settings.defaults.gridLineThickness
    local color = settings.master.gridLineColor or settings.defaults.gridLineColor
    if not color or not color[4] then return end  -- Safety check
    local baseAlpha = color[4] * gridFade.opacity

    -- Get feather settings
    local featherRadius = settings.master.gridFeatherRadius
    local featherPadding = settings.master.gridFeatherPadding
    local featherCurve = settings.master.gridFeatherCurve

    -- Use feathering if currently dragging with feather enabled, OR fading out with preserved bounds
    local useFeather = featherEnabled and (
        previewMode
        or (settings.master.gridShowOnDragOnly and (anyDragging or gridFade.wasFeathering))
    )

    -- Guides active when setting enabled, OR when axis lock (shift+drag) is active
    local axisLockActive = core.isAxisLockActive()
    local guidesActive = (previewMode and settings.master.gridGuidesEnabled)
        or (not previewMode and ((settings.master.gridShowOnDragOnly and settings.master.gridGuidesEnabled) or axisLockActive))

    -- Get window bounds (needed for feathering AND guides)
    local needBounds = useFeather or guidesActive
    local windowBounds = nil
    if needBounds then
        -- Use live bounds if dragging, otherwise use preserved bounds from fade-out
        windowBounds = anyDragging and core.getDraggingWindowBounds() or gridFade.lastBounds
    end

    -- If no bounds available but needed, fall back to mouse position
    if needBounds and not windowBounds then
        local mx, my = ImGui.GetMousePos()
        windowBounds = { x = mx - 100, y = my - 50, width = 200, height = 100 }
    end

    -- Apply grid dimming when guides are enabled
    local gridAlpha = baseAlpha
    if guidesActive then
        gridAlpha = baseAlpha * settings.master.gridGuidesDimming
    end

    -- Draw full grid lines (dimmed if guides enabled)
    -- Draw vertical lines (skip x=0 and x=displayWidth edges)
    local x = gridSize
    while x < displayWidth do
        if useFeather and windowBounds then
            -- Draw line in segments with varying opacity
            local y1 = 0
            while y1 < displayHeight do
                local y2 = math.min(y1 + gridSize, displayHeight)
                -- Use whichever segment endpoint is CLOSEST to the window
                local dist1 = distanceToRect(x, y1, windowBounds.x, windowBounds.y, windowBounds.width, windowBounds.height, featherPadding)
                local dist2 = distanceToRect(x, y2, windowBounds.x, windowBounds.y, windowBounds.width, windowBounds.height, featherPadding)
                local dist = math.min(dist1, dist2)
                local linearAlpha = math.max(0, 1 - (dist / featherRadius))
                local featherAlpha = math.pow(linearAlpha, featherCurve)
                local lineAlpha = gridAlpha * featherAlpha

                if lineAlpha > 0.001 then
                    local lineColor = ImGui.GetColorU32(color[1], color[2], color[3], lineAlpha)
                    ImGui.ImDrawListAddLine(drawList, x, y1, x, y2, lineColor, thickness)
                end
                y1 = y2
            end
        else
            local lineColor = ImGui.GetColorU32(color[1], color[2], color[3], gridAlpha)
            ImGui.ImDrawListAddLine(drawList, x, 0, x, displayHeight, lineColor, thickness)
        end
        x = x + gridSize
    end

    -- Draw horizontal lines (skip y=0 and y=displayHeight edges)
    local y = gridSize
    while y < displayHeight do
        if useFeather and windowBounds then
            -- Draw line in segments with varying opacity
            local x1 = 0
            while x1 < displayWidth do
                local x2 = math.min(x1 + gridSize, displayWidth)
                -- Use whichever segment endpoint is CLOSEST to the window
                local dist1 = distanceToRect(x1, y, windowBounds.x, windowBounds.y, windowBounds.width, windowBounds.height, featherPadding)
                local dist2 = distanceToRect(x2, y, windowBounds.x, windowBounds.y, windowBounds.width, windowBounds.height, featherPadding)
                local dist = math.min(dist1, dist2)
                local linearAlpha = math.max(0, 1 - (dist / featherRadius))
                local featherAlpha = math.pow(linearAlpha, featherCurve)
                local lineAlpha = gridAlpha * featherAlpha

                if lineAlpha > 0.001 then
                    local lineColor = ImGui.GetColorU32(color[1], color[2], color[3], lineAlpha)
                    ImGui.ImDrawListAddLine(drawList, x1, y, x2, y, lineColor, thickness)
                end
                x1 = x2
            end
        else
            local lineColor = ImGui.GetColorU32(color[1], color[2], color[3], gridAlpha)
            ImGui.ImDrawListAddLine(drawList, 0, y, displayWidth, y, lineColor, thickness)
        end
        y = y + gridSize
    end

    -- Draw alignment guides at window edges (full-width/height lines)
    if guidesActive and windowBounds then
        local guideColor = ImGui.GetColorU32(color[1], color[2], color[3], baseAlpha)

        -- Snap window bounds to grid for guide positions (use dragging window's grid size, or preserved during fade-out)
        local windowName = anyDragging and core.getDraggingWindowName() or gridFade.lastWindowName
        local leftEdge = core.snapToGrid(windowBounds.x, windowName)
        local rightEdge = core.snapToGrid(windowBounds.x + windowBounds.width, windowName)
        local topEdge = core.snapToGrid(windowBounds.y, windowName)
        local bottomEdge = core.snapToGrid(windowBounds.y + windowBounds.height, windowName)

        -- Vertical guides (left and right edges) - full height
        ImGui.ImDrawListAddLine(drawList, leftEdge, 0, leftEdge, displayHeight, guideColor, thickness)
        ImGui.ImDrawListAddLine(drawList, rightEdge, 0, rightEdge, displayHeight, guideColor, thickness)

        -- Horizontal guides (top and bottom edges) - full width
        ImGui.ImDrawListAddLine(drawList, 0, topEdge, displayWidth, topEdge, guideColor, thickness)
        ImGui.ImDrawListAddLine(drawList, 0, bottomEdge, displayWidth, bottomEdge, guideColor, thickness)
    end
end

--- Draw the grid overlay (full-screen background draw list). Call every frame when CET overlay is open.
function effects.drawGridOverlay()
    drawGridVisualization()
end

return effects
