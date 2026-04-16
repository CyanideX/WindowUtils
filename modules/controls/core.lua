------------------------------------------------------
-- WindowUtils - Controls Core
-- Shared foundation: frameCache, scaling, grid, icon helpers
------------------------------------------------------

local frameContext = require("core/frameContext")
local styles = require("modules/styles")
local tooltips = require("modules/tooltips")
local utils = require("modules/utils")

local core = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local PANEL_DEFAULT_BG = { 0.65, 0.7, 1.0, 0.045 }
core.PANEL_DEFAULT_BG = PANEL_DEFAULT_BG

--------------------------------------------------------------------------------
-- Per-frame style cache (call core.cacheFrameState() once per onDraw)
--------------------------------------------------------------------------------

local frameCache = {}
core.frameCache = frameCache

-- Scale a 1080p-baseline pixel value to the current display resolution
local function Scaled(value)
    return math.floor(value * (frameCache.displayHeight / 1080) + 0.5)
end

core.Scaled = Scaled

--------------------------------------------------------------------------------
-- Shared state tables (owned by core, accessed by multiple sub-modules)
--------------------------------------------------------------------------------

local buttonRowMinWidths = {}   -- ButtonRow minimum width cache (keyed by opts.id)
local buttonGroupWidths = {}    -- Cached combined widths for button groups (keyed by groupId)

core.buttonRowMinWidths = buttonRowMinWidths
core.buttonGroupWidths = buttonGroupWidths

---@param id string ButtonRow id (from opts.id)
---@return number|nil minWidth Cached minimum width in pixels, or nil if unknown
function core.getButtonRowMinWidth(id)
    return buttonRowMinWidths[id]
end

--- Get the cached combined width of a button group from a previous DragFloatRow/DragIntRow.
--- Buttons with the same groupId have their widths + spacing summed and cached.
---@param groupId string The group ID assigned to buttons via the groupId field
---@return number|nil width Combined pixel width, or nil if not yet measured
function core.getButtonGroupWidth(groupId)
    return buttonGroupWidths[groupId]
end

---@return nil
function core.cacheFrameState()
    local style = ImGui.GetStyle()
    frameCache.itemSpacingX = style.ItemSpacing.x
    frameCache.itemSpacingY = style.ItemSpacing.y
    frameCache.framePaddingX = style.FramePadding.x
    frameCache.windowPaddingX = style.WindowPadding.x
    frameCache.windowPaddingY = style.WindowPadding.y
    frameCache.frameHeight = ImGui.GetFrameHeight()
    frameCache.textLineHeight = ImGui.GetTextLineHeightWithSpacing()
    frameCache.minIconButtonWidth = utils.minIconButtonWidth(style.FramePadding.x)
    frameCache.charWidth = ImGui.CalcTextSize("M")
    frameCache.ellipsisWidth = ImGui.CalcTextSize("...")
    local ctx = frameContext.get()
    frameCache.displayWidth = ctx.displayWidth
    frameCache.displayHeight = ctx.displayHeight
end

---@return table frameCache Cached style values for the current frame
function core.getFrameCache()
    return frameCache
end

--------------------------------------------------------------------------------
-- Grid System (Bootstrap-style columns)
--------------------------------------------------------------------------------

--- Calculate width for a column ratio (1-12 out of 12 columns)
---@param cols? number Column span (1-12, default 12)
---@param gap? number Gap between columns in pixels (default itemSpacingX)
---@param hasIcon? boolean Whether an icon occupies space to the left
---@return number width Calculated pixel width (minimum 20)
function core.ColWidth(cols, gap, hasIcon)
    cols = math.max(1, math.min(12, cols or 12))
    gap = gap or frameCache.itemSpacingX
    local iconWidth = frameCache.minIconButtonWidth
    local availWidth = ImGui.GetContentRegionAvail()
    if hasIcon then
        availWidth = availWidth + iconWidth + gap
    end
    local colWidth = (availWidth - (gap * 11)) / 12
    local targetWidth = (colWidth * cols) + (gap * (cols - 1))
    if hasIcon then
        targetWidth = targetWidth - iconWidth - gap
    end
    return math.max(targetWidth, Scaled(20))
