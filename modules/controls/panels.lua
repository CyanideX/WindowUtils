------------------------------------------------------
-- WindowUtils - Controls: Panels
-- PanelGroup, Panel (child window with default styling)
------------------------------------------------------

local core = require("modules/controls/core")

local frameCache = core.frameCache
local Scaled = core.Scaled
local PANEL_DEFAULT_BG = core.PANEL_DEFAULT_BG

local M = {}

--------------------------------------------------------------------------------
-- Module-local state
--------------------------------------------------------------------------------

local panelHoverState = {}      -- Panel hover state for borderOnHover
local panelResizeState = {}     -- Panel resize state: [id] = {height, dragging, dragStartH, dragStartY}
local panelAutoHeight = {}      -- Cache for auto-height panels (measured on previous frame)

--------------------------------------------------------------------------------
-- PanelGroup
--------------------------------------------------------------------------------

--- Visual panel wrapper for scrollable regions. Uses Group + DrawList instead
--- of BeginChild, so no explicit height is needed and no measurement feedback.
---@param id string Unique identifier (for hover state tracking)
---@param contentFn? function Callback that renders panel content
---@param opts? table {bg?, border?, borderOnHover?}
function M.PanelGroup(id, contentFn, opts)
    opts = opts or {}
    local borderOnHover = opts.borderOnHover or false
    local bg = opts.bg
    if bg == nil then bg = PANEL_DEFAULT_BG end

    local padX = frameCache.windowPaddingX or 8
    local padY = frameCache.windowPaddingY or 8
    local rounding = ImGui.GetStyle().ChildRounding or 4.0

    -- Capture start position and full available width before content
    local startX, startY = ImGui.GetCursorScreenPos()
    local availW = ImGui.GetContentRegionAvail()
    local contentW = availW - padX * 2

    ImGui.BeginGroup()

    -- Top padding + width reservation (forces group to full width)
    ImGui.Dummy(availW, padY)

    -- Left padding via indent; PushItemWidth constrains widget widths
    ImGui.Indent(padX)
    ImGui.PushItemWidth(contentW)
    if contentFn then contentFn() end
    ImGui.PopItemWidth()
    ImGui.Unindent(padX)

    -- Bottom padding
    ImGui.Dummy(availW, padY)

    ImGui.EndGroup()

    -- Rect: full available width, actual content height
    local _, maxY = ImGui.GetItemRectMax()
    local rectMinX = startX
    local rectMinY = startY
    local rectMaxX = startX + availW
    local rectMaxY = maxY

    local drawList = ImGui.GetWindowDrawList()

    -- Background fill
    if bg then
        local bgColor = ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX, rectMinY, rectMaxX, rectMaxY, bgColor, rounding)
    end

    -- Border: thin outline (4 edge rects, inset at corners for rounding)
    local showBorder = opts.border == true
    if borderOnHover and not showBorder then
        showBorder = panelHoverState[id] or false
    end
    if showBorder then
        local bc = ImGui.GetColorU32(ImGuiCol.Border)
        local t = 1.0
        local r = math.min(rounding, 6)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX + r, rectMinY, rectMaxX - r, rectMinY + t, bc)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX + r, rectMaxY - t, rectMaxX - r, rectMaxY, bc)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX, rectMinY + r, rectMinX + t, rectMaxY - r, bc)
        ImGui.ImDrawListAddRectFilled(drawList, rectMaxX - t, rectMinY + r, rectMaxX, rectMaxY - r, bc)
    end

    -- Hover tracking + tooltip
    if borderOnHover then
        local mx, my = ImGui.GetMousePos()
        local hovered = mx >= rectMinX and mx <= rectMaxX and my >= rectMinY and my <= rectMaxY
        panelHoverState[id] = hovered
        -- Show tooltip when hovering the panel background (not a child widget)
        if hovered and not ImGui.IsAnyItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("controls.PanelGroup(\"" .. id .. "\", fn, opts)")
            ImGui.EndTooltip()
        end
    end
end

--------------------------------------------------------------------------------
-- Panel (child window with default styling)
--------------------------------------------------------------------------------

--- Get the cached auto-height for a panel (measured on previous frame).
--- Returns nil if the panel hasn't been drawn yet or doesn't use height="auto".
---@param id string Panel ID
---@return number|nil height Cached content height in pixels
function M.getPanelAutoHeight(id)
    return panelAutoHeight[id]
end

-- Resize handle constants
local RESIZE_HANDLE_HEIGHT = 6
local RESIZE_HANDLE_COLOR = { 0.5, 0.5, 0.5, 0.0 }
local RESIZE_HANDLE_HOVER_COLOR = { 0.5, 0.7, 1.0, 0.4 }
local RESIZE_HANDLE_DRAG_COLOR = { 0.4, 0.8, 1.0, 0.6 }

