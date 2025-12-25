------------------------------------------------------
-- WindowUtils - UI Module
-- Settings window and GUI components
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")
local controls = require("modules/controls")

local ui = {}

-- GUI state
ui.state = {
    isOverlayOpen = false,
    showWindow = false
}

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

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function findEasingIndex(name)
    for i, n in ipairs(settings.easingNames) do
        if n == name then
            return i - 1  -- ImGui combo is 0-indexed
        end
    end
    return 3  -- default to easeInOut
end

--------------------------------------------------------------------------------
-- Grid Visualization
--------------------------------------------------------------------------------

--- Calculate distance from a point to a rectangle (0 if inside, positive if outside).
-- @param px, py: Point coordinates
-- @param rx, ry: Rectangle top-left corner
-- @param rw, rh: Rectangle width and height
-- @param padding: Extra padding around rectangle (points within padding have distance 0)
-- @return number: Distance to rectangle edge (0 if inside or within padding)
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

    local anyDragging = core.isAnyWindowDragging() or core.isAnyExternalWindowDragging()
    local now = os.clock()
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
            -- Preserve bounds, grid size, and window name for fade-out
            gridFade.lastGridSize = core.getDraggingWindowGridSize()
            gridFade.lastWindowName = core.getDraggingWindowName()
            -- Preserve bounds if feathering OR guides enabled (both need window position)
            if featherEnabled or (settings.master.gridShowOnDragOnly and settings.master.gridGuidesEnabled) then
                gridFade.lastBounds = core.getDraggingWindowBounds()
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

        -- Skip drawing if fully faded out
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
    local thickness = settings.master.gridLineThickness
    local color = settings.master.gridLineColor
    local baseAlpha = color[4] * gridFade.opacity

    -- Get feather settings
    local featherRadius = settings.master.gridFeatherRadius
    local featherPadding = settings.master.gridFeatherPadding
    local featherCurve = settings.master.gridFeatherCurve

    -- Use feathering if currently dragging with feather enabled, OR fading out with preserved bounds
    local useFeather = settings.master.gridShowOnDragOnly and featherEnabled and (anyDragging or gridFade.wasFeathering)

    -- Guides only work when Show on Drag Only is enabled
    local guidesActive = settings.master.gridShowOnDragOnly and settings.master.gridGuidesEnabled

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

    -- Segment size for feathered drawing (use grid size for efficiency)
    local segmentSize = gridSize

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
                local y2 = math.min(y1 + segmentSize, displayHeight)
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
                local x2 = math.min(x1 + segmentSize, displayWidth)
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
    -- Draw grid visualization (independent of window visibility)
    drawGridVisualization()

    if not ui.state.showWindow then return end

    ImGui.SetNextWindowSize(320, 280, ImGuiCond.FirstUseEver)
    ui.state.showWindow = ImGui.Begin("WindowUtils Settings", ui.state.showWindow, ImGuiWindowFlags.NoCollapse)

    if ui.state.showWindow then
        -- Master override toggle
        local changed
        settings.master.enabled, changed = controls.Checkbox("Enable Master Override", settings.master.enabled)
        if changed then
            settings.save()
            core.invalidateGridCache()  -- Clear cached grid sizes when override changes
        end

        if settings.master.enabled then
            controls.TextSuccess("Master settings active - overriding all mods")
        else
            controls.TextMuted("Master settings disabled - mods use their own")
        end

        -- Grid Visualization section (always enabled, independent of master override)
        controls.SectionHeader("Grid Visualization", 10, 0)
        settings.master.gridVisualizationEnabled, changed = controls.Checkbox("Show Grid Overlay", settings.master.gridVisualizationEnabled, settings.defaults.gridVisualizationEnabled, "Display Grid Lines on Screen")
        if changed then settings.save() end

        -- Grid visualization sub-options (only when visualization enabled)
        if settings.master.gridVisualizationEnabled then
            ImGui.SameLine()
            settings.master.gridShowOnDragOnly, changed = controls.Checkbox("Show on Drag Only", settings.master.gridShowOnDragOnly, settings.defaults.gridShowOnDragOnly, "Only Show Grid While Dragging Windows")
            if changed then settings.save() end

            if settings.master.gridShowOnDragOnly then
                ImGui.SameLine()
                settings.master.gridGuidesEnabled, changed = controls.Checkbox("Guides", settings.master.gridGuidesEnabled, settings.defaults.gridGuidesEnabled, "Highlight Alignment Lines at Window Edges\n(Dims full grid, shows full-brightness lines at snapped edges)\nCan be combined with Feathered Grid")
                if changed then settings.save() end
            end

            -- Grid dimming slider (only when guides enabled)
            if settings.master.gridGuidesEnabled then
                -- Display as 0-100%, store as 0-1
                local dimmingPercent = settings.master.gridGuidesDimming * 100
                local newDimmingPercent
                newDimmingPercent, changed = controls.SliderFloat(IconGlyphs.Brightness5, "gridDimming", dimmingPercent, 0, 100, "%.0f%%", nil, settings.defaults.gridGuidesDimming * 100, "Grid Dimming (opacity of grid lines when guides active)")
                if changed then
                    settings.master.gridGuidesDimming = newDimmingPercent / 100
                    settings.save()
                end
            end

            local thickness = settings.master.gridLineThickness
            thickness, changed = controls.SliderFloat(IconGlyphs.FormatLineWeight, "gridThickness", thickness, 0.5, 5.0, "%.1f px", nil, settings.defaults.gridLineThickness, "Grid Line Thickness")
            if changed then
                settings.master.gridLineThickness = thickness
                settings.save()
            end

            -- RGBA color picker
            settings.master.gridLineColor, changed = controls.ColorEdit4(IconGlyphs.Palette, "gridColor", settings.master.gridLineColor, nil, settings.defaults.gridLineColor, "Grid Line Color")
            if changed then
                settings.save()
            end

            -- Grid feathering (only available when Show on Drag Only is enabled)
            if settings.master.gridShowOnDragOnly then
                settings.master.gridFeatherEnabled, changed = controls.Checkbox("Feathered Grid", settings.master.gridFeatherEnabled, settings.defaults.gridFeatherEnabled, "Show Grid Only Around Active Window")
                if changed then settings.save() end

                if settings.master.gridFeatherEnabled then
                    local radius = settings.master.gridFeatherRadius
                    radius, changed = controls.SliderFloat(IconGlyphs.BlurRadial, "featherRadius", radius, 200, 1200, "%.0f px", nil, settings.defaults.gridFeatherRadius, "Feather Radius (distance where grid fades to zero)")
                    if changed then
                        settings.master.gridFeatherRadius = radius
                        settings.save()
                    end

                    local padding = settings.master.gridFeatherPadding
                    padding, changed = controls.SliderFloat(IconGlyphs.SelectionEllipse, "featherPadding", padding, 0, 120, "%.0f px", nil, settings.defaults.gridFeatherPadding, "Window Padding (area around window with full opacity)")
                    if changed then
                        settings.master.gridFeatherPadding = padding
                        settings.save()
                    end

                    local curve = settings.master.gridFeatherCurve
                    curve, changed = controls.SliderFloat(IconGlyphs.ChartBellCurveCumulative, "featherCurve", curve, 1.0, 12.0, "%.1f", nil, settings.defaults.gridFeatherCurve, "Feather Curve (higher = faster drop near window, gradual fade at edges)")
                    if changed then
                        settings.master.gridFeatherCurve = curve
                        settings.save()
                    end
                end
            end
        end

        -- Master override dependent settings
        if not settings.master.enabled then
            ImGui.BeginDisabled()
        end

        -- General settings
        controls.SectionHeader("General", 10, 0)
        settings.master.tooltipsEnabled, changed = controls.Checkbox("Show Tooltips", settings.master.tooltipsEnabled, settings.defaults.tooltipsEnabled, "Show Tooltips on Hover", true)
        if changed then settings.save() end

        -- Grid settings
        controls.SectionHeader("Grid Snapping", 10, 0)
        settings.master.gridEnabled, changed = controls.Checkbox("Enable Grid Snapping", settings.master.gridEnabled, settings.defaults.gridEnabled, "Snap Windows to Grid When Released")
        if changed then settings.save() end

        -- Get valid grid units and map to scale 1-N
        local validUnits = settings.getValidGridUnits(10)
        local maxScale = math.min(#validUnits, 5)  -- Cap at 5 scales
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
        newScale, changed = controls.SliderInt(IconGlyphs.Grid, "gridScale", currentScale, 1, maxScale, "Scale %d (" .. gridSize .. "px)", nil, defaultScale, "Grid Scale (maps to valid grid sizes for your resolution)")
        if changed then
            settings.master.gridUnits = validUnits[newScale]
            settings.save()
            core.invalidateGridCache()  -- Clear cached grid sizes
        end

        -- Animation settings
        controls.SectionHeader("Animation", 10, 0)
        settings.master.animationEnabled, changed = controls.Checkbox("Snap Animation", settings.master.animationEnabled, settings.defaults.animationEnabled, "Animate Window Snapping")
        if changed then settings.save() end

        local duration = settings.master.animationDuration
        duration, changed = controls.SliderFloat(IconGlyphs.TimerOutline, "animDuration", duration, 0.05, 1.0, "%.2f s", nil, settings.defaults.animationDuration, "Animation Duration")
        if changed then
            settings.master.animationDuration = duration
            settings.save()
        end

        local currentIndex = findEasingIndex(settings.master.easeFunction)
        local defaultEasingIndex = findEasingIndex(settings.defaults.easeFunction)
        local newIndex
        newIndex, changed = controls.Combo(IconGlyphs.SineWave, "easing", currentIndex, settings.easingNames, nil, defaultEasingIndex, "Easing Function")
        if changed then
            settings.master.easeFunction = settings.easingNames[newIndex + 1]
            settings.save()
        end

        -- Experimental settings
        controls.SectionHeader("Experimental", 10, 0)
        settings.master.overrideAllWindows, changed = controls.Checkbox("Override All Windows", settings.master.overrideAllWindows, settings.defaults.overrideAllWindows, "Apply Grid Snapping to All CET Windows\n(Requires Window Manager's RedCetWM plugin)\n\nWARNING: Currently has issue with windows not hidden by Window Manager!", true)
        if changed then
            settings.save()
            core.invalidateGridCache()  -- Clear cached grid sizes when override changes
        end

        if settings.master.overrideAllWindows and not core.isDiscoveryAvailable() then
            controls.TextWarning("RedCetWM plugin not found - Install Window Manager")
        end

        if not settings.master.enabled then
            ImGui.EndDisabled()
        end

        -- Update with WindowUtils (for this window)
        core.update("WindowUtils Settings", {
            gridEnabled = settings.master.gridEnabled,
            animationEnabled = settings.master.animationEnabled,
            animationDuration = settings.master.animationDuration
        })
    end

    ImGui.End()
end

--------------------------------------------------------------------------------
-- Window Control API
--------------------------------------------------------------------------------

function ui.show()
    ui.state.showWindow = true
end

function ui.hide()
    ui.state.showWindow = false
end

function ui.toggle()
    ui.state.showWindow = not ui.state.showWindow
end

function ui.isVisible()
    return ui.state.showWindow
end

return ui
