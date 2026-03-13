------------------------------------------------------
-- WindowUtils - UI Module
-- Settings window and GUI components
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")
local controls = require("modules/controls")
local browser = require("modules/browser")

local ui = {}

-- GUI state
ui.state = {
    isOverlayOpen = false,
    showWindow = false
}

-- Blur state management
ui.blur = {
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
    if ui.blur.service then return ui.blur.service end

    local success, result = pcall(function()
        local container = Game.GetScriptableServiceContainer()
        if container then
            return container:GetService("CyanideX.BlurUtils.BlurUtils")
        end
        return nil
    end)

    if success and result then
        ui.blur.service = result
        return result
    end
    return nil
end

local function smoothEase(t)
    return t * t * (3 - 2 * t)
end

function ui.enableBlur()
    if ui.blur.isActive and not ui.blur.isAnimating then return end

    local service = getBlurService()
    if not service then return end

    -- Store original settings (only if not already active)
    if not ui.blur.isActive then
        ui.blur.originalEnabled = service:GetEnable()
        ui.blur.originalRadius = service:GetBlurAreaCircularBlurRadius()
    end

    -- Enable service
    service:SetEnable(true)

    -- Start fade-in animation
    ui.blur.isAnimating = true
    ui.blur.animationType = "fade_in"
    ui.blur.startTime = os.clock()
    ui.blur.targetRadius = settings.master.blurIntensity
    -- Start from current radius (allows smooth transition if already animating)
    if not ui.blur.isActive then
        ui.blur.currentRadius = 0.0
    end

    ui.blur.isActive = true
end

function ui.disableBlur()
    if not ui.blur.isActive then return end

    -- Start fade-out animation
    ui.blur.isAnimating = true
    ui.blur.animationType = "fade_out"
    ui.blur.startTime = os.clock()
    -- targetRadius stays the same, we fade from currentRadius to 0
end

function ui.updateBlurAnimation()
    if not ui.blur.isAnimating then return end

    local service = getBlurService()
    if not service then return end

    -- Use appropriate duration based on animation type
    local duration = ui.blur.animationType == "fade_in"
        and settings.master.blurFadeInDuration
        or settings.master.blurFadeOutDuration

    local elapsed = os.clock() - ui.blur.startTime
    local progress = math.min(elapsed / duration, 1.0)
    local easedProgress = smoothEase(progress)

    if ui.blur.animationType == "fade_in" then
        ui.blur.currentRadius = easedProgress * ui.blur.targetRadius
    else -- fade_out
        ui.blur.currentRadius = ui.blur.targetRadius * (1.0 - easedProgress)
    end

    -- Apply current blur radius
    service:SetBlurAreaCircularBlurRadius(ui.blur.currentRadius)

    -- Handle animation completion
    if progress >= 1.0 then
        ui.blur.isAnimating = false

        if ui.blur.animationType == "fade_out" then
            -- Cleanup after fade-out
            ui.blur.currentRadius = 0.0
            ui.blur.animationType = "none"
            service:SetBlurAreaCircularBlurRadius(0.0)
            service:SetEnable(false)
            ui.blur.isActive = false
            ui.blur.service = nil
        end
    end
end

function ui.updateBlurIntensity(intensity)
    if not ui.blur.isActive then return end

    ui.blur.targetRadius = intensity

    -- If not animating, apply immediately
    if not ui.blur.isAnimating then
        ui.blur.currentRadius = intensity
        local service = getBlurService()
        if service then
            service:SetBlurAreaCircularBlurRadius(intensity)
        end
    end
end

function ui.isBlurAvailable()
    return getBlurService() ~= nil
end

function ui.updateBlurDragState()
    if not settings.master.blurOnOverlayOpen then return end
    if not settings.master.blurOnDragOnly then return end
    if not ui.state.isOverlayOpen then return end

    local isDragging = core.isAnyWindowDragging() or core.isAnyExternalWindowDragging()

    -- Detect drag state changes
    if isDragging and not ui.blur.wasDragging then
        -- Started dragging - enable blur
        ui.enableBlur()
    elseif not isDragging and ui.blur.wasDragging then
        -- Stopped dragging - disable blur
        ui.disableBlur()
    end

    ui.blur.wasDragging = isDragging
end

function ui.init()
    ui.state.showWindow = settings.master.showSettingsWindow or false
end

function ui.disableDim()
    dimFade.opacity = 0
    dimFade.wasDragging = false
    dimFade.startTime = 0
end

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

local function findEasingIndex(key)
    for i, k in ipairs(settings.easingKeys) do
        if k == key then
            return i - 1  -- ImGui combo is 0-indexed
        end
    end
    return 3  -- default to easeInOut
end

--------------------------------------------------------------------------------
-- Grid Visualization
--------------------------------------------------------------------------------

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
    local anyDragging = core.isAnyWindowDragging() or core.isAnyExternalWindowDragging()
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
            local displayWidth, displayHeight = GetDisplayResolution()
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

    -- Handle fade transitions for "show on drag only" mode
    if settings.master.gridShowOnDragOnly then
        -- Detect drag state changes
        if anyDragging and not gridFade.wasDragging then
            -- Started dragging - begin fade in
            gridFade.fadeStartTime = now
            gridFade.wasFeathering = featherEnabled
        elseif not anyDragging and gridFade.wasDragging then
            -- Stopped dragging - begin fade out
            gridFade.fadeStartTime = now
            -- Preserve state for fade-out
            gridFade.lastGridSize = core.getDraggingWindowGridSize()
            gridFade.lastWindowName = core.getDraggingWindowName()
            -- Deep copy bounds (reused table would go stale)
            if featherEnabled or (settings.master.gridShowOnDragOnly and settings.master.gridGuidesEnabled) then
                local bounds = core.getDraggingWindowBounds()
                if bounds then
                    gridFade.lastBounds = { x = bounds.x, y = bounds.y, width = bounds.width, height = bounds.height }
                end
                gridFade.wasFeathering = featherEnabled
            end
        end
        gridFade.wasDragging = anyDragging

        -- Calculate current opacity based on fade state
        local elapsed = now - gridFade.fadeStartTime
        if anyDragging then
            -- Fading in or fully visible
            gridFade.opacity = math.min(1, elapsed / GRID_FADE_IN_DURATION)
        else
            -- Fading out or fully hidden
            gridFade.opacity = math.max(0, 1 - (elapsed / GRID_FADE_OUT_DURATION))
        end

        -- Skip drawing grid if fully faded out
        if gridFade.opacity <= 0 then
            -- Clear preserved state after fade-out completes
            gridFade.lastBounds = nil
            gridFade.lastGridSize = nil
            gridFade.lastWindowName = nil
            gridFade.wasFeathering = false
            core.clearDraggingWindowBounds()
            return
        end
    else
        -- Not in "show on drag only" mode - always fully visible
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
    local gridSize = anyDragging and core.getDraggingWindowGridSize() or gridFade.lastGridSize or (settings.master.gridUnits * settings.GRID_UNIT_SIZE)
    local drawList = ImGui.GetBackgroundDrawList()
    local displayWidth, displayHeight = GetDisplayResolution()
    local thickness = settings.master.gridLineThickness or settings.defaults.gridLineThickness
    local color = settings.master.gridLineColor or settings.defaults.gridLineColor
    if not color or not color[4] then return end  -- Safety check
    local baseAlpha = color[4] * gridFade.opacity

    -- Get feather settings
    local featherRadius = settings.master.gridFeatherRadius
    local featherPadding = settings.master.gridFeatherPadding
    local featherCurve = settings.master.gridFeatherCurve

    -- Use feathering if currently dragging with feather enabled, OR fading out with preserved bounds
    local useFeather = settings.master.gridShowOnDragOnly and featherEnabled and (anyDragging or gridFade.wasFeathering)

    -- Guides active when setting enabled, OR when axis lock (shift+drag) is active
    local axisLockActive = core.isAxisLockActive()
    local guidesActive = (settings.master.gridShowOnDragOnly and settings.master.gridGuidesEnabled) or axisLockActive

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

--------------------------------------------------------------------------------
-- Settings Window
--------------------------------------------------------------------------------

function ui.drawSettingsWindow()
    drawGridVisualization()

    if not ui.state.showWindow then return end

    ImGui.SetNextWindowSize(320, 280, ImGuiCond.FirstUseEver)
    -- No close button (use toggle/hotkey to hide), allow collapse
    if not ImGui.Begin(settings.NAME) then
        -- Window is collapsed - still update for grid snapping when dragging collapsed window
        core.update(settings.NAME, {
            gridEnabled = settings.master.gridEnabled,
            animationEnabled = settings.master.animationEnabled,
            animationDuration = settings.master.animationDuration,
            treatAllDragsAsWindowDrag = true
        })
        ImGui.End()
        return
    end

    local c = controls.bind(settings.master, settings.defaults, settings.save)

    -- Master override toggle
    local _, changed = c:Checkbox("Enable Master Override", "enabled")
    if changed then core.invalidateGridCache() end

    if settings.master.enabled then
        controls.TextSuccess("Master Settings Active - Overriding All mods")
    else
        controls.TextMuted("Master Settings Disabled - Mods Use Their Own Settings")
    end

    controls.SectionHeader("General", 10, 0)
    c:Checkbox("Show Tooltips", "tooltipsEnabled", { tooltip = "Show Tooltips on Hover", alwaysShowTooltip = true })

    ImGui.SameLine()
    _, changed = c:Checkbox("Debug Output", "debugOutput", { tooltip = "Print Debug Messages to Console", alwaysShowTooltip = true })
    if changed then settings.debugPrint("Debug Output Enabled") end

    -- Grid Visualization section (always enabled, independent of master override)
    controls.SectionHeader("Grid Visualization", 10, 0)
    c:Checkbox("Enable", "gridVisualizationEnabled", { tooltip = "Display Grid Lines on Screen" })

    -- Grid visualization sub-options (only when visualization enabled)
    if settings.master.gridVisualizationEnabled then
        ImGui.SameLine()
        c:Checkbox("On Drag Only ##grid", "gridShowOnDragOnly", { tooltip = "Only Show Grid While Dragging Windows" })

        if settings.master.gridShowOnDragOnly then
            ImGui.SameLine()
            c:Checkbox("Guides", "gridGuidesEnabled", { tooltip = "Highlight Alignment Lines at Window Edges\n(Dims full grid, shows full-brightness lines at snapped edges)\nCan be combined with Feathered Grid\n\nTip: Hold Shift while dragging to lock movement to one axis" })

            if settings.master.gridGuidesEnabled then
                -- Display as 0-100%, store as 0-1 (transformed — use raw API)
                local dimmingPercent = settings.master.gridGuidesDimming * 100
                local newDimmingPercent
                newDimmingPercent, changed = controls.SliderFloat("Brightness5", "gridDimming", dimmingPercent, 0, 100, { format = "%.0f%%", default = settings.defaults.gridGuidesDimming * 100, tooltip = "Grid Dimming (opacity of grid lines when guides active)" })
                if changed then
                    settings.master.gridGuidesDimming = newDimmingPercent / 100
                    settings.save()
                end
            end

            -- Grid feathering (only available when Show on Drag Only is enabled)
            c:Checkbox("Feathered Grid", "gridFeatherEnabled", { tooltip = "Show Grid Only Around Active Window" })

            if settings.master.gridFeatherEnabled then
                c:SliderFloat("BlurRadial", "gridFeatherRadius", 200, 1200, { format = "%.0f px", tooltip = "Feather Radius (distance where grid fades to zero)" })
                c:SliderFloat("SelectionEllipse", "gridFeatherPadding", 0, 120, { format = "%.0f px", tooltip = "Window Padding (area around window with full opacity)" })
                c:SliderFloat("ChartBellCurveCumulative", "gridFeatherCurve", 1.0, 12.0, { format = "%.1f", tooltip = "Feather Curve (higher = faster drop near window, gradual fade at edges)" })
            end
        end

        c:SliderFloat("FormatLineWeight", "gridLineThickness", 0.5, 5.0, { format = "%.1f px", tooltip = "Grid Line Thickness" })
        c:ColorEdit4("Palette", "gridLineColor", { tooltip = "Grid Line Color" })

    end

    -- Background section (independent of grid visualization)
    controls.SectionHeader("Background", 10, 0)

    c:Checkbox("Dim Background", "gridDimBackground", { tooltip = "Darken Screen When Grid Overlay Visible" })

    if settings.master.gridDimBackground then
        ImGui.SameLine()
        c:Checkbox("On Drag Only##dimBg", "gridDimBackgroundOnDragOnly", { tooltip = "Only Dim Background While Dragging Windows" })
        -- Display as 0-100%, store as 0-1 (transformed — use raw API)
        local opacityPercent = settings.master.gridDimBackgroundOpacity * 100
        local newOpacityPercent
        newOpacityPercent, changed = controls.SliderFloat("Brightness4", "dimOpacity", opacityPercent, 10, 90, { format = "%.0f%%", default = settings.defaults.gridDimBackgroundOpacity * 100, tooltip = "Background Dimming Opacity" })
        if changed then
            settings.master.gridDimBackgroundOpacity = newOpacityPercent / 100
            settings.save()
        end
    end

    -- Blur settings
    local blurAvailable = ui.isBlurAvailable()

    if not blurAvailable then
        ImGui.BeginDisabled()
    end

    -- Blur checkbox has complex side-effects — use raw API
    local blurValue = blurAvailable and settings.master.blurOnOverlayOpen or false
    blurValue, changed = controls.Checkbox("Blur on Overlay Open", blurValue, { default = settings.defaults.blurOnOverlayOpen, tooltip = blurAvailable and "Blur Game Background When CET Overlay Opens" or "Download the required library files" })
    if changed and blurAvailable then
        settings.master.blurOnOverlayOpen = blurValue
        settings.save()
        if settings.master.blurOnOverlayOpen and ui.state.isOverlayOpen and not settings.master.blurOnDragOnly then
            ui.enableBlur()
        elseif not settings.master.blurOnOverlayOpen then
            ui.disableBlur()
        end
    end

    if not blurAvailable then
        ImGui.EndDisabled()
        controls.TextWarning("XUtils Not Installed")
    end

    if settings.master.blurOnOverlayOpen and blurAvailable then
        ImGui.SameLine()
        -- Blur drag-only has complex side-effects — use raw API
        local newBlurDragOnly
        newBlurDragOnly, changed = controls.Checkbox("On Drag Only##blur", settings.master.blurOnDragOnly, { default = settings.defaults.blurOnDragOnly, tooltip = "Only Blur While Dragging Windows" })
        if changed then
            settings.master.blurOnDragOnly = newBlurDragOnly
            settings.save()
            if not settings.master.blurOnDragOnly and ui.state.isOverlayOpen then
                ui.enableBlur()
            elseif settings.master.blurOnDragOnly and not ui.blur.wasDragging then
                ui.disableBlur()
            end
        end

        _, changed = c:SliderFloat("Blur", "blurIntensity", 0.001, 0.02, { format = "%.4f", tooltip = "Blur Intensity" })
        if changed then ui.updateBlurIntensity(settings.master.blurIntensity) end

        c:SliderFloat("TransitionMasked", "blurFadeInDuration", 0.05, 1.0, { format = "%.2f s", tooltip = "Fade In Duration" })
        c:SliderFloat("TransitionMasked", "blurFadeOutDuration", 0.05, 1.0, { format = "%.2f s", tooltip = "Fade Out Duration" })
    end

    -- Master override dependent settings
    if not settings.master.enabled then
        ImGui.BeginDisabled()
    end

    -- Grid settings
    controls.SectionHeader("Grid Snapping", 10, 0)
    c:Checkbox("Enable Grid Snapping", "gridEnabled", { tooltip = "Snap Windows to Grid When Released" })

    if settings.master.gridEnabled then
        ImGui.SameLine()
        c:Checkbox("Snap Collapsed", "snapCollapsed", { tooltip = "Snap Collapsed Windows When Dragged" })

        -- Grid scale uses validUnits mapping — use raw API
        local validUnits = settings.getValidGridUnits(10)
        local maxScale = math.min(#validUnits, 5)
        local currentScale = 1
        local defaultScale = 1

        for i, units in ipairs(validUnits) do
            if i <= maxScale then
                if units == settings.master.gridUnits then
                    currentScale = i
                end
                if units == settings.defaults.gridUnits then
                    defaultScale = i
                end
            end
        end

        local gridSize = validUnits[currentScale] * settings.GRID_UNIT_SIZE
        local newScale
        newScale, changed = controls.SliderInt("Grid", "gridScale", currentScale, 1, maxScale, { format = "Scale %d (" .. gridSize .. "px)", default = defaultScale, tooltip = "Grid Scale (maps to valid grid sizes for your resolution)" })
        if changed then
            settings.master.gridUnits = validUnits[newScale]
            settings.save()
            core.invalidateGridCache()
        end
    end

    -- Animation settings (only meaningful when grid snapping is on)
    if settings.master.gridEnabled then
        controls.SectionHeader("Animation", 10, 0)
        c:Checkbox("Snap Animation", "animationEnabled", { tooltip = "Animate Window Snapping" })

        if settings.master.animationEnabled then
            c:SliderFloat("TimerOutline", "animationDuration", 0.05, 1.0, { format = "%.2f s", tooltip = "Animation Duration" })

            -- Easing uses index mapping — use raw API
            local currentIndex = findEasingIndex(settings.master.easeFunction)
            local defaultEasingIndex = findEasingIndex(settings.defaults.easeFunction)
            local newIndex
            newIndex, changed = controls.Combo("SineWave", "easing", currentIndex, settings.easingNames, { default = defaultEasingIndex, tooltip = "Easing Function" })
            if changed then
                settings.master.easeFunction = settings.easingKeys[newIndex + 1]
                settings.save()
            end
        end
    end

    -- Experimental settings
    controls.SectionHeader("Experimental", 10, 0)

    local discoveryAvailable = core.isDiscoveryAvailable()

    if discoveryAvailable then
        _, changed = c:Checkbox("Override All Windows", "overrideAllWindows", { tooltip = "Apply Grid Snapping to All CET Windows\n(Requires Window Manager's RedCetWM plugin)\n\nRespects Window Manager hidden/locked states.\nDoes not work with collapsed windows and may break the grid.\nMay conflict with windows using older versions of WindowUtils.", alwaysShowTooltip = true })
        if changed then core.invalidateGridCache() end
    else
        controls.TextWarning("RedCetWM plugin not found - Install Window Manager")
    end

    if settings.master.overrideAllWindows and discoveryAvailable then
        c:SliderFloat("TimerSand", "probeInterval", 0.1, 5.0, { format = "%.1f s", tooltip = "Re-Probe Interval\nHow often to scan for newly-drawn windows" })

        c:Checkbox("Auto-Remove Empty Windows", "autoRemoveEmptyWindows", { tooltip = "Automatically stop managing windows that are no longer drawn by any mod\nAlso removes empty shells instantly when clicked", alwaysShowTooltip = true })

        if settings.master.autoRemoveEmptyWindows then
            c:SliderFloat("TimerSand", "autoRemoveInterval", 0.1, 5.0, { format = "%.1f s", tooltip = "Auto-Remove Interval\nHow often to check for empty window shells\nLower = faster cleanup, slightly more processing" })

            c:Checkbox("Batch Auto-Remove", "batchAutoRemove", { tooltip = "Check all windows simultaneously each interval\nWhen off, checks one window per interval (round-robin)" })
        end

        if controls.Button("Window Browser", "inactive", ImGui.GetContentRegionAvail(), 0) then
            browser.toggle()
        end
    end

    if not settings.master.enabled then
        ImGui.EndDisabled()
    end

    -- Update with WindowUtils (for this window)
    -- treatAllDragsAsWindowDrag enables live grid preview when adjusting sliders
    core.update(settings.NAME, {
        gridEnabled = settings.master.gridEnabled,
        animationEnabled = settings.master.animationEnabled,
        animationDuration = settings.master.animationDuration,
        treatAllDragsAsWindowDrag = true
    })

    ImGui.End()
end

--------------------------------------------------------------------------------
-- Window Control API
--------------------------------------------------------------------------------

function ui.show()
    ui.state.showWindow = true
    settings.master.showSettingsWindow = true
    settings.save()
end

function ui.hide()
    ui.state.showWindow = false
    settings.master.showSettingsWindow = false
    settings.save()
end

function ui.toggle()
    ui.state.showWindow = not ui.state.showWindow
    settings.master.showSettingsWindow = ui.state.showWindow
    settings.save()
end

function ui.isVisible()
    return ui.state.showWindow
end

return ui