--- Render a child window panel with default styling.
--- opts.resizable adds a drag handle at the bottom edge for vertical resizing.
--- When resizable, opts.height sets the initial height (default 200), and
--- opts.minHeight / opts.maxHeight set clamp bounds.
---@param id string Unique panel ID (## prefix added automatically if missing)
---@param contentFn? function Callback that renders panel content
---@param opts? table {bg?, border?, borderOnHover?, width?, height?, flags?, resizable?, minHeight?, maxHeight?}
---@return nil
function M.Panel(id, contentFn, opts)
    opts = opts or {}
    local border = opts.border == true
    local borderOnHover = opts.borderOnHover or false
    local bg = opts.bg
    if bg == nil then bg = PANEL_DEFAULT_BG end
    local width = opts.width or 0
    local height = opts.height or 0
    local resizable = opts.resizable or false
    local flags = ImGuiWindowFlags.AlwaysUseWindowPadding + (opts.flags or 0)

    -- Auto-height: use cached content height from previous frame (not compatible with resizable)
    if height == "auto" and not resizable then
        height = panelAutoHeight[id] or 100
    end

    -- Resizable: use persisted height from drag state
    if resizable then
        local rs = panelResizeState[id]
        if rs then
            height = rs.height
        else
            -- Initialize with provided height or a sensible default
            local initH = (type(opts.height) == "number" and opts.height > 0) and opts.height or 200
            panelResizeState[id] = { height = initH, dragging = false }
            height = initH
        end
    end

    local showBorder = border
    if borderOnHover and not border then
        showBorder = panelHoverState[id] or false
    end

    local childId = id:find("^##") and id or ("##" .. id)

    if bg then
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0))
    end
    ImGui.BeginChild(childId, width, height, showBorder, flags)
    if bg then ImGui.PopStyleColor() end
    if contentFn then contentFn() end

    -- Measure content height for auto-sizing on next frame
    if opts.height == "auto" and not resizable then
        local padY = ImGui.GetStyle().WindowPadding.y
        local spacingY = ImGui.GetStyle().ItemSpacing.y
        panelAutoHeight[id] = ImGui.GetCursorPosY() + padY - spacingY
    end

    ImGui.EndChild()

    if borderOnHover then
        panelHoverState[id] = ImGui.IsItemHovered()
    end

    -- Resize handle: invisible button below the panel that drags to resize
    if resizable then
        local rs = panelResizeState[id]
        local minH = opts.minHeight or 50
        local maxH = opts.maxHeight or 2000

        -- Draw the handle as a full-width invisible region
        local availW = ImGui.GetContentRegionAvail()
        local handleH = Scaled(RESIZE_HANDLE_HEIGHT)

        -- Reduce spacing between panel and handle so they feel connected
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)

        local handleColor = RESIZE_HANDLE_COLOR
        if rs.dragging then
            handleColor = RESIZE_HANDLE_DRAG_COLOR
        elseif rs.hovering then
            handleColor = RESIZE_HANDLE_HOVER_COLOR
        end

        ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(handleColor[1], handleColor[2], handleColor[3], handleColor[4]))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(RESIZE_HANDLE_HOVER_COLOR[1], RESIZE_HANDLE_HOVER_COLOR[2], RESIZE_HANDLE_HOVER_COLOR[3], RESIZE_HANDLE_HOVER_COLOR[4]))
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(RESIZE_HANDLE_DRAG_COLOR[1], RESIZE_HANDLE_DRAG_COLOR[2], RESIZE_HANDLE_DRAG_COLOR[3], RESIZE_HANDLE_DRAG_COLOR[4]))
        ImGui.Button("##resize_" .. id, availW, handleH)
        ImGui.PopStyleColor(3)

        rs.hovering = ImGui.IsItemHovered()

        if rs.hovering and ImGui.IsMouseDragging(0, 0) and not rs.dragging then
            rs.dragging = true
            rs.dragStartH = rs.height
            rs.dragStartY = select(2, ImGui.GetMousePos())
        end

        if rs.dragging then
            if ImGui.IsMouseDragging(0, 0) then
                local _, mouseY = ImGui.GetMousePos()
                local delta = mouseY - rs.dragStartY
                rs.height = math.max(minH, math.min(maxH, rs.dragStartH + delta))
            else
                rs.dragging = false
            end
        end

        if rs.hovering or rs.dragging then
            ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeNS)
        end

        ImGui.PopStyleVar()
    end
end

return M