end

--- Get remaining width after current cursor position
---@param offset? number Pixels to subtract from remaining width (default 0)
---@return number width Remaining width in pixels
function core.RemainingWidth(offset)
    offset = offset or 0
    return ImGui.GetContentRegionAvail() - offset
end

--------------------------------------------------------------------------------
-- Icon Button (Invisible button with icon for labels)
--------------------------------------------------------------------------------

--- Create an invisible button with an icon (for use as slider/input labels)
---@param icon string Icon glyph string or IconGlyphs key
---@param clickable? boolean If true, returns click state (default false)
---@return boolean clicked True if clickable and the button was clicked
function core.IconButton(icon, clickable)
    clickable = clickable or false

    styles.PushButtonTransparent()
    local clicked = ImGui.Button(icon)
    styles.PopButtonTransparent()

    if clickable then
        return clicked
    end
    return false
end

--------------------------------------------------------------------------------
-- Helpers: icon prefix + width calculation (shared by sliders, inputs, combo)
--------------------------------------------------------------------------------

local resolveIcon = utils.resolveIcon
core.resolveIcon = resolveIcon

local function iconPrefix(icon, tooltip, alwaysShow)
    icon = resolveIcon(icon)
    if not icon then return false end
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
    core.IconButton(icon, false)
    if tooltip then
        if alwaysShow then tooltips.ShowAlways(tooltip)
        else tooltips.Show(tooltip) end
    end
    ImGui.SameLine()
    ImGui.PopStyleVar()
    return true
end

core.iconPrefix = iconPrefix

local function calcControlWidth(cols, hasIcon)
    if cols then return core.ColWidth(cols, nil, hasIcon) end
    return ImGui.GetContentRegionAvail()
end

core.calcControlWidth = calcControlWidth

local function cachedCalcTextSize(text)
    return utils.cachedCalcTextSize(text, frameCache.charWidth)
end

core.cachedCalcTextSize = cachedCalcTextSize

local function cachedTruncateText(label, innerWidth)
    return utils.cachedTruncateText(label, innerWidth, frameCache.charWidth)
end

core.cachedTruncateText = cachedTruncateText

--------------------------------------------------------------------------------
-- Shared icon control render sequence (used by sliders, drags, inputs, combo)
--------------------------------------------------------------------------------

