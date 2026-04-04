------------------------------------------------------
-- WindowUtils - Lists Module
-- Scrollable list container with per-item callbacks
------------------------------------------------------

local controls = require("modules/controls")
local styles = require("modules/styles")
local dragdrop = require("modules/dragdrop")
local utils = require("modules/utils")

local lists = {}

--- Render a scrollable list of items with per-item callbacks.
--- Handles ID scoping, hover-with-delay active tracking, style switching
--- for non-active items, auto-scroll, clipper optimization, and optional
--- drag-drop reorder with handle-based drag source.
---@param items table|nil Array of items to render (nil or empty shows placeholder)
---@param renderer function function(item, index, state) called for each visible item
---@param state table Caller-owned List_State table (mutated each frame)
---@param opts? table Configuration options
---  opts.id                string|nil    ImGui child region ID (default "##list")
---  opts.height            number|"fill"|nil  Fixed pixel height or "fill" (default "fill")
---  opts.footerHeight      number|nil    Space to reserve below the list (default 0)
---  opts.bg                table|nil     Background color {r,g,b,a} (default panel bg)
---  opts.placeholder       string|nil    Text shown when items is empty (default "No items")
---  opts.dimAlpha          number|nil    Alpha for non-focused items when focusIndex is set (default 0.4)
---  opts.itemHeight        number|nil    Fixed item height for ImGuiListClipper (nil = no clipper)
---  opts.showCount         boolean|nil   Show item count above the list (default false)
---  opts.countFormat       string|nil    Format string for count display (default "%d items")
---  opts.reorderable       boolean|nil   Enable drag-drop reordering (default false)
---  opts.onReorder         function|nil  function(fromIndex, toIndex) called after reorder
---  opts.dragHandle        string|nil    Icon name for drag handle (default "DragHorizontalVariant")
---  opts.dragColors        table|nil     Colors for drag/hover styles {dragAlpha?, hover?}
---  opts.unhighlightDelay  number|nil    Seconds before clearing activeIndex after hover exit (default 0.3)
---  opts.onActiveChange    function|nil  function(index|nil) called when activeIndex changes
---  opts.disableStyleFn    function|nil  Custom push style for non-active items (default styles.PushDragDisabled)
---  opts.disableStylePopFn function|nil  Custom pop style for non-active items (default styles.PopDragDisabled)
function lists.render(items, renderer, state, opts)
    opts = opts or {}

    local id               = opts.id or "##list"
    local height           = opts.height or "fill"
    local footerHeight     = opts.footerHeight or 0
    local bg               = opts.bg
    local placeholder      = opts.placeholder or "No items"
    local dimAlpha         = opts.dimAlpha or 0.4
    local itemHeight       = opts.itemHeight
    local showCount        = opts.showCount or false
    local countFormat      = opts.countFormat or "%d items"
    local reorderable      = opts.reorderable or false
    local onReorder        = opts.onReorder
    local dragHandle       = opts.dragHandle or "DragHorizontalVariant"
    local dragColors       = opts.dragColors
    local unhighlightDelay = opts.unhighlightDelay or 0.3
    local onActiveChange   = opts.onActiveChange
    local pushDisabled     = opts.disableStyleFn or styles.PushDragDisabled
    local popDisabled      = opts.disableStylePopFn or styles.PopDragDisabled

    -- Nil guards
    if not renderer then
        print("[WindowUtils] Lists: renderer is nil, skipping render")
        return
    end
    if not state then
        print("[WindowUtils] Lists: state is nil, skipping render")
        return
    end

    -- Empty state
    if not items or #items == 0 then
        -- Clear active tracking when list becomes empty
        if state.activeIndex then
            state.activeIndex = nil
            state._hoverExitTime = nil
            if onActiveChange then onActiveChange(nil) end
        end
        if height == "fill" or height == nil then
            controls.BeginFillChild(id, { footerHeight = footerHeight, bg = bg })
            controls.TextMuted(placeholder)
            controls.EndFillChild(id)
        else
            ImGui.BeginChild(id, 0, height, false, 0)
            controls.TextMuted(placeholder)
            ImGui.EndChild()
        end
        return
    end

    -- Count display (above the list region)
    if showCount then
        controls.TextMuted(string.format(countFormat, #items))
    end

    -- Open scrollable child region
    if height == "fill" or height == nil then
        controls.BeginFillChild(id, { footerHeight = footerHeight, bg = bg })
    else
        if bg then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0))
        end
        ImGui.BeginChild(id, 0, height, false, ImGuiWindowFlags.AlwaysUseWindowPadding)
    end

    -- Focus index clamping
    if state.focusIndex then
        if #items == 0 then
            state.focusIndex = nil
        elseif state.focusIndex > #items then
            state.focusIndex = #items
        elseif state.focusIndex < 1 then
            state.focusIndex = 1
        end
    end

    -- Clamp activeIndex if items shrunk
    if state.activeIndex then
        if state.activeIndex > #items or state.activeIndex < 1 then
            state.activeIndex = nil
            state._hoverExitTime = nil
            if onActiveChange then onActiveChange(nil) end
        end
    end

    -- Clear out-of-bounds scroll target
    if state.scrollTarget and (state.scrollTarget < 1 or state.scrollTarget > #items) then
        state.scrollTarget = nil
    end

    -- Per-frame tracking for hover/drag-active detection
    state.hoveredIndex = nil
    local frameHoveredIndex = nil
    local frameDragActiveIndex = nil

    -- Auto-create drag-drop state when reorderable
    if reorderable and not state._dragdrop then
        state._dragdrop = dragdrop.createState()
    end

    -- Resolve drag handle icon once
    local handleGlyph = reorderable and (utils.resolveIcon(dragHandle) or "") or nil
    local handleColor = { 0.5, 0.5, 0.5, 1.0 }

    -- Per-item render function (shared between clipper and simple paths)
    local function renderItem(i)
        -- Drag-drop context and pre-item separator
        local ctx
        if reorderable then
            ctx = dragdrop.getItemContext(i, state._dragdrop)
            if state._dragdrop.draggingIndex then
                dragdrop.drawSeparator(ctx.dropAbove)
            end
            dragdrop.pushItemStyles(ctx, dragColors)
        end

        -- Style switching: non-active items get disabled styling when an active item exists
        local isNonActive = state.activeIndex ~= nil and state.activeIndex ~= i
        -- Alpha dimming for non-focused items (separate from active tracking)
        local dimmed = false
        if state.focusIndex and i ~= state.focusIndex then
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, dimAlpha)
            dimmed = true
        end
        if isNonActive then
            pushDisabled()
        end

        ImGui.PushID(i)

        -- Record start position for bounding rect hover detection
        local itemStartY = select(2, ImGui.GetCursorScreenPos())

        -- Drag handle as button (drag source, rendered before content so drags inside work independently)
        local handleReorder, handleFrom, handleTo
        if reorderable then
            ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(handleColor[1], handleColor[2], handleColor[3], handleColor[4]))
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)

            ImGui.Button(handleGlyph .. "##handle_" .. i)

            if ImGui.IsItemActive() and ImGui.IsMouseDragging(0, 2.0) then
                if not state._dragdrop.draggingIndex then
                    state._dragdrop.draggingIndex = i
                end
            end

            -- Track handle hover for activeIndex
            if ImGui.IsItemHovered() then
                state.hoveredIndex = i
                frameHoveredIndex = i
            end

            -- handleDrag on the handle button: tracks hover for drop targeting and detects reorder on release
            handleReorder, handleFrom, handleTo = dragdrop.handleDrag(i, #items, state._dragdrop)

            ImGui.PopStyleVar()
            ImGui.PopStyleColor(4)
            ImGui.SameLine()
        end

        ImGui.BeginGroup()

        -- Auto-scroll to target item
        if state.scrollTarget == i then
            ImGui.SetScrollHereY(0.5)
            state.scrollTarget = nil
        end

        renderer(items[i], i, state)

        ImGui.EndGroup()

        -- Bounding rect hover detection: covers the entire item area including all rows
        -- IsItemHovered on a group fails when interactive children (DragFloat etc) are hovered,
        -- so we check the mouse position against the item's bounding rect manually.
        local itemMinX, itemMinY = ImGui.GetItemRectMin()
        local itemMaxX, itemMaxY = ImGui.GetItemRectMax()
        -- Extend rect to include the handle column
        if reorderable then
            local windowMinX = select(1, ImGui.GetWindowPos())
            itemMinX = windowMinX
        end
        local mouseX, mouseY = ImGui.GetMousePos()
        local mouseInRect = mouseX >= itemMinX and mouseX <= itemMaxX and mouseY >= itemStartY and mouseY <= itemMaxY
        -- Only count as hovered if the list child window is hovered (not blocked by popups etc)
        if mouseInRect and ImGui.IsWindowHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) then
            state.hoveredIndex = i
            frameHoveredIndex = i
        end

        -- Track drag-active: if any widget in this item's rect is active
        if ImGui.IsItemActive() then
            frameDragActiveIndex = i
        end

        ImGui.PopID()

        if isNonActive then
            popDisabled()
        end
        if dimmed then
            ImGui.PopStyleVar()
        end

        if reorderable then
            dragdrop.popItemStyles(ctx)

            if state._dragdrop.draggingIndex then
                dragdrop.drawSeparator(ctx.dropBelow)
            end

            if handleReorder then
                dragdrop.reorderArray(items, handleFrom, handleTo)
                if onReorder then
                    onReorder(handleFrom, handleTo)
                end
            end
        end
    end

    -- Item iteration: clipper path for uniform-height items, simple loop otherwise
    if itemHeight and #items > 0 then
        local clipper = ImGuiListClipper.new()
        clipper:Begin(#items, itemHeight)
        while clipper:Step() do
            for i = clipper.DisplayStart + 1, clipper.DisplayEnd do
                renderItem(i)
            end
        end
    else
        for i = 1, #items do
            renderItem(i)
        end
    end

    -- Update drag cursor after the loop
    if reorderable then
        dragdrop.updateCursor(state._dragdrop)
    end

    -- Close scrollable child region
    if height == "fill" or height == nil then
        controls.EndFillChild(id)
    else
        ImGui.EndChild()
        if bg then
            ImGui.PopStyleColor()
        end
    end

    -- Active index tracking with delayed unhighlight (like Echo's editPointsActivePositionIndex)
    local prevActive = state.activeIndex
    if frameHoveredIndex then
        -- Hovering an item: activate immediately, clear exit timer
        state.activeIndex = frameHoveredIndex
        state._hoverExitTime = nil
    elseif frameDragActiveIndex then
        -- Drag active on an item: keep it highlighted, clear exit timer
        state.activeIndex = frameDragActiveIndex
        state._hoverExitTime = nil
    else
        -- Nothing hovered or dragged: start/check delay timer before clearing
        if state.activeIndex ~= nil then
            if state._hoverExitTime == nil then
                state._hoverExitTime = os.clock()
            elseif os.clock() - state._hoverExitTime >= unhighlightDelay then
                state.activeIndex = nil
                state._hoverExitTime = nil
            end
        end
    end

    -- Notify caller when activeIndex changes
    if state.activeIndex ~= prevActive and onActiveChange then
        onActiveChange(state.activeIndex)
    end
end

return lists
