------------------------------------------------------
-- WindowUtils - Controls Layout
-- Layout containers: Row, MultiRow, Column, BeginFillChild, EndFillChild
------------------------------------------------------

local styles = require("modules/styles")
local core = require("modules/controls/core")

local frameCache = core.frameCache
local PANEL_DEFAULT_BG = core.PANEL_DEFAULT_BG

local M = {}

--------------------------------------------------------------------------------
-- Module-local state
--------------------------------------------------------------------------------

local fillChildBgState = {}     -- BeginFillChild bg push tracking
local columnAutoCache = {}      -- Column auto-size cache: [columnId][childIndex] = height

--------------------------------------------------------------------------------
-- Fill-Available-Space Child Region
--------------------------------------------------------------------------------

--- Begin a child region that fills remaining vertical space in the window.
--- bg defaults to the standard panel background. Pass false for transparent,
--- or an {r,g,b,a} table for a custom color.
---@param id string Unique child ID (## prefix added automatically if missing)
---@param opts? table {footerHeight?, border?, flags?, bg?}
---@return boolean visible True if the child region is visible
function M.BeginFillChild(id, opts)
    opts = opts or {}
    local footerHeight = opts.footerHeight or 0
    local border = opts.border or false
    local extraFlags = opts.flags or 0
    local bg = opts.bg
    if bg == nil then bg = PANEL_DEFAULT_BG end

    local childId = id
    if not id:find("^##") then
        childId = "##" .. id
    end

    if bg and bg ~= false then
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0))
        fillChildBgState[id] = true
    else
        fillChildBgState[id] = false
    end

    local width, contentAvailH = ImGui.GetContentRegionAvail()
    -- Subtract footer + item spacing between child and footer (if any)
    local spacingBeforeFooter = footerHeight > 0 and frameCache.itemSpacingY or 0
    local childHeight = math.max(contentAvailH - footerHeight - spacingBeforeFooter, 1)

    local flags = ImGuiWindowFlags.AlwaysUseWindowPadding + extraFlags

    styles.PushScrollbar()
    return ImGui.BeginChild(childId, width, childHeight, border, flags)
end

--- End a fill child region. Pops ChildBg if BeginFillChild pushed one for this id.
---@param id string Child ID passed to BeginFillChild
---@return nil
function M.EndFillChild(id)
    ImGui.EndChild()
    styles.PopScrollbar()
    if id == nil then
        print("[WindowUtils] EndFillChild called with nil id")
        return
    end
    if fillChildBgState[id] then
        ImGui.PopStyleColor()
        fillChildBgState[id] = nil
    end
end

--------------------------------------------------------------------------------
-- Layout: Row (horizontal child windows)
--------------------------------------------------------------------------------

--- Horizontal row of child windows that fills available width
---@param id string Unique row ID prefix
---@param defs table Array of column defs: {width?, cols?, flex?, bg?, border?, flags?, content?}
---@param opts? table {gap?, height?}
---@return nil
function M.Row(id, defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}
    local gap = opts.gap or frameCache.itemSpacingX
    local rowHeight = opts.height or 0

    -- Phase 1: calculate widths
    local availW = ImGui.GetContentRegionAvail()
    local totalGap = gap * (#defs - 1)
    local fixedW = 0
    local totalFlex = 0

    local calcWidths = {}
    for i, def in ipairs(defs) do
        if def.width then
            fixedW = fixedW + def.width
        elseif def.cols then
            calcWidths[i] = core.ColWidth(def.cols, gap)
            fixedW = fixedW + calcWidths[i]
        else
            totalFlex = totalFlex + (def.flex or 1)
        end
    end

    local remainingW = math.max(availW - totalGap - fixedW, 0)

    -- Phase 2: render children
    for i, def in ipairs(defs) do
        local childW
        if def.width then
            childW = def.width
        elseif calcWidths[i] then
            childW = calcWidths[i]
        else
            childW = totalFlex > 0
                and math.floor(remainingW * (def.flex or 1) / totalFlex)
                or 0
        end

        if def.bg then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, def.bg[1], def.bg[2], def.bg[3], def.bg[4] or 1.0)
        end

        local childId = "##row_" .. id .. "_" .. i
        ImGui.BeginChild(childId, childW, rowHeight, def.border or false, def.flags or 0)
        if def.content then def.content() end
        ImGui.EndChild()

        if def.bg then ImGui.PopStyleColor() end

        if i < #defs then
            ImGui.SameLine()
        end
    end
end

--------------------------------------------------------------------------------
-- Layout: MultiRow (horizontal cells with vertical spanning/stacking)
--------------------------------------------------------------------------------

