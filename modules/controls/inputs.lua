------------------------------------------------------
-- WindowUtils - Controls / Inputs
-- InputText, InputFloat, InputInt, Checkbox, Combo, SearchBar, SearchBarPlain
------------------------------------------------------

local core = require("modules/controls/core")
local styles = require("modules/styles")
local tooltips = require("modules/tooltips")

local M = {}

--------------------------------------------------------------------------------
-- Checkboxes (standard ImGui styling, no custom colors)
--------------------------------------------------------------------------------

--- Create a checkbox (opts: icon, default, tooltip, alwaysShowTooltip)
---@param label string Checkbox label text
---@param value boolean Current checked state
---@param opts? table {icon?, default?, tooltip?, alwaysShowTooltip?}
---@return boolean newValue Updated checked state
---@return boolean changed True if the value was toggled
function M.Checkbox(label, value, opts)
    opts = opts or {}
    local hasIcon = false
    if opts.icon then
        hasIcon = true
        core.iconPrefix(opts.icon, opts.tooltip, opts.alwaysShowTooltip)
    end

    local newValue, changed = ImGui.Checkbox(label, value)

    if not hasIcon and opts.tooltip then
        if opts.alwaysShowTooltip then
            tooltips.ShowAlways(opts.tooltip)
        else
            tooltips.Show(opts.tooltip)
        end
    end

    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end

    return newValue, changed
end

--------------------------------------------------------------------------------
-- Combo/Dropdown with Icon
--------------------------------------------------------------------------------

--- Create a combo dropdown (icon, id, currentIndex, items, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param currentIndex integer Zero-based selected index
---@param items table Array of string labels
---@param opts? table {tooltip?, cols?, default?}
---@return integer newIndex Updated selected index
---@return boolean changed True if the selection changed
function M.Combo(icon, id, currentIndex, items, opts)
    return core.renderIconControl(icon, id, opts, ImGui.Combo, currentIndex, items, #items)
end

--------------------------------------------------------------------------------
-- Input Fields with Icon
--------------------------------------------------------------------------------

--- Create an input text field (icon, id, text, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param text string Current text value
---@param opts? table {maxLength?, tooltip?, alwaysShowTooltip?, cols?}
---@return string newText Updated text value
---@return boolean changed True if the text was modified
function M.InputText(icon, id, text, opts)
    local maxLength = opts and opts.maxLength or 256
    return core.renderIconControl(icon, id, opts, ImGui.InputText, text, maxLength)
end

--- Create an input float field (icon, id, value, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value number Current float value
---@param opts? table {step?, stepFast?, format?, tooltip?, alwaysShowTooltip?, cols?}
---@return number newValue Updated float value
---@return boolean changed True if the value was modified
function M.InputFloat(icon, id, value, opts)
    local step = opts and opts.step or 0.1
    local stepFast = opts and opts.stepFast or 1.0
    local fmt = opts and opts.format or "%.2f"
    return core.renderIconControl(icon, id, opts, ImGui.InputFloat, value, step, stepFast, fmt)
end

--- Create an input int field (icon, id, value, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value integer Current integer value
---@param opts? table {step?, stepFast?, tooltip?, alwaysShowTooltip?, cols?}
---@return integer newValue Updated integer value
---@return boolean changed True if the value was modified
function M.InputInt(icon, id, value, opts)
    local step = opts and opts.step or 1
    local stepFast = opts and opts.stepFast or 10
    return core.renderIconControl(icon, id, opts, ImGui.InputInt, value, step, stepFast)
end

--------------------------------------------------------------------------------
-- SearchBar Control (migrated from search.lua)
--------------------------------------------------------------------------------

--- Render a search bar that drives a search state.
--- Icon changes to MagnifyClose when query is active (click to clear).
--- Right-click the input to clear.
---@param state table|nil SearchState (no-op if nil)
---@param opts? table {cols?: number, placeholder?: string, width?: number}
---@return string query Current query text
function M.SearchBar(state, opts)
    if not state then return "" end
    opts = opts or {}
    local hasQuery = not state:isEmpty()
    local ic = IconGlyphs or {}

    -- Icon: clickable clear button when query is active
    local icon = hasQuery and (ic.MagnifyClose or "X") or (ic.Magnify or "?")
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, ImGui.GetStyle().ItemSpacing.y)
    local clicked = core.IconButton(icon, hasQuery)
    if hasQuery then
        tooltips.Show("Clear search")
    else
        tooltips.Show("Search settings")
    end
    ImGui.SameLine()
    ImGui.PopStyleVar()

    if clicked and hasQuery then
        state:clear()
    end

    -- Input field
    local w
    if opts.width then
        -- width is the total control width; subtract icon space
        local iconWidth = core.frameCache.minIconButtonWidth
        w = opts.width - iconWidth - 4
    else
        w = core.ColWidth(opts.cols or 12, nil, true)
    end
    ImGui.SetNextItemWidth(w)
    styles.PushOutlined()
    local newText, changed = ImGui.InputText("##search_" .. state.id, state:getQuery(), 256)
    styles.PopOutlined()

    -- Right-click to clear
    if ImGui.IsItemClicked(1) then
        state:clear()
        newText = ""
        changed = true
    end

    if changed then
        state:setQuery(newText)
    end
    return state:getQuery()
end

--- Render a search bar with placeholder text instead of an icon.
--- Uses InputTextWithHint for inline placeholder that disappears on focus.
--- Right-click the input to clear. No icon prefix, full-width input.
---@param state table|nil SearchState (no-op if nil)
---@param opts? table {cols?: number, placeholder?: string, maxLength?: number, clearIcon?: boolean, width?: number}
---@return string query Current query text
function M.SearchBarPlain(state, opts)
    if not state then return "" end
    opts = opts or {}
    local placeholder = opts.placeholder or "Search..."
    local maxLength = opts.maxLength or 256
    local hasQuery = not state:isEmpty()

    -- Optional clear icon when query is active
    local hasIcon = false
    if opts.clearIcon and hasQuery then
        local ic = IconGlyphs or {}
        local icon = ic.Close or "X"
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, ImGui.GetStyle().ItemSpacing.y)
        local clicked = core.IconButton(icon, true)
        if clicked then state:clear() end
        tooltips.Show("Clear search")
        ImGui.SameLine()
        ImGui.PopStyleVar()
        hasIcon = true
    end

    -- Input field with hint
    local w
    if opts.width then
        -- width is the total control width; subtract icon space if present
        if hasIcon then
            local iconWidth = core.frameCache.minIconButtonWidth
            w = opts.width - iconWidth - 4
        else
            w = opts.width
        end
    else
        w = core.ColWidth(opts.cols or 12, nil, hasIcon)
    end
    ImGui.SetNextItemWidth(w)
    styles.PushOutlined()
    local newText, changed = ImGui.InputTextWithHint(
        "##search_" .. state.id, placeholder, state:getQuery(), maxLength
    )
    styles.PopOutlined()

    -- Right-click to clear
    if ImGui.IsItemClicked(1) then
        state:clear()
        newText = ""
        changed = true
    end

    if changed then
        state:setQuery(newText)
    end
    return state:getQuery()
end

return M
