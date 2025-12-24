------------------------------------------------------
-- WindowUtils - Tooltips Module
-- Universal tooltip utilities for CET mods
------------------------------------------------------

local settings = require("modules/settings")

local tooltips = {}

--------------------------------------------------------------------------------
-- Basic Tooltips
--------------------------------------------------------------------------------

--- Show a simple tooltip if the previous item is hovered (always shows, ignores settings)
-- @param text string: Tooltip text
function tooltips.ShowAlways(text)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        ImGui.EndTooltip()
    end
end

--- Show a simple tooltip if the previous item is hovered (respects tooltipsEnabled setting)
-- @param text string: Tooltip text (if nil, does nothing)
function tooltips.Show(text)
    if not text then return end
    if not settings.master.tooltipsEnabled then return end

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with wrapped text for long descriptions
-- @param text string: Tooltip text
-- @param maxWidth number: Maximum width before wrapping (optional, default 300)
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

--- Show a tooltip with a title and description
-- @param title string: Tooltip title (bold/prominent)
-- @param description string: Tooltip description (muted)
function tooltips.ShowTitled(title, description)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(title)
        if description then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.6, 0.6, 0.6, 1.0))
            ImGui.TextWrapped(description)
            ImGui.PopStyleColor()
        end
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with custom color
-- @param text string: Tooltip text
-- @param r number: Red (0-1)
-- @param g number: Green (0-1)
-- @param b number: Blue (0-1)
-- @param a number: Alpha (0-1, optional, default 1)
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

--- Show a muted (grey) tooltip
-- @param text string: Tooltip text
function tooltips.ShowMuted(text)
    tooltips.ShowColored(text, 0.6, 0.6, 0.6, 1.0)
end

--- Show a success (green) tooltip
-- @param text string: Tooltip text
function tooltips.ShowSuccess(text)
    tooltips.ShowColored(text, 0.0, 1.0, 0.7, 1.0)
end

--- Show a danger (red) tooltip
-- @param text string: Tooltip text
function tooltips.ShowDanger(text)
    tooltips.ShowColored(text, 1.0, 0.3, 0.3, 1.0)
end

--- Show a warning (yellow) tooltip
-- @param text string: Tooltip text
function tooltips.ShowWarning(text)
    tooltips.ShowColored(text, 1.0, 0.8, 0.0, 1.0)
end

--------------------------------------------------------------------------------
-- Conditional Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip only if condition is true
-- @param text string: Tooltip text
-- @param condition boolean: Show tooltip only if true
function tooltips.ShowIf(text, condition)
    if condition then
        tooltips.Show(text)
    end
end

--- Show a tooltip only if tooltips are enabled in settings
-- @param text string: Tooltip text
-- @param enabled boolean: Whether tooltips are enabled
function tooltips.ShowIfEnabled(text, enabled)
    if enabled then
        tooltips.Show(text)
    end
end

--------------------------------------------------------------------------------
-- Info/Help Tooltips
--------------------------------------------------------------------------------

--- Show a help tooltip with question mark styling
-- @param text string: Help text
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

--- Show a keybind tooltip
-- @param action string: Action description
-- @param keybind string: Keybind text (e.g., "Right-click", "Ctrl+Z")
function tooltips.ShowKeybind(action, keybind)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(action)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.5, 0.5, 0.5, 1.0))
        ImGui.Text("[" .. keybind .. "]")
        ImGui.PopStyleColor()
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with action hint (commonly used pattern)
-- @param text string: Tooltip text
-- @param hint string: Action hint (e.g., "Right-click to reset")
function tooltips.ShowWithHint(text, hint)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        if hint then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.5, 0.5, 0.5, 1.0))
            ImGui.Text(hint)
            ImGui.PopStyleColor()
        end
        ImGui.EndTooltip()
    end
end

--------------------------------------------------------------------------------
-- Multi-line Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip with multiple lines
-- @param lines table: Array of strings, each on its own line
function tooltips.ShowLines(lines)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        for _, line in ipairs(lines) do
            ImGui.Text(line)
        end
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with bullet points
-- @param title string: Tooltip title (optional)
-- @param bullets table: Array of bullet point strings
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