--- Horizontal row of child windows where cells can span multiple rows or stack controls vertically
---@param id string Unique row ID prefix
---@param rows number Number of visual rows (determines region height)
---@param defs table Array of cell defs: {width?, cols?, flex?, span?, rows?, content?, bg?, border?, flags?}
---@param opts? table {gap?}
---@return nil
function M.MultiRow(id, rows, defs, opts)
    if not defs or #defs == 0 then return end
    if type(rows) ~= "number" or rows < 1 then
        print("[WindowUtils] MultiRow '" .. id .. "': invalid row count")
        return
    end
    opts = opts or {}

    local rowHeight = frameCache.frameHeight + frameCache.itemSpacingY
    local regionHeight = rows * rowHeight

    -- Phase 1: calculate widths
    local availW = ImGui.GetContentRegionAvail()
    local gap = opts.gap or frameCache.itemSpacingX
    local totalGap = gap * (#defs - 1)
    local fixedW = 0
    local totalFlex = 0
    local calcWidths = {}

    for i, def in ipairs(defs) do
        if def.width then
            fixedW = fixedW + def.width
        elseif def.cols then
            calcWidths[i] = core.ColWidth(def.cols, gap)
            fixedW = fixedW + calcWidths[i]
        else
            totalFlex = totalFlex + (def.flex or 1)
        end
    end

    local remainingW = math.max(availW - totalGap - fixedW, 0)

    -- Phase 2: render cells
    for i, def in ipairs(defs) do
        local cellW
        if def.width then
            cellW = def.width
        elseif calcWidths[i] then
            cellW = calcWidths[i]
        else
            cellW = totalFlex > 0
                and math.floor(remainingW * (def.flex or 1) / totalFlex)
                or 0
        end

        if def.bg then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, def.bg[1], def.bg[2], def.bg[3], def.bg[4] or 1.0)
        end

        local useSpan = def.span == true
        if useSpan and def.rows then
            print("[WindowUtils] MultiRow '" .. id .. "' cell " .. i .. ": span and rows both set, using span")
        end

        if useSpan then
            ImGui.BeginChild("##mr_" .. id .. "_" .. i, cellW, regionHeight, def.border or false, def.flags or 0)
            if def.content then def.content() end
            ImGui.EndChild()
        elseif def.rows and #def.rows > 0 then
            ImGui.BeginChild("##mr_" .. id .. "_" .. i, cellW, regionHeight, def.border or false, def.flags or 0)
            local stackRowH = math.floor((regionHeight - (#def.rows - 1) * frameCache.itemSpacingY) / #def.rows)
            for rowIdx, rowFn in ipairs(def.rows) do
                ImGui.BeginChild("##mr_" .. id .. "_" .. i .. "_r" .. rowIdx, cellW, stackRowH, false, 0)
                rowFn()
                ImGui.EndChild()
            end
            ImGui.EndChild()
        elseif def.content then
            ImGui.BeginChild("##mr_" .. id .. "_" .. i, cellW, regionHeight, def.border or false, def.flags or 0)
            def.content()
            ImGui.EndChild()
        else
            ImGui.BeginChild("##mr_" .. id .. "_" .. i, cellW, regionHeight, def.border or false, def.flags or 0)
            ImGui.EndChild()
        end

        if def.bg then ImGui.PopStyleColor() end

        if i < #defs then
            ImGui.SameLine()
        end
    end
end

--------------------------------------------------------------------------------
-- Layout: Column (vertical child windows)
--------------------------------------------------------------------------------

--- Vertical column of child windows that fills available height.
--- Children can be flex (fill proportional space), fixed height, or auto-sized.
---@param id string Unique column ID prefix
---@param defs table Array of row defs: {flex?, height?, auto?, bg?, border?, flags?, content?}
---@param opts? table {gap?} gap = spacing in pixels between children (default ItemSpacing.y * 2)
---@return nil
function M.Column(id, defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}

    local spacingY = frameCache.itemSpacingY
    local gap = opts.gap or spacingY * 2
    local availW, availH = ImGui.GetContentRegionAvail()
    availH = math.max(availH, 1)

    -- Auto-height cache (persists across frames for stable layout)
    local ac = columnAutoCache[id]
    if not ac then
        ac = { n = 0 }
        columnAutoCache[id] = ac
    end

    -- Invalidate stale entries only when slot count changes
    local n = #defs
    if ac.n ~= n then
        for i = n + 1, ac.n do ac[i] = nil end
        ac.n = n
    end

    -- Single pass: tally fixed heights and flex weights, count content-bearing slots
    local fixedH = 0
    local totalFlex = 0
    local contentSlots = 0
    for i = 1, n do
        local def = defs[i]
        if def.auto then
            local h = ac[i] or 0
            fixedH = fixedH + h
            if h > 0 then contentSlots = contentSlots + 1 end
        elseif def.height then
            fixedH = fixedH + def.height
            contentSlots = contentSlots + 1
        else
            totalFlex = totalFlex + (def.flex or 1)
            contentSlots = contentSlots + 1
        end
    end

    local totalGap = gap * math.max(contentSlots - 1, 0)
    local remainingH = math.max(availH - fixedH - totalGap, 0)

    -- Render pass
    local prevRendered = false
    for i = 1, n do
        local def = defs[i]

        -- Will this slot produce visible output? (auto uses previous frame's measurement)
        local willRender = not def.auto or (ac[i] or 0) > 0

        -- Gap: only between two adjacent slots that both have content
        if i > 1 then
            local addGap = prevRendered and willRender
            ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY + (addGap and gap or 0))
        end

        if def.auto then
            local _, startY = ImGui.GetCursorPos()
            if def.content then def.content() end
            local _, endY = ImGui.GetCursorPos()
            local measured = math.max(endY - startY - spacingY, 0)
            ac[i] = measured
            prevRendered = measured > 0
        else
            local childH
            if def.height then
                childH = def.height
            elseif totalFlex > 0 then
                childH = math.floor(remainingH * (def.flex or 1) / totalFlex)
            else
                childH = 0
            end

            if def.bg then
                ImGui.PushStyleColor(ImGuiCol.ChildBg, def.bg[1], def.bg[2], def.bg[3], def.bg[4] or 1.0)
            end

            local childFlags = def.flags or 0
            if def.height then
                childFlags = childFlags + ImGuiWindowFlags.NoScrollbar
            end

            ImGui.BeginChild("##col_" .. id .. "_" .. i, availW, childH, def.border or false, childFlags)
            if def.content then def.content() end
            ImGui.EndChild()

            if def.bg then ImGui.PopStyleColor() end
            prevRendered = true
        end
    end
end

return M
