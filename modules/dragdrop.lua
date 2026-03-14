------------------------------------------------------
-- WindowUtils - DragDrop Module
-- Drag-and-drop reordering for ImGui lists
------------------------------------------------------

local styles = require("modules/styles")

local dragdrop = {}

local defaultHoverColor = nil
local function getDefaultHoverColor()
    if not defaultHoverColor then
        defaultHoverColor = { styles.colors.blueHover[1], styles.colors.blueHover[2], styles.colors.blueHover[3], 0.3 }
    end
    return defaultHoverColor
end

--------------------------------------------------------------------------------
-- State Management
--------------------------------------------------------------------------------

--- Create a new drag-drop state for a list.
---@return table state {draggingIndex, hoverIndex, dropPosition}
function dragdrop.createState()
    return {
        draggingIndex = nil,     -- Index being dragged (1-based, nil if not dragging)
        hoverIndex = nil,        -- Index currently hovered over
        dropPosition = nil,      -- "above" or "below" relative to hoverIndex
    }
end

--- Reset all drag state fields to nil.
---@param state table Drag-drop state from createState()
function dragdrop.resetState(state)
    state.draggingIndex = nil
    state.hoverIndex = nil
    state.dropPosition = nil
end

--------------------------------------------------------------------------------
-- Core API (advanced, manual state management)
--------------------------------------------------------------------------------

-- Reusable context table — do not store the reference across frames
local reusableCtx = { isDragged = false, isHoverTarget = false, dropAbove = false, dropBelow = false }

--- Get drag context for an item (call at start of each list item).
---@param index number 1-based item index
---@param state table Drag-drop state
---@return table ctx {isDragged, isHoverTarget, dropAbove, dropBelow}
function dragdrop.getItemContext(index, state)
    local isDragging = state.draggingIndex ~= nil
    reusableCtx.isDragged = state.draggingIndex == index
    reusableCtx.isHoverTarget = isDragging and state.hoverIndex == index and state.draggingIndex ~= index
    reusableCtx.dropAbove = isDragging and state.hoverIndex == index and state.dropPosition == "above" and state.draggingIndex ~= index
    reusableCtx.dropBelow = isDragging and state.hoverIndex == index and state.dropPosition == "below" and state.draggingIndex ~= index
    return reusableCtx
end

--- Track hover position on the last ImGui item for drop targeting
local function trackHover(index, state)
    if state.draggingIndex and state.draggingIndex ~= index then
        if ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) then
            state.hoverIndex = index
            local minY = select(2, ImGui.GetItemRectMin())
            local maxY = select(2, ImGui.GetItemRectMax())
            local mouseY = select(2, ImGui.GetMousePos())
            state.dropPosition = mouseY < (minY + maxY) / 2 and "above" or "below"
        end
    end
end

--- Handle drag interaction for an ImGui item (call AFTER the draggable ImGui element).
---@param index number 1-based item index
---@param totalCount number Total number of items in the list
---@param state table Drag-drop state
---@return boolean shouldReorder Whether a reorder should be applied
---@return number|nil fromIndex Source index (nil if no reorder)
---@return number|nil toIndex Destination index (nil if no reorder)
function dragdrop.handleDrag(index, totalCount, state)
    local shouldReorder = false
    local fromIndex, toIndex = nil, nil

    -- Start dragging when item is active and mouse is dragging
    if ImGui.IsItemActive() and ImGui.IsMouseDragging(0, 2.0) then
        if not state.draggingIndex then
            state.draggingIndex = index
        end
    end

    -- Track hover position for non-dragged items
    trackHover(index, state)

    -- Handle drop when mouse released
    if state.draggingIndex == index and not ImGui.IsMouseDown(0) then
        if state.hoverIndex and state.dropPosition and state.hoverIndex ~= index then
            shouldReorder = true
            fromIndex = index
            toIndex = state.hoverIndex

            if state.dropPosition == "below" then
                toIndex = toIndex + 1
            end
            -- Adjust for removal shifting indices
            if fromIndex < toIndex then
                toIndex = toIndex - 1
            end
            -- Clamp to valid range
            toIndex = math.max(1, math.min(toIndex, totalCount))
        end
        dragdrop.resetState(state)
    end

    return shouldReorder, fromIndex, toIndex
end

--- Check if currently dragging any item.
---@param state table Drag-drop state
---@return boolean
function dragdrop.isDragging(state)
    return state.draggingIndex ~= nil
end

--- Get the index being dragged (or nil).
---@param state table Drag-drop state
---@return number|nil
function dragdrop.getDraggingIndex(state)
    return state.draggingIndex
end

--------------------------------------------------------------------------------
-- Visual Feedback Helpers
--------------------------------------------------------------------------------

