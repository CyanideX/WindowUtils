------------------------------------------------------
-- WindowUtils - Tooltips Module
-- Universal tooltip utilities for CET mods
------------------------------------------------------

local settings = require("modules/settings")
local styles = require("modules/styles")

local tooltips = {}

--------------------------------------------------------------------------------
-- Basic Tooltips
--------------------------------------------------------------------------------

--- Show a simple tooltip if the previous item is hovered (always shows, ignores settings).
---@param text string Tooltip text
function tooltips.ShowAlways(text)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        ImGui.EndTooltip()
    end
end

--- Show a simple tooltip if the previous item is hovered (respects tooltipsEnabled setting).
---@param text string|nil Tooltip text (nil = no-op)
function tooltips.Show(text)
    if not text then return end
    if not settings.master.tooltipsEnabled then return end

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        ImGui.EndTooltip()
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
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(title)
        if description then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, styles.ToColor(styles.colors.greyLight))
            ImGui.TextWrapped(description)
            ImGui.PopStyleColor()
        end
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with custom text color.
---@param text string Tooltip text
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a? number Alpha (default 1.0)
function tooltips.ShowColored(text, r, g, b, a)
    a = a or 1.0

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(r, g, b, a))
        ImGui.Text(text)
        ImGui.PopStyleColor()
        ImGui.EndTooltip()
    end
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
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.5, 0.7, 1.0, 1.0))
        ImGui.Text("[?]")
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.PushTextWrapPos(300)
        ImGui.TextWrapped(text)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with action label and grey keybind hint.
---@param action string Action description
---@param keybind string Keybind string (displayed in brackets)
function tooltips.ShowKeybind(action, keybind)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(action)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, styles.ToColor(styles.colors.greyText))
        ImGui.Text("[" .. keybind .. "]")
        ImGui.PopStyleColor()
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with main text and grey hint below a separator.
---@param text string Main tooltip text
---@param hint? string Hint text shown below separator
function tooltips.ShowWithHint(text, hint)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        if hint then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, styles.ToColor(styles.colors.greyText))
            ImGui.Text(hint)
            ImGui.PopStyleColor()
        end
        ImGui.EndTooltip()
    end
end

--------------------------------------------------------------------------------
-- Multi-line Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip with multiple text lines.
---@param lines string[] Array of text lines
function tooltips.ShowLines(lines)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        for _, line in ipairs(lines) do
            ImGui.Text(line)
        end
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with optional title and bullet points.
---@param title? string Title line (nil = no title)
---@param bullets string[] Array of bullet point strings
function tooltips.ShowBullets(title, bullets)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        if title then
            ImGui.Text(title)
            ImGui.Separator()
        end
        for _, bullet in ipairs(bullets) do
            ImGui.BulletText(bullet)
        end
        ImGui.EndTooltip()
    end
end

return tooltips
