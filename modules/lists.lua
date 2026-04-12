------------------------------------------------------
-- WindowUtils - Lists
-- Scrollable list rendering with per-item callbacks
------------------------------------------------------

local controls = require("modules/controls")
local styles = require("modules/styles")
local dragdrop = require("modules/dragdrop")
local utils = require("modules/utils")
local frameContext = require("core/frameContext")

local lists = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local HANDLE_COLOR = { 0.5, 0.5, 0.5, 1.0 }
local DEFAULT_DIM_ALPHA = 0.4
local DEFAULT_UNHIGHLIGHT_DELAY = 0.3

--------------------------------------------------------------------------------
-- Internal: hover detection via bounding rect
--------------------------------------------------------------------------------

--- Check if the mouse is inside a screen-space rect and the window is hovered.
--- Reliable even when interactive children (DragFloat, Button) capture hover.
---@param minX number Left edge (screen coords)
---@param minY number Top edge (screen coords)
---@param maxX number Right edge (screen coords)
---@param maxY number Bottom edge (screen coords)
---@return boolean
local function isMouseInRect(minX, minY, maxX, maxY)
    local mx, my = ImGui.GetMousePos()
    return mx >= minX and mx <= maxX and my >= minY and my <= maxY
end

--------------------------------------------------------------------------------
-- Internal: active index tracking with delayed unhighlight
--------------------------------------------------------------------------------

--- Update state.activeIndex based on this frame's hover/drag detection.
--- Called once after all items are rendered and the child region is closed.
---@param state table List state
---@param frameHovered number|nil Item index hovered this frame
---@param frameDragActive number|nil Item index with an active drag this frame
---@param delay number Seconds before clearing activeIndex
---@param onChange function|nil Callback when activeIndex changes
local function updateActiveTracking(state, frameHovered, frameDragActive, delay, onChange)
    local prev = state.activeIndex

    if frameHovered then
        state.activeIndex = frameHovered
        state._hoverExitTime = nil
    elseif frameDragActive then
        state.activeIndex = frameDragActive
        state._hoverExitTime = nil
    elseif state.activeIndex ~= nil then
        if state._hoverExitTime == nil then
            state._hoverExitTime = frameContext.get().clock
        elseif frameContext.get().clock - state._hoverExitTime >= delay then
            state.activeIndex = nil
            state._hoverExitTime = nil
        end
    end

    if state.activeIndex ~= prev and onChange then
        onChange(state.activeIndex)
    end
end

--------------------------------------------------------------------------------
-- Internal: scrollable region open/close
--------------------------------------------------------------------------------

local function openRegion(id, height, footerHeight, bg)
    if height == "fill" or height == nil then
        controls.BeginFillChild(id, { footerHeight = footerHeight, bg = bg })
    else
        if bg then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0))
        end
        ImGui.BeginChild(id, 0, height, false, ImGuiWindowFlags.AlwaysUseWindowPadding)
    end
end

local function closeRegion(id, height, bg)
    if height == "fill" or height == nil then
        controls.EndFillChild(id)
    else
        ImGui.EndChild()
        if bg then ImGui.PopStyleColor() end
    end
end

--------------------------------------------------------------------------------
-- Internal: clamp helpers
--------------------------------------------------------------------------------