--- Push visual styles for dragged/hover state.
---@param ctx table Item context from getItemContext()
---@param colors? table {dragAlpha?: number, hover?: table}
function dragdrop.pushItemStyles(ctx, colors)
    colors = colors or {}
    local dragAlpha = colors.dragAlpha or 0.4
    local hoverColor = colors.hover or getDefaultHoverColor()

    if ctx.isDragged then
        ImGui.PushStyleVar(ImGuiStyleVar.Alpha, dragAlpha)
    end
    if ctx.isHoverTarget then
        ImGui.PushStyleColor(ImGuiCol.Header, ImGui.GetColorU32(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4]))
    end
end

--- Pop visual styles (must match pushItemStyles).
---@param ctx table Item context from getItemContext()
function dragdrop.popItemStyles(ctx)
    if ctx.isHoverTarget then
        ImGui.PopStyleColor()
    end
    if ctx.isDragged then
        ImGui.PopStyleVar()
    end
end

--- Draw a colored drop indicator separator.
---@param show boolean Whether to render
---@param color? table {r,g,b,a} color (default: blueHover)
function dragdrop.drawSeparator(show, color)
    if not show then return end
    color = color or styles.colors.blueHover
    ImGui.PushStyleColor(ImGuiCol.Separator, ImGui.GetColorU32(color[1], color[2], color[3], color[4]))
    ImGui.Separator()
    ImGui.PopStyleColor()
end

--- Set hand cursor when dragging over a valid target (call once after the list loop).
---@param state table Drag-drop state
function dragdrop.updateCursor(state)
    if state.draggingIndex and state.hoverIndex and state.dropPosition then
        ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
    end
end

--------------------------------------------------------------------------------
-- Array Utility
--------------------------------------------------------------------------------

--- Move an element in an array from one index to another (mutates in-place).
---@param array table The array to reorder
---@param fromIndex number Source index
---@param toIndex number Destination index
function dragdrop.reorderArray(array, fromIndex, toIndex)
    if fromIndex < 1 or fromIndex > #array then return end
    if toIndex < 1 or toIndex > #array then return end
    if fromIndex == toIndex then return end

    local item = table.remove(array, fromIndex)
    table.insert(array, toIndex, item)
end

--------------------------------------------------------------------------------
-- Convenience API: dd.list()
--------------------------------------------------------------------------------

-- Cached states for the convenience wrapper, keyed by list ID
local listStates = {}

--- Render a reorderable list with all state, visuals, and array mutation handled internally.
---@param id string Unique list ID
---@param items table Array to reorder in-place on drop
---@param renderFn function function(item, index, ctx) — render each item
---@param onReorder? function function(fromIndex, toIndex) — called after reorder
---@param opts? table {colors?, showHandle?, handleIcon?, handleColor?}
function dragdrop.list(id, items, renderFn, onReorder, opts)
    if not items or #items == 0 then return end

    -- Get or create cached state for this list
    if not listStates[id] then
        listStates[id] = dragdrop.createState()
    end
    local state = listStates[id]

    opts = opts or {}
    local colors = opts.colors or nil
    local showHandle = opts.showHandle or false
    local handleIcon = opts.handleIcon or "DragVertical"
    if IconGlyphs and IconGlyphs[handleIcon] then handleIcon = IconGlyphs[handleIcon] end
    local handleColor = opts.handleColor or { 0.5, 0.5, 0.5, 1.0 }

    for i = 1, #items do
        local ctx = dragdrop.getItemContext(i, state)

        -- Draw drop separator above this item if dropping here
        if state.draggingIndex then
            dragdrop.drawSeparator(ctx.dropAbove, colors and colors.separator or nil)
        end

        -- Push visual styles
        dragdrop.pushItemStyles(ctx, colors)

        -- Render optional drag handle (transparent button so it's interactive)
        if showHandle then
            ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(handleColor[1], handleColor[2], handleColor[3], handleColor[4]))
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)

            ImGui.Button(handleIcon .. "##handle_" .. i)

            -- Start drag from handle
            if ImGui.IsItemActive() and ImGui.IsMouseDragging(0, 2.0) then
                if not state.draggingIndex then state.draggingIndex = i end
            end

            -- Track hover on handle for drop targeting
            trackHover(i, state)

            ImGui.PopStyleVar()
            ImGui.PopStyleColor(4)
            ImGui.SameLine()
        end

        -- Render the item
        ImGui.PushID(id .. "_item_" .. i)
        renderFn(items[i], i, ctx)
        ImGui.PopID()

        -- Handle drag interaction
        local shouldReorder, fromIdx, toIdx = dragdrop.handleDrag(i, #items, state)

        -- Pop visual styles
        dragdrop.popItemStyles(ctx)

        -- Draw drop separator below this item if dropping here
        if state.draggingIndex then
            dragdrop.drawSeparator(ctx.dropBelow, colors and colors.separator or nil)
        end

        -- Apply reorder
        if shouldReorder and fromIdx and toIdx then
            dragdrop.reorderArray(items, fromIdx, toIdx)
            if onReorder then
                onReorder(fromIdx, toIdx)
            end
        end
    end

    -- Update cursor
    dragdrop.updateCursor(state)
end

return dragdrop
