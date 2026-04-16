------------------------------------------------------
-- WindowUtils - Controls Sliders
-- Slider family: SliderFloat, SliderInt, SliderDisabled, TimeSlider
------------------------------------------------------

local styles = require("modules/styles")
local core = require("modules/controls/core")

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
    local fmt = opts and opts.format or "%.2f"
    return core.renderIconControl(icon, id, opts, ImGui.SliderFloat, value, min, max, fmt)
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
    local fmt = opts and opts.format or "%d"
    return core.renderIconControl(icon, id, opts, ImGui.SliderInt, value, min, max, fmt)
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

--------------------------------------------------------------------------------
-- Time-of-Day Slider
-- Value: seconds since midnight (0-86399)
-- Display: "h:MM AM/PM" format
-- Drag: minute-granularity steps with proper wrapping
-- Ctrl+click: type raw seconds or time strings
--------------------------------------------------------------------------------

-- Persistent state for time input text editing (keyed by slider id)
local _timeInputState = {}

local formatTimeOfDay = core.formatTimeOfDay
local parseTimeInput = core.parseTimeInput

--- Create a time-of-day slider.
--- Value is seconds since midnight (0-86399). Displays as "h:MM AM/PM".
--- Drag adjusts in minute increments. Double-click to type a time string.
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value number Current value in seconds since midnight
---@param opts? table {tooltip?, cols?, default?}
---@return number newValue Updated value in seconds since midnight
---@return boolean changed True if the value was modified
function M.TimeSlider(icon, id, value, opts)
    opts = opts or {}
    value = math.floor(value or 0) % 86400

    local alwaysShow = opts.alwaysShowTooltip ~= false
    local hasIcon = core.iconPrefix(icon, opts.tooltip, alwaysShow)
    local controlWidth = core.calcControlWidth(opts.cols, hasIcon)

    local state = _timeInputState[id]

    -- Text input mode (activated by double-click)
    if state and state.editing then
        ImGui.SetNextItemWidth(controlWidth)
        styles.PushOutlined()
        local newText, textChanged = ImGui.InputText("##" .. id, state.buffer, 32,
            ImGuiInputTextFlags.EnterReturnsTrue + ImGuiInputTextFlags.AutoSelectAll)
        styles.PopOutlined()

        -- Auto-focus on first frame
        if state.focusNext then
            ImGui.SetKeyboardFocusHere(-1)
            state.focusNext = false
        end

        -- Commit on Enter
        if textChanged then
            local parsed = parseTimeInput(newText)
            if parsed then
                state.editing = false
                return parsed, true
            end
            -- Invalid input: stay in edit mode, let user fix it
        end

        -- Cancel on Escape or click away
        if ImGui.IsKeyPressed(ImGuiKey.Escape) or
           (not ImGui.IsItemActive() and not state.focusNext) then
            state.editing = false
        end

        return value, false
    end

    -- Slider mode: use SliderInt with minutes for clean stepping
    local minutes = math.floor(value / 60)
    local displayFmt = formatTimeOfDay(value)

    ImGui.SetNextItemWidth(controlWidth)
    styles.PushOutlined()
    local newMinutes, changed = ImGui.SliderInt("##" .. id, minutes, 0, 1439, displayFmt)
    styles.PopOutlined()

    -- Double-click to enter text input mode
    if ImGui.IsItemHovered() and ImGui.IsMouseDoubleClicked(0) then
        _timeInputState[id] = {
            editing = true,
            buffer = formatTimeOfDay(value),
            focusNext = true,
        }
        return value, false
    end

    -- Right-click reset
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        return opts.default, true
    end

    if changed then
        return newMinutes * 60, true
    end

    return value, false
end

return M
