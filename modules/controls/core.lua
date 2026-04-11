------------------------------------------------------
-- WindowUtils - Controls Core
-- Shared foundation: frameCache, scaling, grid, icon helpers
------------------------------------------------------

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
    frameCache.displayWidth, frameCache.displayHeight = GetDisplayResolution()
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
    return math.max(targetWidth, 20)
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

return core