--- Execute the full 6-step icon control sequence using varargs (zero closures).
--- 1. iconPrefix  2. SetNextItemWidth  3. PushOutlined
--- 4. imguiFn("##"..id, ...)  5. PopOutlined  6. right-click reset
---@param icon string|nil Icon glyph
---@param id string ImGui ID suffix (## prepended automatically)
---@param opts table|nil {tooltip?, cols?, default?, alwaysShowTooltip?} (nil-safe)
---@param imguiFn function The ImGui control function (e.g. ImGui.SliderFloat)
---@param ... any Arguments to pass after the ImGui ID
---@return any newValue
---@return boolean changed
function core.renderIconControl(icon, id, opts, imguiFn, ...)
    local alwaysShow = not opts or opts.alwaysShowTooltip ~= false
    local hasIcon = iconPrefix(icon, opts and opts.tooltip, alwaysShow)
    ImGui.SetNextItemWidth(calcControlWidth(opts and opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = imguiFn("##" .. id, ...)
    styles.PopOutlined()
    if opts and opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end
    return newValue, changed
end

--------------------------------------------------------------------------------
-- Time-of-Day helpers (shared by sliders.TimeSlider and drags type="time")
--------------------------------------------------------------------------------

--- Format seconds since midnight as "h:MM AM/PM"
---@param seconds number Seconds since midnight (0-86399)
---@return string Formatted time string
function core.formatTimeOfDay(seconds)
    seconds = math.floor(seconds) % 86400
    local h24 = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local period = h24 >= 12 and "PM" or "AM"
    local h12 = h24 % 12
    if h12 == 0 then h12 = 12 end
    return string.format("%d:%02d %s", h12, m, period)
end

--- Parse a time string into seconds since midnight.
--- Accepts: "1:45 PM", "13:45", "1345", "1:45pm", "945", "9:45"
---@param text string Time string to parse
---@return number|nil seconds Seconds since midnight, or nil if unparseable
function core.parseTimeInput(text)
    if not text or text == "" then return nil end
    text = text:match("^%s*(.-)%s*$")
    local h, m, period = text:match("^(%d+):(%d+)%s*([AaPp][Mm]?)$")
    if h then
        h, m = tonumber(h), tonumber(m)
        if not h or not m then return nil end
        if period and period ~= "" then
            period = period:upper()
            if period == "PM" and h < 12 then h = h + 12 end
            if period == "AM" and h == 12 then h = 0 end
        end
        if h >= 0 and h < 24 and m >= 0 and m < 60 then return h * 3600 + m * 60 end
        return nil
    end
    h, m = text:match("^(%d+):(%d+)$")
    if h then
        h, m = tonumber(h), tonumber(m)
        if h and m and h >= 0 and h < 24 and m >= 0 and m < 60 then return h * 3600 + m * 60 end
        return nil
    end
    if text:match("^%d+$") then
        local n = tonumber(text)
        if not n then return nil end
        if #text >= 3 then
            h = math.floor(n / 100)
            m = n % 100
        else
            h, m = n, 0
        end
        if h >= 0 and h < 24 and m >= 0 and m < 60 then return h * 3600 + m * 60 end
    end
    return nil
end

--- Shared time-of-day control renderer. Used by TimeSlider and TimeDrag.
--- Handles text input mode, double-click switching, right-click reset.
--- The caller provides the ImGui control function for the normal mode.
---@param icon string|nil Icon glyph
---@param id string Unique ImGui ID suffix
---@param value number Seconds since midnight (0-86399)
---@param opts table {tooltip?, cols?, default?}
---@param stateTable table Module-level persistent state table for text editing
---@param renderControl function(controlWidth, dragId, minutes, displayFmt) -> newMinutes, changed
---@return number newValue Seconds since midnight
---@return boolean changed
function core.renderTimeControl(icon, id, value, opts, stateTable, renderControl)
    opts = opts or {}
    value = math.floor(value or 0) % 86400

    local alwaysShow = opts.alwaysShowTooltip ~= false
    local hasIcon = iconPrefix(icon, opts.tooltip, alwaysShow)
    local controlWidth = calcControlWidth(opts.cols, hasIcon)

    local dragId = "##" .. id
    local state = stateTable[dragId]

    -- Text input mode (activated by double-click)
    if state and state.editing then
        ImGui.SetNextItemWidth(controlWidth)
        styles.PushOutlined()
        local newText, committed = ImGui.InputText(dragId, state.buffer, 32,
            ImGuiInputTextFlags.EnterReturnsTrue + ImGuiInputTextFlags.AutoSelectAll)
        styles.PopOutlined()
        if state.focusNext then
            ImGui.SetKeyboardFocusHere(-1)
            state.focusNext = false
        end
        if committed then
            local parsed = core.parseTimeInput(newText)
            if parsed then
                state.editing = false
                return parsed, true
            end
        end
        if ImGui.IsKeyPressed(ImGuiKey.Escape) or
           (not ImGui.IsItemActive() and not state.focusNext) then
            state.editing = false
        end
        return value, false
    end

    -- Normal mode: delegate to caller's control renderer
    local minutes = math.floor(value / 60)
    local displayFmt = core.formatTimeOfDay(value)
    local newMinutes, changed = renderControl(controlWidth, dragId, minutes, displayFmt)

    -- Double-click to enter text input mode
    if ImGui.IsItemHovered() and ImGui.IsMouseDoubleClicked(0) then
        stateTable[dragId] = {
            editing = true,
            buffer = core.formatTimeOfDay(value),
            focusNext = true,
        }
        return value, false
    end

    -- Right-click reset
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        return opts.default, true
    end

    if changed then
        newMinutes = newMinutes % 1440
        if newMinutes < 0 then newMinutes = newMinutes + 1440 end
        return newMinutes * 60, true
    end

    return value, false
end

return core
