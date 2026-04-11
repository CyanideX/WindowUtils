------------------------------------------------------
-- WindowUtils - Controls Sliders
-- Slider family: SliderFloat, SliderInt, SliderDisabled
------------------------------------------------------

local styles = require("modules/styles")
local core = require("modules/controls/core")

local iconPrefix = core.iconPrefix
local calcControlWidth = core.calcControlWidth

local M = {}

--------------------------------------------------------------------------------
-- Sliders with Icon (icon on left, slider fills remaining width)
--------------------------------------------------------------------------------

--- Create a float slider (icon, id, value, min, max, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value number Current slider value
---@param min number Minimum value
---@param max number Maximum value
---@param opts? table {format?, tooltip?, cols?, default?}
---@return number newValue Updated value
---@return boolean changed True if the value was modified
function M.SliderFloat(icon, id, value, min, max, opts)
    opts = opts or {}
    local format = opts.format or "%.2f"
    local hasIcon = iconPrefix(icon, opts.tooltip, true)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderFloat("##" .. id, value, min, max, format)
    styles.PopOutlined()
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end
    return newValue, changed
end

--- Create an integer slider (icon, id, value, min, max, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value integer Current slider value
---@param min integer Minimum value
---@param max integer Maximum value
---@param opts? table {format?, tooltip?, cols?, default?}
---@return integer newValue Updated value
---@return boolean changed True if the value was modified
function M.SliderInt(icon, id, value, min, max, opts)
    opts = opts or {}
    local format = opts.format or "%d"
    local hasIcon = iconPrefix(icon, opts.tooltip, true)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderInt("##" .. id, value, min, max, format)
    styles.PopOutlined()
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end
    return newValue, changed
end

--- Create a disabled slider appearance (greyed out)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param label string Slider display label
---@return nil
function M.SliderDisabled(icon, label)
    if icon then
        core.IconButton(icon, false)
        ImGui.SameLine()
    end

    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    styles.PushSliderDisabled()
    ImGui.BeginDisabled(true)
    ImGui.SliderFloat(label, 0, 0, 0, "%.2f", 0)
    ImGui.EndDisabled()
    styles.PopSliderDisabled()
end

return M
