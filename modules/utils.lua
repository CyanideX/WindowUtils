------------------------------------------------------
-- WindowUtils - Utils
-- Shared utility functions
------------------------------------------------------
-- See docs/utils.md "Reusable Table Convention"
-- for the full pattern.
------------------------------------------------------

local utils = {}

--------------------------------------------------------------------------------
-- Icon Resolution
--------------------------------------------------------------------------------

--- Resolve an icon name to its glyph character.
--- @param icon string|nil Icon name (e.g. "ContentSave") or raw glyph string
--- @return string|nil glyph The resolved glyph character, or nil
function utils.resolveIcon(icon)
    if not icon or icon == "" then return nil end
    if IconGlyphs and IconGlyphs[icon] then return IconGlyphs[icon] end
    return icon
end

--------------------------------------------------------------------------------
-- Text Truncation
--------------------------------------------------------------------------------

--- Binary search for maximum text that fits within maxWidth, appending ellipsis.
--- @param text string The full text
--- @param maxWidth number Maximum pixel width
--- @return string displayText The truncated text (or original if it fits)
--- @return boolean wasTruncated Whether truncation occurred
function utils.truncateText(text, maxWidth)
    local fullWidth = ImGui.CalcTextSize(text)
    if fullWidth <= maxWidth then return text, false end

    local ellipsis = "..."
    local ellipsisWidth = ImGui.CalcTextSize(ellipsis)
    local targetWidth = maxWidth - ellipsisWidth
    if targetWidth <= 0 then return ellipsis, true end

    local lo, hi = 1, #text
    local bestLen = 0
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local w = ImGui.CalcTextSize(text:sub(1, mid))
        if w <= targetWidth then
            bestLen = mid
            lo = mid + 1
        else
            hi = mid - 1
        end
    end

    if bestLen == 0 then return ellipsis, true end
    return text:sub(1, bestLen) .. ellipsis, true
end

--------------------------------------------------------------------------------
-- Size Specification
--------------------------------------------------------------------------------

--- Parse a size spec: number (pixels), string "30%" (percentage), or nil (flex).
--- @param spec number|string|nil A pixel value, percentage string, or nil
--- @param available number The total available space in pixels
--- @return number|nil pixels The computed pixel value, or nil if spec was nil/invalid
function utils.parseSizeSpec(spec, available)
    if type(spec) == "number" then
        return spec
    elseif type(spec) == "string" then
        local pct = tonumber(spec:match("^(%d+%.?%d*)%%$"))
        if pct then
            return math.floor(available * pct / 100)
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Key State
--------------------------------------------------------------------------------

--- Check if Ctrl key is currently held.
--- @return boolean
function utils.isCtrlHeld()
    return ImGui.IsKeyDown(ImGuiKey.LeftCtrl) or ImGui.IsKeyDown(ImGuiKey.RightCtrl)
end

--- Check if Shift key is currently held.
--- @return boolean
function utils.isShiftHeld()
    return ImGui.IsKeyDown(ImGuiKey.LeftShift) or ImGui.IsKeyDown(ImGuiKey.RightShift)
end

--- Check if Alt key is currently held.
--- @return boolean
function utils.isAltHeld()
    return ImGui.IsKeyDown(ImGuiKey.LeftAlt) or ImGui.IsKeyDown(ImGuiKey.RightAlt)
end

--------------------------------------------------------------------------------
-- Snapping
--------------------------------------------------------------------------------

--- Snap a value to the nearest increment.
--- @param val number The value to snap
--- @param increment number The snap increment (default 0.05)
--- @return number snapped The snapped value
function utils.snapToIncrement(val, increment)
    increment = increment or 0.05
    return math.floor(val / increment + 0.5) * increment
end

--------------------------------------------------------------------------------
-- Minimum Size Detection
--------------------------------------------------------------------------------

--- Compute the minimum usable width for a single icon button.
--- Based on live ImGui measurements: icon glyph width + frame padding.
--- Must be called during onDraw (requires ImGui context).
--- @return number minWidth Minimum pixel width for one icon button
function utils.minIconButtonWidth(framePaddingX)
    local sampleIcon = IconGlyphs and IconGlyphs.DotsVertical or "..."
    local glyphWidth = ImGui.CalcTextSize(sampleIcon)
    framePaddingX = framePaddingX or ImGui.GetStyle().FramePadding.x
    return glyphWidth + framePaddingX * 2
end

--------------------------------------------------------------------------------
-- Drag Speed with Shift Precision
--------------------------------------------------------------------------------

--- Compute drag speed with shift-precision applied.
--- ImGui natively multiplies drag speed by 10x when Shift is held,
--- so this counters that and applies a configurable multiplier.
--- @param baseSpeed number Normal drag speed
--- @param multiplier number|nil Speed multiplier when Shift is held (default 0.1)
--- @return number speed Effective drag speed for this frame
function utils.getDragSpeed(baseSpeed, multiplier)
    if utils.isShiftHeld() then
        multiplier = multiplier or 0.1
        return baseSpeed * 0.1 * multiplier
    end
    return baseSpeed
end

--------------------------------------------------------------------------------
-- Cached Text Measurement
--------------------------------------------------------------------------------

local textSizeCache = {}
local textSizeCacheCharWidth = nil

--- Cache ImGui.CalcTextSize results, invalidated when charWidth changes.
---@param text string
---@param charWidth number Current character width for cache invalidation
---@return number width Pixel width of text
function utils.cachedCalcTextSize(text, charWidth)
    if charWidth ~= textSizeCacheCharWidth then
        textSizeCache = {}
        textSizeCacheCharWidth = charWidth
    end
    local cached = textSizeCache[text]
    if cached then return cached end
    local w = ImGui.CalcTextSize(text)
    textSizeCache[text] = w
    return w
end

--------------------------------------------------------------------------------
-- Cached Text Truncation
--------------------------------------------------------------------------------

local truncateCache = {}
local truncateCacheCharWidth = nil

--- Cache truncated text results, invalidated when charWidth changes.
---@param label string
---@param innerWidth number Available pixel width
---@param charWidth number Current character width for cache invalidation
---@return string result Truncated text
---@return boolean wasTruncated
function utils.cachedTruncateText(label, innerWidth, charWidth)
    if charWidth ~= truncateCacheCharWidth then
        truncateCache = {}
        truncateCacheCharWidth = charWidth
    end
    local key = label .. "|" .. math.floor(innerWidth)
    local cached = truncateCache[key]
    if cached then return cached[1], cached[2] end
    local result, wasTruncated = utils.truncateText(label, innerWidth)
    truncateCache[key] = { result, wasTruncated }
    return result, wasTruncated
end

return utils