local function clampIndex(state, field, count)
    local v = state[field]
    if not v then return end
    if count == 0 then
        state[field] = nil
    elseif v > count then
        state[field] = count
    elseif v < 1 then
        state[field] = 1
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Render a scrollable list of items with per-item callbacks.
--- Handles ID scoping, active-index tracking with delayed unhighlight,
--- disabled styling for non-active items, auto-scroll, clipper optimization,
--- and optional drag-drop reorder with handle-based drag source.
---@param items table|nil Array of items to render (nil or empty shows placeholder)
---@param renderer function function(item, index, state) called for each visible item
---@param state table Caller-owned state table (mutated each frame)
---@param opts? table Configuration options
---  opts.id               string    ImGui child region ID (default "##list")
---  opts.height           number|"fill"  Fixed pixel height or "fill" (default "fill")
---  opts.footerHeight     number    Space below the list in fill mode (default 0)
---  opts.bg               table     Background color {r,g,b,a} (default panel bg)
---  opts.placeholder      string    Text when items is empty (default "No items")
---  opts.dimAlpha         number    Alpha for non-focused items (default 0.4)
---  opts.itemHeight       number    Fixed item height for clipper (nil = no clipper)
---  opts.showCount        boolean   Show item count above the list (default false)
---  opts.countFormat      string    Format string for count (default "%d items")
---  opts.reorderable      boolean   Enable drag-drop reordering (default false)
---  opts.onReorder        function  function(fromIndex, toIndex) after reorder
---  opts.dragHandle       string    Icon name for drag handle (default "DragHorizontalVariant")
---  opts.dragColors       table     Colors for drag/hover {dragAlpha?, hover?}
---  opts.unhighlightDelay number    Delay before clearing activeIndex (default 0.3)
---  opts.onActiveChange   function  function(index|nil) when activeIndex changes
function lists.render(items, renderer, state, opts)
    if not renderer then
        print("[WindowUtils] Lists: renderer is nil, skipping render")
        return
    end
    if not state then
        print("[WindowUtils] Lists: state is nil, skipping render")
        return
    end

    opts = opts or {}
    local id               = opts.id or "##list"
    local height           = opts.height or "fill"
    local footerHeight     = opts.footerHeight or 0
    local bg               = opts.bg
    local placeholder      = opts.placeholder or "No items"
    local dimAlpha         = opts.dimAlpha or DEFAULT_DIM_ALPHA
    local itemHeight       = opts.itemHeight
    local showCount        = opts.showCount or false
    local countFormat      = opts.countFormat or "%d items"
    local reorderable      = opts.reorderable or false
    local onReorder        = opts.onReorder
    local dragHandle       = opts.dragHandle or "DragHorizontalVariant"
    local dragColors       = opts.dragColors
    local unhighlightDelay = opts.unhighlightDelay or DEFAULT_UNHIGHLIGHT_DELAY
    local onActiveChange   = opts.onActiveChange

    local count = items and #items or 0

    -- Empty state: clear tracking and show placeholder
    if count == 0 then
        if state.activeIndex then
            state.activeIndex = nil
            state._hoverExitTime = nil
            if onActiveChange then onActiveChange(nil) end
        end
        openRegion(id, height, footerHeight, bg)
        controls.TextMuted(placeholder)
        closeRegion(id, height, bg)
        return
    end

    -- Count display (above the scrollable region)
    if showCount then
        controls.TextMuted(string.format(countFormat, count))
    end

    openRegion(id, height, footerHeight, bg)

    -- Clamp caller-set indices
    clampIndex(state, "focusIndex", count)
    clampIndex(state, "activeIndex", count)
    if state.activeIndex == nil then state._hoverExitTime = nil end

    -- Clear out-of-bounds scroll target
    if state.scrollTarget and (state.scrollTarget < 1 or state.scrollTarget > count) then
        state.scrollTarget = nil
    end

    -- Per-frame tracking
    state.hoveredIndex = nil
    local frameHovered = nil
    local frameDragActive = nil
    local isDragging = false

    -- Drag-drop state
    if reorderable and not state._dragdrop then
        state._dragdrop = dragdrop.createState()
    end
    if reorderable and state._dragdrop.draggingIndex then
        isDragging = true
    end
    local handleGlyph = reorderable and (utils.resolveIcon(dragHandle) or "") or nil

    -- Render one item. Defined here to share locals; not a closure issue since
    -- Lua reuses the function object across iterations within the same call.
    local function renderItem(i)
        local ddState = state._dragdrop

        ----------------------------------------------------------------
        -- Drag-drop: context + pre-item separator
        ----------------------------------------------------------------
        local ctx, handleReorder, handleFrom, handleTo
        if reorderable then
            ctx = dragdrop.getItemContext(i, ddState)
            if ddState.draggingIndex then
                dragdrop.drawSeparator(ctx.dropAbove)
            end
            dragdrop.pushItemStyles(ctx, dragColors)
        end

        ----------------------------------------------------------------
        -- Style: disabled look for non-active items, alpha dim for non-focused
        ----------------------------------------------------------------
        local isNonActive = state.activeIndex ~= nil and state.activeIndex ~= i
        local dimmed = false
        if state.focusIndex and i ~= state.focusIndex then
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, dimAlpha)
            dimmed = true
        end
        if isNonActive then
            styles.PushDragDisabled()
        end

        ----------------------------------------------------------------
        -- Item scope
        ----------------------------------------------------------------
        ImGui.PushID(i)

        -- Capture Y before any widgets for rect-based hover detection
        local startY = select(2, ImGui.GetCursorScreenPos())

        ----------------------------------------------------------------
        -- Drag handle (rendered before content group so inner drags work)
        ----------------------------------------------------------------
        if reorderable then
            ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(HANDLE_COLOR[1], HANDLE_COLOR[2], HANDLE_COLOR[3], HANDLE_COLOR[4]))
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)

            ImGui.Button(handleGlyph .. "##handle_" .. i)

            if ImGui.IsItemActive() and ImGui.IsMouseDragging(0, 2.0) then
                if not ddState.draggingIndex then
                    ddState.draggingIndex = i
                end
            end

            handleReorder, handleFrom, handleTo = dragdrop.handleDrag(i, count, ddState)

            ImGui.PopStyleVar()
            ImGui.PopStyleColor(4)
            ImGui.SameLine()
        end

        ----------------------------------------------------------------
        -- Content group (renderer callback)
        ----------------------------------------------------------------
        ImGui.BeginGroup()

        if state.scrollTarget == i then
            ImGui.SetScrollHereY(0.5)
            state.scrollTarget = nil
        end

        renderer(items[i], i, state)

        ImGui.EndGroup()

        ----------------------------------------------------------------
        -- Hover detection: rect-based, works with interactive children
        -- Suppressed during drag-drop to prevent highlighting other items
        ----------------------------------------------------------------
        if not isDragging then
            local grpMinX = select(1, ImGui.GetItemRectMin())
            local grpMaxX, grpMaxY = ImGui.GetItemRectMax()
            local rectMinX = reorderable and select(1, ImGui.GetWindowPos()) or grpMinX

            if isMouseInRect(rectMinX, startY, grpMaxX, grpMaxY)
               and ImGui.IsWindowHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) then
                state.hoveredIndex = i
                frameHovered = i
            end

            -- Drag-active: mouse is held down inside this item's rect
            if ImGui.IsMouseDown(0) and isMouseInRect(rectMinX, startY, grpMaxX, grpMaxY) then
                frameDragActive = i
            end
        end

        ----------------------------------------------------------------
        -- Pop styles (reverse order of push)
        ----------------------------------------------------------------
        ImGui.PopID()
        if isNonActive then styles.PopDragDisabled() end
        if dimmed then ImGui.PopStyleVar() end

        ----------------------------------------------------------------
        -- Drag-drop: post-item separator + reorder
        ----------------------------------------------------------------
        if reorderable then
            dragdrop.popItemStyles(ctx)
            if ddState.draggingIndex then
                dragdrop.drawSeparator(ctx.dropBelow)
            end
            if handleReorder then
                dragdrop.reorderArray(items, handleFrom, handleTo)
                if onReorder then onReorder(handleFrom, handleTo) end
            end
        end
    end

    ----------------------------------------------------------------
    -- Item iteration
    ----------------------------------------------------------------
    if itemHeight and count > 0 then
        local clipper = ImGuiListClipper.new()
        clipper:Begin(count, itemHeight)
        while clipper:Step() do
            for i = clipper.DisplayStart + 1, clipper.DisplayEnd do
                renderItem(i)
            end
        end
    else
        for i = 1, count do
            renderItem(i)
        end
    end

    if reorderable then
        dragdrop.updateCursor(state._dragdrop)
    end

    closeRegion(id, height, bg)

    -- Post-frame: update active index with delayed unhighlight
    updateActiveTracking(state, frameHovered, frameDragActive, unhighlightDelay, onActiveChange)
end

return lists
