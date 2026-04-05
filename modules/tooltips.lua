------------------------------------------------------
-- WindowUtils - Tooltips
-- Tooltip utilities for CET mods
------------------------------------------------------

local settings = require("core/settings")
local styles = require("modules/styles")

local tooltips = {}

local DEFAULT_TOOLTIP_WIDTH_PCT = 15

--- Set the default tooltip max width percentage.
--- WindowUtils UI calls this to sync with the user's setting.
---@param pct number Screen-width percentage (e.g. 15 for 15%)
function tooltips.setDefaultWidthPct(pct)
    DEFAULT_TOOLTIP_WIDTH_PCT = pct
end

--- Resolve tooltip max width from a screen-width percentage.
--- Pass 0 to disable wrapping.
---@param pct? number Screen-width percentage override, 0 to disable wrapping
---@return number pixels
local function tooltipMaxWidth(pct)
    if pct == 0 then return 0 end
    local sw = GetDisplayResolution()
    return math.floor(sw * (pct or DEFAULT_TOOLTIP_WIDTH_PCT) / 100)
end

--- Render a tooltip with optional text wrapping.
---@param text string Tooltip text
---@param widthPct? number Max width as screen-width percentage, 0 to disable wrapping
local function renderTooltip(text, widthPct)
    ImGui.BeginTooltip()
    local maxW = tooltipMaxWidth(widthPct)
    if maxW > 0 then
        ImGui.PushTextWrapPos(maxW)
        ImGui.TextWrapped(text)
        ImGui.PopTextWrapPos()
    else
        ImGui.Text(text)
    end
    ImGui.EndTooltip()
end

--- Guard: run renderFn inside a tooltip only when the previous item is hovered.
---@param renderFn function Content rendering callback
local function ifHovered(renderFn)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        renderFn()
        ImGui.EndTooltip()
    end
end

--------------------------------------------------------------------------------
-- Basic Tooltips
--------------------------------------------------------------------------------

--- Show a simple tooltip if the previous item is hovered (always shows, ignores settings).
---@param text string Tooltip text
---@param widthPct? number Max width as screen-width percentage (default 15), 0 to disable wrapping
function tooltips.ShowAlways(text, widthPct)
    if ImGui.IsItemHovered() then
        renderTooltip(text, widthPct)
    end
end

--- Show a simple tooltip if the previous item is hovered (respects tooltipsEnabled setting).
---@param text string|nil Tooltip text (nil = no-op)
---@param widthPct? number Max width as screen-width percentage (default 15), 0 to disable wrapping
function tooltips.Show(text, widthPct)
    if not text then return end
    if not settings.master.tooltipsEnabled then return end

    if ImGui.IsItemHovered() then
        renderTooltip(text, widthPct)
    end
end

--- Show a tooltip with wrapped text for long descriptions.
---@param text string Tooltip text
---@param maxWidth? number Wrap width in pixels (default 300)
function tooltips.ShowWrapped(text, maxWidth)
    maxWidth = maxWidth or 300

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(maxWidth)
        ImGui.TextWrapped(text)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

--------------------------------------------------------------------------------
-- Styled Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip with a title and grey description.
---@param title string Title line
---@param description? string Description shown below a separator
function tooltips.ShowTitled(title, description)
    ifHovered(function()
        ImGui.Text(title)
        if description then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, styles.ToColor(styles.colors.greyLight))
            ImGui.PushTextWrapPos(300)
            ImGui.TextWrapped(description)
            ImGui.PopTextWrapPos()
            ImGui.PopStyleColor()
        end
    end)
end

--- Show a tooltip with custom text color.
---@param text string Tooltip text
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a? number Alpha (default 1.0)
function tooltips.ShowColored(text, r, g, b, a)
    a = a or 1.0

    ifHovered(function()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(r, g, b, a))
        ImGui.Text(text)
        ImGui.PopStyleColor()
    end)
end

--- Show a muted (grey) tooltip.
---@param text string
function tooltips.ShowMuted(text)
    local c = styles.colors.greyLight
    tooltips.ShowColored(text, c[1], c[2], c[3], c[4])
end

--- Show a success (green) tooltip.
---@param text string
function tooltips.ShowSuccess(text)
    local c = styles.colors.green
    tooltips.ShowColored(text, c[1], c[2], c[3], c[4])
end

--- Show a danger (red) tooltip.
---@param text string
function tooltips.ShowDanger(text)
    local c = styles.colors.red
    tooltips.ShowColored(text, c[1], c[2], c[3], c[4])
end

--- Show a warning (yellow) tooltip.
---@param text string
function tooltips.ShowWarning(text)
    local c = styles.colors.yellow
    tooltips.ShowColored(text, c[1], c[2], c[3], 1.0)
end

--------------------------------------------------------------------------------
-- Conditional Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip only if condition is true (respects tooltipsEnabled).
---@param text string Tooltip text
---@param condition boolean Show condition
function tooltips.ShowIf(text, condition)
    if condition then
        tooltips.Show(text)
    end
end

--------------------------------------------------------------------------------
-- Info/Help Tooltips
--------------------------------------------------------------------------------

--- Show a help tooltip with blue [?] prefix and wrapped text.
---@param text string Help text
function tooltips.ShowHelp(text)
    ifHovered(function()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.5, 0.7, 1.0, 1.0))
        ImGui.Text("[?]")
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.PushTextWrapPos(300)
        ImGui.TextWrapped(text)
        ImGui.PopTextWrapPos()
    end)
end

--- Show a tooltip with action label and grey keybind hint.
---@param action string Action description
---@param keybind string Keybind string (displayed in brackets)
function tooltips.ShowKeybind(action, keybind)
    ifHovered(function()
        ImGui.Text(action)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, styles.ToColor(styles.colors.greyText))
        ImGui.Text("[" .. keybind .. "]")
        ImGui.PopStyleColor()
    end)
end

--- Show a tooltip with main text and grey hint below a separator.
---@param text string Main tooltip text
---@param hint? string Hint text shown below separator
function tooltips.ShowWithHint(text, hint)
    ifHovered(function()
        ImGui.Text(text)
        if hint then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, styles.ToColor(styles.colors.greyText))
            ImGui.Text(hint)
            ImGui.PopStyleColor()
        end
    end)
end

--------------------------------------------------------------------------------
-- Multi-line Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip with multiple text lines.
---@param lines string[] Array of text lines
function tooltips.ShowLines(lines)
    ifHovered(function()
        for _, line in ipairs(lines) do
            ImGui.Text(line)
        end
    end)
end

--- Show a tooltip with optional title and bullet points.
---@param title? string Title line (nil = no title)
---@param bullets string[] Array of bullet point strings
function tooltips.ShowBullets(title, bullets)
    ifHovered(function()
        if title then
            ImGui.Text(title)
            ImGui.Separator()
        end
        for _, bullet in ipairs(bullets) do
            ImGui.BulletText(bullet)
        end
    end)
end

return tooltips
